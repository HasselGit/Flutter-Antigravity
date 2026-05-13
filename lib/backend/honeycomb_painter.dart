
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui';

class HoneycombPainter extends CustomPainter {
  final Color color;
  static Picture? _cachedPicture;
  static Color? _cachedColor;

  HoneycombPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (_cachedPicture != null && _cachedColor == color) {
      canvas.drawPicture(_cachedPicture!);
      return;
    }

    _cachedColor = color;

    final recorder = PictureRecorder();
    final recordingCanvas = Canvas(recorder);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const radius = 30.0;
    final double hexWidth = radius * 1.732;
    final double hexHeight = radius * 2;
    final double verticalSpacing = hexHeight * 0.75;

    for (double y = -radius; y < 2000; y += verticalSpacing) {
      bool offset = ((y / verticalSpacing).round() % 2 == 0);
      for (double x = -hexWidth; x < 1500; x += hexWidth) {
        double cx = x + (offset ? hexWidth / 2 : 0);
        _drawHexagon(recordingCanvas, Offset(cx, y), radius, paint);
      }
    }

    _cachedPicture = recorder.endRecording();
    canvas.drawPicture(_cachedPicture!);
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      double angle = (pi / 3) * i - (pi / 2);
      double x = center.dx + radius * cos(angle);
      double y = center.dy + radius * sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant HoneycombPainter oldDelegate) => oldDelegate.color != color;
}
