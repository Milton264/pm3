import 'dart:math' as math;

import 'package:flutter/material.dart';

const ink = Color(0xFF302626);
const plum = Color(0xFF683D4B);
const paper = Color(0xFFFAF7F2);
const blush = Color(0xFFEAD6D4);
const muted = Color(0xFF837773);
const line = Color(0xFFE5DDD5);
const green = Color(0xFF377657);
const red = Color(0xFFAC4B4C);

TextStyle editorial(
  double size, {
  Color color = ink,
  FontStyle style = FontStyle.normal,
  double height = 1.04,
}) => TextStyle(
  fontFamily: 'Editorial',
  fontSize: size,
  color: color,
  fontStyle: style,
  height: height,
  letterSpacing: -1.1,
);

ThemeData musaTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: paper,
  fontFamily: 'Atelier',
  colorScheme: ColorScheme.fromSeed(
    seedColor: plum,
    primary: plum,
    surface: paper,
  ),
  splashFactory: InkRipple.splashFactory,
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 15, color: ink, height: 1.45),
    bodySmall: TextStyle(fontSize: 12, color: muted, height: 1.4),
    titleMedium: TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 16,
      color: ink,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: paper,
    foregroundColor: ink,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
  ),
  dividerColor: line,
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: paper,
    modalBackgroundColor: paper,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    showDragHandle: true,
    elevation: 0,
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: ink,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    labelStyle: const TextStyle(color: muted),
    hintStyle: const TextStyle(color: muted, fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: plum),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: plum,
      foregroundColor: Colors.white,
      minimumSize: const Size(48, 54),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      elevation: 0,
      textStyle: const TextStyle(
        fontFamily: 'Atelier',
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: ink,
      minimumSize: const Size(48, 50),
      side: const BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: Colors.transparent,
    selectedColor: plum,
    side: const BorderSide(color: line),
    labelStyle: const TextStyle(fontFamily: 'Atelier', fontSize: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
  ),
);

class MuseMark extends StatelessWidget {
  final double size;
  final Color color;
  const MuseMark({super.key, this.size = 28, this.color = plum});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _Flower(color));
}

class _Flower extends CustomPainter {
  final Color color;
  _Flower(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width / 30;
    for (var i = 0; i < 7; i++) {
      canvas.save();
      canvas.rotate(math.pi * 2 * i / 7);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -size.width * .23),
          width: size.width * .24,
          height: size.height * .49,
        ),
        pen,
      );
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, size.width * .06, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _Flower old) => old.color != color;
}

class HangerArt extends StatelessWidget {
  final double height;
  const HangerArt({super.key, this.height = 180});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: 260,
    child: CustomPaint(painter: _Hanger()),
  );
}

class _Hanger extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    canvas.save();
    canvas.scale(s.width / 260, s.height / 200);
    canvas.drawOval(
      const Rect.fromLTWH(20, 10, 220, 175),
      Paint()..color = blush.withValues(alpha: .6),
    );
    final p = Paint()
      ..color = plum
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final hook = Path()
      ..moveTo(112, 56)
      ..cubicTo(106, 26, 151, 21, 150, 48)
      ..cubicTo(149, 64, 130, 62, 130, 80);
    canvas.drawPath(hook, p);
    final hanger = Path()
      ..moveTo(130, 80)
      ..lineTo(39, 132)
      ..quadraticBezierTo(29, 145, 47, 145)
      ..lineTo(211, 145)
      ..quadraticBezierTo(230, 145, 217, 132)
      ..close();
    canvas.drawPath(hanger, p);
    final cloth = Path()
      ..moveTo(101, 102)
      ..quadraticBezierTo(126, 115, 153, 102)
      ..lineTo(176, 164)
      ..quadraticBezierTo(131, 180, 84, 164)
      ..close();
    canvas.drawPath(cloth, Paint()..color = paper);
    canvas.drawPath(cloth, p);
    canvas.drawLine(const Offset(107, 125), const Offset(98, 160), p);
    canvas.drawLine(const Offset(145, 125), const Offset(155, 160), p);
    for (final point in [
      const Offset(35, 58),
      const Offset(209, 52),
      const Offset(226, 164),
    ]) {
      canvas.drawLine(
        point - const Offset(5, 0),
        point + const Offset(5, 0),
        p,
      );
      canvas.drawLine(
        point - const Offset(0, 5),
        point + const Offset(0, 5),
        p,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
