import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:epub_reader/branding/app_logo.dart';

/// One-shot generator: renders the Int Reader brand mark to the PNGs used
/// for launcher icons. Run with:
///   flutter test tool/generate_logo_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate launcher icon PNGs', () async {
    const outDir = 'assets/branding';
    Directory(outDir).createSync(recursive: true);

    // Square, full-bleed icon (launchers apply their own masking).
    await renderPainterToPng(
      AppLogoPainter(),
      1024,
      '$outDir/int_reader_icon.png',
    );

    // Adaptive-icon foreground: transparent background, mark inside the
    // safe zone (scaled into the central ~66%).
    final fgRecorder = ui.PictureRecorder();
    const side = 1024.0;
    final canvas = Canvas(fgRecorder, Offset.zero & const Size(side, side));
    canvas.save();
    const scale = 0.66;
    const offset = (side - side * scale) / 2;
    canvas.translate(offset, offset);
    canvas.scale(scale);
    AppLogoPainter(paintBackground: false)
        .paint(canvas, const Size.square(side));
    canvas.restore();
    final picture = fgRecorder.endRecording();
    final image = await picture.toImage(side.toInt(), side.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$outDir/int_reader_adaptive_foreground.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());

    expect(File('$outDir/int_reader_icon.png').lengthSync(), greaterThan(0));
    expect(File('$outDir/int_reader_adaptive_foreground.png').lengthSync(),
        greaterThan(0));
  });
}

