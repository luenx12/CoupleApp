import 'dart:ui';
import 'package:flutter/material.dart';
import '../../domain/draw_game_model.dart';
import '../../../../core/theme/app_theme.dart';

class DrawCanvasPainter extends CustomPainter {
  DrawCanvasPainter({
    required this.localStrokes,
    required this.remoteStrokes,
    this.currentStroke,
  });

  final List<DrawStroke> localStrokes;
  final List<DrawStroke> remoteStrokes;
  final DrawStroke? currentStroke;

  @override
  void paint(Canvas canvas, Size size) {
    // Fill background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = AppColors.card);

    // Draw all strokes (remote + local)
    for (var stroke in remoteStrokes) {
      _paintStroke(canvas, stroke);
    }
    
    for (var stroke in localStrokes) {
      _paintStroke(canvas, stroke);
    }

    // Draw current active stroke
    if (currentStroke != null) {
      _paintStroke(canvas, currentStroke!);
    }
  }

  void _paintStroke(Canvas canvas, DrawStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.isEraser ? AppColors.card : stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.points.length == 1) {
      // Draw a single dot
      canvas.drawPoints(PointMode.points, stroke.points, paint);
      return;
    }

    final path = Path();
    path.moveTo(stroke.points.first.dx, stroke.points.first.dy);

    // simple interpolation / smoothing could be applied here if needed
    for (var i = 1; i < stroke.points.length; i++) {
        // Simple straight line interpolation for now. 
        // Can be upgraded to quadraticBezierTo for smoother paths.
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DrawCanvasPainter oldDelegate) {
     return true; // Repaint often for real-time smoothness
  }
}
