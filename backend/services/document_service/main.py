"""
FillFormAI - Document Service (port 8005)
Handles: OCR, extraction, verification, AI Photo Fixer, signature processor
"""

import logging
import uuid
from typing import Optional

import boto3
from botocore.config import Config
from fastapi import FastAPI, Depends, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel

from backend.shared.config.settings import settings
from backend.shared.middleware.auth import get_current_user
from backend.services.document_service.photo_fixer import (
    PhotoSpec,
    fix_photo,
    fix_signature,
    PhotoFixResult,
)

logger = logging.getLogger(__name__)

app = FastAPI(title="FillFormAI - Document Service", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def get_s3():
    return boto3.client(
        "s3",
        endpoint_url=settings.s3_endpoint_url or None,
        aws_access_key_id=settings.aws_access_key_id,
        aws_secret_access_key=settings.aws_secret_access_key,
        region_name=settings.aws_region,
        config=Config(signature_version="s3v4"),
    )


class PhotoFixResponse(BaseModel):
    success: bool
    original_size_kb: float
    output_size_kb: float
    width: int
    height: int
    spec_applied: str
    issues_fixed: list[str]
    download_url: Optional[str] = None
    error: Optional[str] = None


@app.get("/health")
async def health():
    return {"status": "ok", "service": "document-service"}


# ── AI Photo Fixer ────────────────────────────────────────────────────────────


@app.post("/api/v1/documents/fix-photo", response_model=PhotoFixResponse)
async def fix_passport_photo(
    file: UploadFile = File(...),
    spec: PhotoSpec = Form(PhotoSpec.NSP),
    current_user=Depends(get_current_user),
):
    """
    Fix a passport photo to government portal specifications.
    Accepts JPEG/PNG. Returns processed JPEG.

    Spec options: passport, nsp, up_scholarship, ssc, upsc, railway
    """
    if file.content_type not in ("image/jpeg", "image/jpg", "image/png", "image/webp"):
        raise HTTPException(400, "Only JPEG, PNG, or WebP images are accepted")

    max_upload_mb = 10
    content = await file.read()
    if len(content) > max_upload_mb * 1024 * 1024:
        raise HTTPException(400, f"File too large — max {max_upload_mb}MB")

    result: PhotoFixResult = fix_photo(content, spec=spec)

    if not result.success:
        raise HTTPException(422, f"Photo processing failed: {result.error}")

    # Upload fixed photo to S3
    s3_key = f"photos/{current_user.id}/fixed_{spec.value}_{uuid.uuid4().hex[:8]}.jpg"
    try:
        s3 = get_s3()
        s3.put_object(
            Bucket=settings.s3_bucket,
            Key=s3_key,
            Body=result.image_bytes,
            ContentType="image/jpeg",
            Metadata={"user_id": str(current_user.id), "spec": spec.value},
        )
        download_url = f"/api/v1/documents/download/{s3_key}"
    except Exception:
        logger.warning("S3 upload failed, returning inline only")
        download_url = None

    return PhotoFixResponse(
        success=True,
        original_size_kb=result.original_size_kb,
        output_size_kb=result.output_size_kb,
        width=result.width,
        height=result.height,
        spec_applied=result.spec_applied,
        issues_fixed=result.issues_fixed,
        download_url=download_url,
    )


@app.post("/api/v1/documents/fix-photo/preview")
async def fix_photo_preview(
    file: UploadFile = File(...),
    spec: PhotoSpec = Form(PhotoSpec.NSP),
    current_user=Depends(get_current_user),
):
    """Returns the processed image bytes directly (for in-browser preview)."""
    content = await file.read()
    result = fix_photo(content, spec=spec)
    if not result.success:
        raise HTTPException(422, result.error)
    return Response(content=result.image_bytes, media_type="image/jpeg")


@app.post("/api/v1/documents/fix-signature", response_model=PhotoFixResponse)
async def fix_signature_endpoint(
    file: UploadFile = File(...),
    current_user=Depends(get_current_user),
):
    """
    Process a signature image: grayscale, high contrast, trim whitespace,
    resize to 250×80px (standard government portal spec).
    """
    content = await file.read()
    result = fix_signature(content)
    if not result.success:
        raise HTTPException(422, result.error)

    s3_key = f"signatures/{current_user.id}/sig_{uuid.uuid4().hex[:8]}.jpg"
    try:
        s3 = get_s3()
        s3.put_object(
            Bucket=settings.s3_bucket,
            Key=s3_key,
            Body=result.image_bytes,
            ContentType="image/jpeg",
        )
        download_url = f"/api/v1/documents/download/{s3_key}"
    except Exception:
        download_url = None

    return PhotoFixResponse(
        success=True,
        original_size_kb=result.original_size_kb,
        output_size_kb=result.output_size_kb,
        width=result.width,
        height=result.height,
        spec_applied="signature",
        issues_fixed=result.issues_fixed,
        download_url=download_url,
    )


@app.get("/api/v1/documents/photo-specs")
async def get_photo_specs():
    """Returns all supported government portal photo specifications."""
    return {
        "specs": [
            {
                "id": "nsp",
                "name": "NSP / National Scholarship Portal",
                "size": "3.5×4.5cm",
                "max_kb": 50,
                "bg": "White",
            },
            {
                "id": "passport",
                "name": "Passport / Visa Photo",
                "size": "35×45mm",
                "max_kb": 50,
                "bg": "White",
            },
            {
                "id": "up_scholarship",
                "name": "UP Scholarship Portal",
                "size": "2×2 inch",
                "max_kb": 20,
                "bg": "White",
            },
            {
                "id": "ssc",
                "name": "SSC / IBPS / Bank Exams",
                "size": "4×5cm",
                "max_kb": 50,
                "bg": "White",
            },
            {
                "id": "upsc",
                "name": "UPSC / IAS Exam",
                "size": "3.5×4.5cm",
                "max_kb": 50,
                "bg": "White",
            },
            {
                "id": "railway",
                "name": "Railway / RRB Exams",
                "size": "3.5×4.5cm",
                "max_kb": 100,
                "bg": "White",
            },
        ]
    }
