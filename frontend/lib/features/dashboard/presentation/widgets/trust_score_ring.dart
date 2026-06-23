import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class TrustScoreRing extends StatelessWidget {
  final int score;
  const TrustScoreRing({super.key, required this.score});

  Color get _color {
    if (score >= 80) return AppColors.trustGold;
    if (score >= 60) return AppColors.success;
    if (score >= 40) return AppColors.warning;
    return AppColors.error;
  }

  String get _badge {
    if (score >= 80) return '🥇';
    if (score >= 60) return '🥈';
    if (score >= 40) return '🥉';
    return '🔰';
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Trust Score: $score/100',
      child: SizedBox(
        width: 52,
        height: 52,
        child: CustomPaint(
          painter: _RingPainter(progress: score / 100, color: _color),
          child: Center(
            child: Text(_badge, style: const TextStyle(fontSize: 20)),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 6) / 2;
    final paint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Background ring
    paint.color = AppColors.divider;
    canvas.drawCircle(center, radius, paint);

    // Progress arc
    paint.color = color;
    paint.shader = SweepGradient(
      colors: [color.withOpacity(0.5), color],
      startAngle: -pi / 2,
      endAngle: -pi / 2 + 2 * pi * progress,
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
