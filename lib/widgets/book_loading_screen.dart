import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/reader_options.dart';

/// Animated loading screen shown while an EPUB is being parsed.
/// Displays the book cover (if available) with a subtle pulse and a
/// colourful wave-ripple loader beneath it.
class BookLoadingScreen extends StatefulWidget {
  final String bookTitle;
  final String? coverImagePath;
  final ReaderTheme theme;

  const BookLoadingScreen({
    super.key,
    required this.bookTitle,
    this.coverImagePath,
    required this.theme,
  });

  @override
  State<BookLoadingScreen> createState() => _BookLoadingScreenState();
}

class _BookLoadingScreenState extends State<BookLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rippleCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Scaffold(
      backgroundColor: theme.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, child) {
                final scale = 1.0 + _pulseCtrl.value * 0.03;
                return Transform.scale(scale: scale, child: child);
              },
              child: _buildCover(theme),
            ),
            const SizedBox(height: 24),
            Text(
              widget.bookTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.text,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 13,
                color: theme.text.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 32),
            AnimatedWaveRipple(
              size: 80,
              duration: const Duration(seconds: 3),
              color: theme.text,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(ReaderTheme theme) {
    if (widget.coverImagePath != null) {
      final file = File(widget.coverImagePath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: 120,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackCover(theme),
          ),
        );
      }
    }
    return _fallbackCover(theme);
  }

  Widget _fallbackCover(ReaderTheme theme) {
    return Container(
      width: 120,
      height: 180,
      decoration: BoxDecoration(
        color: theme.text.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.auto_stories,
        size: 48,
        color: theme.text.withValues(alpha: 0.3),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wave Ripple Loader (adapted from flutterfx/flutterfx_widgets)
// ---------------------------------------------------------------------------

class AnimatedWaveRipple extends StatefulWidget {
  final double size;
  final Duration duration;
  final Color color;

  const AnimatedWaveRipple({
    super.key,
    this.size = 80,
    this.duration = const Duration(seconds: 3),
    this.color = Colors.black,
  });

  @override
  State<AnimatedWaveRipple> createState() => _AnimatedWaveRippleState();
}

class _AnimatedWaveRippleState extends State<AnimatedWaveRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const _layerCount = 10;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  Color _colorFor(int index) {
    final hue = _lerp(350.0, 40.0,
        ((index / _layerCount) - _ctrl.value) % 1.0);
    final hsl = HSLColor.fromAHSL(
      0.7,
      hue < 0 ? hue + 360 : hue,
      0.85,
      0.58,
    );
    return Color.lerp(hsl.toColor(), widget.color, 0.4)!;
  }

  double _sizeMultiplier(double pos) {
    final angle = pos * math.pi - (math.pi / 2);
    return 0.4 + math.cos(angle) * 0.6;
  }

  double _heightMultiplier(double pos) {
    final angle = pos * math.pi - (math.pi / 2);
    return 0.15 + math.cos(angle) * 0.1;
  }

  double _fadeOpacity(double pos) {
    if (pos < 0.1) return pos / 0.1;
    if (pos > 0.9) return 1.0 - ((pos - 0.9) / 0.1);
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: List.generate(_layerCount, (i) {
              final basePos = i / (_layerCount - 1);
              final pos = (basePos - _ctrl.value) % 1.0;
              final sm = _sizeMultiplier(pos);
              final w = widget.size * 0.95 * sm;
              final h = w * _heightMultiplier(pos);
              final spacing = widget.size / (_layerCount + 1);
              final top = spacing + pos * widget.size * (_layerCount - 1) / (_layerCount + 1);
              return Positioned(
                top: top - h / 2,
                child: Opacity(
                  opacity: _fadeOpacity(pos),
                  child: CustomPaint(
                    size: Size(w, h),
                    painter: _EllipsePainter(color: _colorFor(i)),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _EllipsePainter extends CustomPainter {
  final Color color;
  _EllipsePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width,
      height: size.height,
    );
    canvas.drawOval(rect, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_EllipsePainter old) => color != old.color;
}
