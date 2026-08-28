import 'package:flutter/material.dart';

/// Limits the visible reading area to a horizontal band, dimming
/// everything above and below. Creates a "reading ruler" effect that
/// helps the reader focus on a few lines at a time.
///
/// [bandHeight] is the height of the clear reading area in logical pixels.
/// [offset] shifts the band up or down from vertical centre.
/// [showRulers] draws thin lines at the top and bottom of the band.
class HorizontalLimiter extends StatelessWidget {
  final double bandHeight;
  final double offset;
  final bool showRulers;
  final Color dimColor;
  final double rulerThickness;

  const HorizontalLimiter({
    super.key,
    this.bandHeight = 120,
    this.offset = 0,
    this.showRulers = true,
    this.dimColor = const Color(0x55000000),
    this.rulerThickness = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final centre = h / 2 + offset;
          final bandTop = (centre - bandHeight / 2).clamp(0.0, h);
          final bandBottom = (centre + bandHeight / 2).clamp(0.0, h);
          final rulerColor = Theme.of(context).colorScheme.outlineVariant;

          return Stack(
            children: [
              // Dim above
              if (bandTop > 0)
                Positioned(
                  left: 0, top: 0,
                  width: w, height: bandTop,
                  child: Container(color: dimColor),
                ),
              // Dim below
              if (bandBottom < h)
                Positioned(
                  left: 0, top: bandBottom,
                  width: w, height: h - bandBottom,
                  child: Container(color: dimColor),
                ),
              // Top ruler
              if (showRulers && bandTop > 0)
                Positioned(
                  left: 0, top: bandTop - rulerThickness,
                  width: w, height: rulerThickness,
                  child: Container(color: rulerColor),
                ),
              // Bottom ruler
              if (showRulers && bandBottom < h)
                Positioned(
                  left: 0, top: bandBottom,
                  width: w, height: rulerThickness,
                  child: Container(color: rulerColor),
                ),
            ],
          );
        },
      ),
    );
  }
}
