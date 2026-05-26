import 'dart:math';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class StorageRing extends StatelessWidget {
  final StorageStats stats;
  final double size;

  const StorageRing({super.key, required this.stats, this.size = 200});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(stats: stats),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${stats.reclaimableMB.toStringAsFixed(0)} MB',
                style: TextStyle(color: AppTheme.textPrimary,
                    fontSize: size * 0.12, fontWeight: FontWeight.w700),
              ),
              Text('reclaimable',
                style: TextStyle(color: AppTheme.textSecondary,
                    fontSize: size * 0.07)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final StorageStats stats;
  _RingPainter({required this.stats});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 18.0;

    final bgPaint = Paint()
      ..color = AppTheme.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final total = stats.totalBytes.toDouble();
    if (total == 0) return;

    void drawArc(double startAngle, double sweepAngle, Color color) {
      if (sweepAngle <= 0) return;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAngle, false, paint,
      );
    }

    const startAngle = -pi / 2;
    const fullCircle = 2 * pi;

    final duplicateSweep = (stats.duplicateBytes / total) * fullCircle;
    final otherSweep = ((stats.photoBytes - stats.duplicateBytes) / total) * fullCircle;

    double angle = startAngle;
    drawArc(angle, otherSweep.clamp(0, fullCircle), AppTheme.primary);
    angle += otherSweep;
    drawArc(angle, duplicateSweep.clamp(0, fullCircle), AppTheme.error);
  }

  @override
  bool shouldRepaint(_RingPainter old) => true;
}
