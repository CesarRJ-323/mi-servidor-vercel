import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Patrón decorativo de fondo estilo "doodle delivery": motos, cajas,
/// puntos y rayitas dibujados con CustomPainter (equivalente vectorial
/// de un SVG, sin dependencias externas).
class LoginPatternPainter extends CustomPainter {
  final Color strokeColor;
  LoginPatternPainter({this.strokeColor = const Color(0x22FFFFFF)});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final fill = Paint()..color = strokeColor;

    // Retícula de celdas; en cada celda un doodle según (col+fila) % 4.
    const cell = 110.0;
    final cols = (size.width / cell).ceil() + 1;
    final rows = (size.height / cell).ceil() + 1;
    final rnd = math.Random(7); // seed fija: patrón estable

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final ox = c * cell + (r.isOdd ? cell / 2 : 0);
        final oy = r * cell;
        final kind = rnd.nextInt(4);
        canvas.save();
        canvas.translate(ox, oy);
        switch (kind) {
          case 0:
            _dibujarMoto(canvas, stroke);
          case 1:
            _dibujarCaja(canvas, stroke);
          case 2:
            _dibujarChispa(canvas, fill);
          case 3:
            _dibujarRayitas(canvas, stroke);
        }
        canvas.restore();
      }
    }
  }

  // Moto de delivery chiquita.
  void _dibujarMoto(Canvas canvas, Paint p) {
    canvas.drawCircle(const Offset(16, 34), 8, p);
    canvas.drawCircle(const Offset(52, 34), 8, p);
    final body = Path()
      ..moveTo(16, 34)
      ..lineTo(28, 20)
      ..lineTo(40, 20)
      ..lineTo(46, 26)
      ..lineTo(52, 34);
    canvas.drawPath(body, p);
    // caja de delivery
    canvas.drawRect(const Rect.fromLTWH(30, 10, 14, 10), p);
    // manubrio
    canvas.drawLine(const Offset(44, 18), const Offset(50, 12), p);
  }

  // Caja / paquete con cinta.
  void _dibujarCaja(Canvas canvas, Paint p) {
    canvas.drawRect(const Rect.fromLTWH(18, 14, 28, 24), p);
    canvas.drawLine(const Offset(18, 22), const Offset(46, 22), p);
    canvas.drawLine(const Offset(32, 14), const Offset(32, 38), p);
  }

  // Chispa / estrellita de 4 puntas.
  void _dibujarChispa(Canvas canvas, Paint p) {
    final path = Path()
      ..moveTo(32, 16)
      ..quadraticBezierTo(34, 30, 46, 32)
      ..quadraticBezierTo(34, 34, 32, 48)
      ..quadraticBezierTo(30, 34, 18, 32)
      ..quadraticBezierTo(30, 30, 32, 16)
      ..close();
    canvas.drawPath(path, p);
  }

  // Tres rayitas de velocidad (sensación de movimiento).
  void _dibujarRayitas(Canvas canvas, Paint p) {
    canvas.drawLine(const Offset(14, 20), const Offset(44, 20), p);
    canvas.drawLine(const Offset(20, 30), const Offset(50, 30), p);
    canvas.drawLine(const Offset(14, 40), const Offset(38, 40), p);
  }

  @override
  bool shouldRepaint(covariant LoginPatternPainter oldDelegate) =>
      oldDelegate.strokeColor != strokeColor;
}
