import 'package:flutter/material.dart';

/// Draws two semi-transparent vertical panels on the left and right edges,
/// narrowing the visible reading area to create a "focus tunnel" that
/// guides the reader's eye to the centre of the page.
///
/// The [padding] controls how far inward the guide lines sit from each edge.
/// The [lineWidth] controls the thickness of each guide line.
class PerceptionExpander extends StatelessWidget {
  final double padding;
  final double lineWidth;
  final Color color;

  const PerceptionExpander({
    super.key,
    this.padding = 48,
    this.lineWidth = 1.5,
    this.color = const Color(0x33000000),
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          return Stack(
            children: [
              // Left panel
              Positioned(
                left: 0,
                top: 0,
                width: padding,
                height: h,
                child: Container(color: color),
              ),
              // Left guide line
              Positioned(
                left: padding,
                top: 0,
                width: lineWidth,
                height: h,
                child: Container(color: color.withValues(alpha: 0.5)),
              ),
              // Right panel
              Positioned(
                right: 0,
                top: 0,
                width: padding,
                height: h,
                child: Container(color: color),
              ),
              // Right guide line
              Positioned(
                right: padding,
                top: 0,
                width: lineWidth,
                height: h,
                child: Container(color: color.withValues(alpha: 0.5)),
              ),
            ],
          );
        },
      ),
    );
  }
}
