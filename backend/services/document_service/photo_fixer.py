"""
AI Photo Fixer — Government-spec photo processor.

Handles the silent killer of scholarship rejections: bad passport photos.
Every government portal has different size/background/KB requirements.
This module auto-corrects all of them.
"""
import io
import math
from dataclasses import dataclass
from enum import Enum
from typing import Optional

from PIL import Image, ImageFilter, ImageEnhance, ImageOps
from PIL.Image import Resampling


class PhotoSpec(str, Enum):
    PASSPORT = "passport"           # 35×45mm, white bg, <50KB
    NSP = "nsp"                     # 3.5×4.5cm, white bg, 10–50KB
    UP_SCHOLARSHIP = "up_scholarship"  # 2×2 inch, white bg, <20KB
    SSC = "ssc"                     # 4×5cm, white bg, <50KB
    UPSC = "upsc"                   # 3.5×4.5cm, white bg, 20–50KB
    RAILWAY = "railway"             # 3.5×4.5cm, white bg, <100KB
    CUSTOM = "custom"


@dataclass
class PhotoSpecConfig:
    width_px: int
    height_px: int
    max_kb: int
    min_kb: int
    bg_color: tuple  # RGB
    dpi: int


SPEC_MAP: dict[PhotoSpec, PhotoSpecConfig] = {
    PhotoSpec.PASSPORT:       PhotoSpecConfig(413, 531, 50, 10, (255,255,255), 300),
    PhotoSpec.NSP:            PhotoSpecConfig(413, 531, 50, 10, (255,255,255), 300),
    PhotoSpec.UP_SCHOLARSHIP: PhotoSpecConfig(240, 240, 20,  5, (255,255,255), 200),
    PhotoSpec.SSC:            PhotoSpecConfig(472, 590, 50, 10, (255,255,255), 300),
    PhotoSpec.UPSC:           PhotoSpecConfig(413, 531, 50, 20, (255,255,255), 300),
    PhotoSpec.RAILWAY:        PhotoSpecConfig(413, 531, 100, 10, (255,255,255), 300),
}


@dataclass
class PhotoFixResult:
    success: bool
    image_bytes: bytes
    original_size_kb: float
    output_size_kb: float
    width: int
    height: int
    spec_applied: str
    issues_fixed: list[str]
    error: Optional[str] = None


def fix_photo(
    image_bytes: bytes,
    spec: PhotoSpec = PhotoSpec.NSP,
    custom_width: int = 413,
    custom_height: int = 531,
    custom_max_kb: int = 50,
    enhance: bool = True,
) -> PhotoFixResult:
    """
    Main entry point. Takes raw image bytes, returns government-spec JPEG.

    Steps:
    1. Load + orient (fix EXIF rotation from phone cameras)
    2. Detect and crop to face region
    3. Replace background with white
    4. Resize to spec dimensions
    5. Enhance (brightness/contrast if needed)
    6. Compress to target KB range
    """
    issues_fixed = []
    original_size_kb = len(image_bytes) / 1024

    try:
        img = Image.open(io.BytesIO(image_bytes)).convert("RGBA")

        # Fix EXIF rotation (phones often store rotation in metadata)
        img = ImageOps.exif_transpose(img)
        if img.size != Image.open(io.BytesIO(image_bytes)).size:
            issues_fixed.append("Fixed camera rotation")

        cfg = SPEC_MAP.get(spec) if spec != PhotoSpec.CUSTOM else PhotoSpecConfig(
            custom_width, custom_height, custom_max_kb, 5, (255,255,255), 300
        )

        # ── 1. Smart face crop ──────────────────────────────────────────────
        img = _smart_face_crop(img, cfg, issues_fixed)

        # ── 2. Background removal → white ──────────────────────────────────
        img = _replace_background(img, cfg.bg_color, issues_fixed)

        # ── 3. Resize to exact spec ─────────────────────────────────────────
        img_rgb = img.convert("RGB")
        img_rgb = img_rgb.resize((cfg.width_px, cfg.height_px), Resampling.LANCZOS)
        issues_fixed.append(f"Resized to {cfg.width_px}×{cfg.height_px}px")

        # ── 4. Enhance brightness/contrast ──────────────────────────────────
        if enhance:
            img_rgb = _auto_enhance(img_rgb, issues_fixed)

        # ── 5. Compress to target KB ─────────────────────────────────────────
        output_bytes, output_size_kb = _compress_to_target(
            img_rgb, cfg.min_kb, cfg.max_kb, issues_fixed
        )

        return PhotoFixResult(
            success=True,
            image_bytes=output_bytes,
            original_size_kb=round(original_size_kb, 1),
            output_size_kb=round(output_size_kb, 1),
            width=cfg.width_px,
            height=cfg.height_px,
            spec_applied=spec.value,
            issues_fixed=issues_fixed,
        )

    except Exception as e:
        return PhotoFixResult(
            success=False,
            image_bytes=b"",
            original_size_kb=round(original_size_kb, 1),
            output_size_kb=0,
            width=0,
            height=0,
            spec_applied=spec.value,
            issues_fixed=issues_fixed,
            error=str(e),
        )


def fix_signature(image_bytes: bytes, max_kb: int = 20) -> PhotoFixResult:
    """
    Signature-specific processor:
    - Converts to grayscale
    - Increases contrast so signature is crisp black on white
    - Trims whitespace
    - Resizes to 250×80px (standard government portal size)
    """
    issues_fixed = []
    original_size_kb = len(image_bytes) / 1024

    try:
        img = Image.open(io.BytesIO(image_bytes)).convert("L")  # grayscale
        img = ImageOps.exif_transpose(img)

        # High contrast: make signature black, background white
        enhancer = ImageEnhance.Contrast(img)
        img = enhancer.enhance(2.5)
        issues_fixed.append("Enhanced signature contrast")

        # Trim white border
        bg = Image.new("L", img.size, 255)
        diff = ImageOps.invert(img)
        bbox = diff.getbbox()
        if bbox:
            margin = 10
            bbox = (
                max(0, bbox[0] - margin),
                max(0, bbox[1] - margin),
                min(img.width, bbox[2] + margin),
                min(img.height, bbox[3] + margin),
            )
            img = img.crop(bbox)
            issues_fixed.append("Trimmed whitespace")

        img = img.resize((250, 80), Resampling.LANCZOS)
        img_rgb = Image.new("RGB", img.size, (255, 255, 255))
        img_rgb.paste(img)

        output_bytes, output_kb = _compress_to_target(img_rgb, 5, max_kb, issues_fixed)

        return PhotoFixResult(
            success=True,
            image_bytes=output_bytes,
            original_size_kb=round(original_size_kb, 1),
            output_size_kb=round(output_kb, 1),
            width=250,
            height=80,
            spec_applied="signature",
            issues_fixed=issues_fixed,
        )
    except Exception as e:
        return PhotoFixResult(
            success=False,
            image_bytes=b"",
            original_size_kb=round(original_size_kb, 1),
            output_size_kb=0,
            width=0,
            height=0,
            spec_applied="signature",
            issues_fixed=issues_fixed,
            error=str(e),
        )


# ── Private helpers ──────────────────────────────────────────────────────────

def _smart_face_crop(img: Image.Image, cfg: PhotoSpecConfig, issues: list) -> Image.Image:
    """
    Crops image to face-region proportions.
    Uses a heuristic center-top crop (face in upper 60% of frame) when
    no face detection library is available. Falls back to center crop.
    """
    target_ratio = cfg.width_px / cfg.height_px
    w, h = img.size
    current_ratio = w / h

    if abs(current_ratio - target_ratio) < 0.05:
        return img  # Already correct ratio

    if current_ratio > target_ratio:
        # Too wide — crop sides, keep vertical center
        new_w = int(h * target_ratio)
        left = (w - new_w) // 2
        img = img.crop((left, 0, left + new_w, h))
        issues.append("Cropped to portrait ratio")
    else:
        # Too tall — crop bottom (face is usually at top)
        new_h = int(w / target_ratio)
        top = 0
        img = img.crop((0, top, w, top + new_h))
        issues.append("Cropped to portrait ratio")

    return img


def _replace_background(img: Image.Image, bg_color: tuple, issues: list) -> Image.Image:
    """
    Simple background replacement using edge-flood fill from corners.
    Works well for photos taken against light/uniform backgrounds.
    For complex backgrounds, a rembg call would be ideal but adds ~500MB dependency.
    """
    rgba = img.convert("RGBA")
    data = rgba.load()
    w, h = rgba.size

    # Sample background color from 4 corners
    corner_colors = [
        data[0, 0][:3], data[w-1, 0][:3],
        data[0, h-1][:3], data[w-1, h-1][:3],
    ]
    avg_bg = tuple(sum(c[i] for c in corner_colors) // 4 for i in range(3))
    tolerance = 40

    def _is_bg(r, g, b):
        return all(abs(int(c) - int(avg_bg[i])) < tolerance for i, c in enumerate([r,g,b]))

    # Replace near-background pixels with white
    changed = False
    for y in range(h):
        for x in range(w):
            r, g, b, a = data[x, y]
            if _is_bg(r, g, b):
                data[x, y] = (*bg_color, 255)
                changed = True

    if changed:
        issues.append("Background replaced with white")

    # Composite onto white background
    result = Image.new("RGBA", rgba.size, (*bg_color, 255))
    result.paste(rgba, (0, 0), rgba)
    return result


def _auto_enhance(img: Image.Image, issues: list) -> Image.Image:
    """Auto-adjusts brightness and contrast for dark/overexposed photos."""
    # Check average brightness
    grayscale = img.convert("L")
    avg_brightness = sum(grayscale.getdata()) / (img.width * img.height)

    if avg_brightness < 100:  # Too dark
        img = ImageEnhance.Brightness(img).enhance(1.3)
        img = ImageEnhance.Contrast(img).enhance(1.15)
        issues.append("Brightened underexposed photo")
    elif avg_brightness > 200:  # Too bright/washed out
        img = ImageEnhance.Contrast(img).enhance(1.2)
        issues.append("Improved contrast for overexposed photo")

    # Slight sharpening for clarity
    img = img.filter(ImageFilter.UnsharpMask(radius=1, percent=120, threshold=3))
    return img


def _compress_to_target(
    img: Image.Image, min_kb: int, max_kb: int, issues: list
) -> tuple[bytes, float]:
    """Binary-search JPEG quality to land in [min_kb, max_kb] range."""
    lo, hi = 10, 95
    best_bytes = b""
    best_kb = 0.0

    for _ in range(8):  # Max 8 iterations
        quality = (lo + hi) // 2
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=quality, optimize=True)
        size_kb = buf.tell() / 1024
        buf.seek(0)
        best_bytes = buf.read()
        best_kb = size_kb

        if size_kb > max_kb:
            hi = quality - 1
        elif size_kb < min_kb and quality < 95:
            lo = quality + 1
        else:
            break

    issues.append(f"Compressed to {round(best_kb, 1)}KB (quality={quality})")
    return best_bytes, best_kb
