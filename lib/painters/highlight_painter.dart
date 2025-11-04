import 'package:flutter/material.dart';
import '../models/highlight_model.dart';

class HighlightPainter extends CustomPainter {
  final List<HighlightModel> highlights;
  final Size pageSize;
  final Offset? currentStart;
  final Offset? currentEnd;
  final Color? currentColor;
  final double currentStrokeWidth;
  final double currentOpacity;

  HighlightPainter({
    required this.highlights,
    required this.pageSize,
    this.currentStart,
    this.currentEnd,
    this.currentColor,
    this.currentStrokeWidth = 10.0,
    this.currentOpacity = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Usar el tamaño real del canvas
    final renderSize = pageSize.width > 0 ? pageSize : size;

    // Dibujar highlights guardados
    for (var highlight in highlights) {
      final paint = Paint()
        ..color = highlight.highlightColor.withValues(alpha: currentOpacity)
        ..strokeWidth = currentStrokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // Convertir coordenadas normalizadas a píxeles
      final start = Offset(
        highlight.startX * renderSize.width,
        highlight.startY * renderSize.height,
      );
      final end = Offset(
        highlight.endX * renderSize.width,
        highlight.endY * renderSize.height,
      );

      canvas.drawLine(start, end, paint);
    }

    // Dibujar highlight temporal (mientras el usuario está dibujando)
    if (currentStart != null && currentEnd != null && currentColor != null) {
      final paint = Paint()
        ..color = currentColor!.withValues(alpha: currentOpacity)
        ..strokeWidth = currentStrokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(currentStart!, currentEnd!, paint);
    }
  }

  @override
  bool shouldRepaint(covariant HighlightPainter oldDelegate) {
    return oldDelegate.highlights != highlights ||
        oldDelegate.currentStart != currentStart ||
        oldDelegate.currentEnd != currentEnd ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.currentStrokeWidth != currentStrokeWidth ||
        oldDelegate.currentOpacity != currentOpacity;
  }
}
