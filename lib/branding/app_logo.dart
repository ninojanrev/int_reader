import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';

/// The "Int Reader" brand mark: an open white book whose spine rises into
/// a lowercase "i" (for *Int*), on a blue gradient tile matching the app
/// accent. Geometry mirrors assets/branding/int_reader_logo.svg.
class AppLogoPainter extends CustomPainter {
  /// When false, only the mark is painted (transparent background) â€” used
  /// for adaptive-icon foregrounds.
  final bool paintBackground;

  AppLogoPainter({this.paintBackground = true});

  static const gradientTop = Color(0xFF55A0F2);
  static const gradientBottom = Color(0xFF2E6FBF);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 512;
    canvas.scale(scale);

    if (paintBackground) {
      final bgPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [gradientTop, gradientBottom],
        ).createShader(Offset.zero & const Size(512, 512));
      final rrect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 512, 512),
        const Radius.circular(116),
      );
      canvas.drawRRect(rrect, bgPaint);
    }

    final white = Paint()..color = Colors.white;

    // i dot
    canvas.drawCircle(const Offset(256, 112), 22, white);

    // i stem (rounded rect)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(243, 152, 26, 192),
        const Radius.circular(13),
      ),
      white,
    );

    // Open book pages
    final leftPage = Path()
      ..moveTo(243, 344)
      ..quadraticBezierTo(178, 306, 92, 316)
      ..lineTo(92, 380)
      ..quadraticBezierTo(178, 370, 243, 408)
      ..close();
    final rightPage = Path()
      ..moveTo(269, 344)
      ..quadraticBezierTo(334, 306, 420, 316)
      ..lineTo(420, 380)
      ..quadraticBezierTo(334, 370, 269, 408)
      ..close();
    canvas.drawPath(leftPage, white);
    canvas.drawPath(rightPage, white);

    // Page-edge shadow under the book
    final shadow = Paint()
      ..color = const Color(0xFF1E5AA8).withValues(alpha: 0.55);
    final edge = Path()
      ..moveTo(104, 392)
      ..quadraticBezierTo(186, 384, 256, 418)
      ..quadraticBezierTo(326, 384, 408, 392)
      ..lineTo(408, 404)
      ..quadraticBezierTo(330, 396, 256, 432)
      ..quadraticBezierTo(182, 396, 104, 404)
      ..close();
    canvas.drawPath(edge, shadow);
  }

  @override
  bool shouldRepaint(covariant AppLogoPainter oldDelegate) =>
      oldDelegate.paintBackground != paintBackground;
}

/// Ready-to-drop-in widget (e.g. About dialogs, splash screens).
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: AppLogoPainter(),
    );
  }
}

/// Renders [painter] to a PNG file at [side]x[side] pixels.
Future<void> renderPainterToPng(
  CustomPainter painter,
  int side,
  String outputPath,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & Size(side.toDouble(), side.toDouble()));
  painter.paint(canvas, Size.square(side.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(side, side);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(outputPath).writeAsBytesSync(bytes!.buffer.asUint8List());
}

