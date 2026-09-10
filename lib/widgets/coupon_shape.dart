import 'package:flutter/material.dart';
import 'package:delivery_app_v2/theme/app_theme.dart';

/// Forma de cupón: muescas circulares semicircular a cada lado,
/// en la altura de la línea de recorte.
class CouponClipper extends CustomClipper<Path> {
  // Altura de la cabecera coloreada + mitad del divisor.
  static const double notchY = 74.0;
  static const double notchR = 12.0;

  @override
  Path getClip(Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(AppRadii.card),
      ));

    // Restar (con evenOdd) los dos círculos de las muescas.
    path.addOval(Rect.fromCircle(
      center: const Offset(0, notchY),
      radius: notchR,
    ));
    path.addOval(Rect.fromCircle(
      center: Offset(size.width, notchY),
      radius: notchR,
    ));
    path.fillType = PathFillType.evenOdd;
    return path;
  }

  @override
  bool shouldReclip(covariant CouponClipper oldClipper) => false;
}

/// Línea de recorte: punteada + dos círculos del color del fondo que
/// simulan el "recorte" del ticket.
class CouponDivider extends StatelessWidget {
  const CouponDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      width: double.infinity,
      child: CustomPaint(painter: _CouponDividerPainter()),
    );
  }
}

class _CouponDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;

    // Muescas: círculos del color del fondo de la pantalla (fingir hueco).
    final hole = Paint()..color = AppColors.background;
    canvas.drawCircle(Offset(0, CouponClipper.notchY - y + y), 12, hole);
    // Las muescas están a altura fija (notchY del clipper); alineadas acá:
    canvas.drawCircle(const Offset(0, 12), 12, hole);
    canvas.drawCircle(Offset(size.width, 12), 12, hole);

    // Línea punteada
    final dash = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const step = 8.0;
    for (double x = 20; x < size.width - 20; x += step) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x + 4, y),
        dash,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CouponDividerPainter oldDelegate) => false;
}
