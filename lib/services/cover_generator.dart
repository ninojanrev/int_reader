import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Generates a branded gradient cover (title initials + author) for books
/// without embedded cover art. Same technique as the launcher-icon
/// generator: offscreen canvas -> PNG bytes.
class CoverGenerator {
  CoverGenerator._();

  /// Render a [width]x[height] PNG cover. Returns PNG byte data.
  static Future<List<int>> generate({
    required String title,
    String author = '',
    int width = 600,
    int height = 900,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas =
        Canvas(recorder, Offset.zero & Size(width.toDouble(), height.toDouble()));

    // Gradient background (brand blues).
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF55A0F2), Color(0xFF2E6FBF)],
      ).createShader(Offset.zero & Size(width.toDouble(), height.toDouble()));
    canvas.drawRect(
        Offset.zero & Size(width.toDouble(), height.toDouble()), bgPaint);

    // Initials from the first two words of the title.
    final words =
        title.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    var initials = '';
    for (final w in words.take(2)) {
      initials += w[0].toUpperCase();
    }
    if (initials.isEmpty) initials = '?';

    // Title initials, centered slightly above middle.
    await _drawCenteredText(
      canvas,
      initials,
      fontSize: width * 0.30,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      center: Offset(width / 2, height * 0.44),
      maxWidth: width * 0.9,
    );

    // Divider.
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(width / 2, height * 0.55),
        width: width * 0.18,
        height: 4,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );

    // Author line.
    if (author.trim().isNotEmpty) {
      await _drawCenteredText(
        canvas,
        author.trim(),
        fontSize: width * 0.075,
        fontWeight: FontWeight.w500,
        color: Colors.white.withValues(alpha: 0.85),
        center: Offset(width / 2, height * 0.62),
        maxWidth: width * 0.85,
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  static Future<void> _drawCenteredText(
    Canvas canvas,
    String text, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    required Offset center,
    double? maxWidth,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: 1.1,
        ),
      ),
      textAlign: TextAlign.center,
      maxLines: 3,
      ellipsis: 'â€¦',
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: maxWidth ?? fontSize * text.length);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    return Future.value();
  }
}



