import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/book.dart';

/// Decorative home-screen backdrop: the library's covers arranged in
/// tilted columns that drift slowly in a seamless loop. Purely visual —
/// pointer events are ignored by the parent stack.
///
/// Performance: the tile tree is built ONCE (per books/size change); the
/// animation only applies translate offsets to pre-built subtrees. No
/// synchronous file I/O happens during animation.
class CoverBackdrop extends StatefulWidget {
  final List<Book> books;
  const CoverBackdrop({super.key, required this.books});

  @override
  State<CoverBackdrop> createState() => _CoverBackdropState();
}

class _CoverBackdropState extends State<CoverBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final math.Random _rng = math.Random(42); // stable layout per session

  static const _tileW = 92.0;
  static const _tileH = 138.0;
  static const _gap = 14.0;
  static const _angle = -0.21; // ~-12 degrees

  // Pre-built tile lists per column; invalidated on input changes.
  List<Book> _cachedBooks = const [];
  double _cachedHeight = -1;
  double _columnLoopH = 1;
  List<List<Widget>> _columns = const [];

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 36))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CoverBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.books, widget.books)) {
      _columns = const [];
    }
  }

  Widget _coverTile(BuildContext context, Book book) {
    final theme = Theme.of(context);
    final path = book.coverImagePath;
    Widget inner = _placeholder(theme, book);
    if (path != null) {
      // Missing/corrupt files degrade to the placeholder via errorBuilder —
      // no synchronous existence checks in the hot path.
      inner = Image.file(
        File(path),
        width: _tileW,
        height: _tileH,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(theme, book),
      );
    }
    return Container(
      margin: const EdgeInsets.all(_gap / 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: inner,
    );
  }

  Widget _placeholder(ThemeData theme, Book book) {
    return Container(
      width: _tileW,
      height: _tileH,
      color: theme.colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        book.title.isNotEmpty ? book.title[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  /// Build all column subtrees once per (books, size) change.
  void _buildColumns(BoxConstraints constraints) {
    final books = [...widget.books]..shuffle(_rng);
    final gridW = constraints.maxWidth * math.sqrt2;
    final cols = (gridW / (_tileW + _gap)).ceil() + 1;
    final loopRows = (constraints.maxHeight / (_tileH + _gap)).ceil() + 2;

    final columns = <List<Widget>>[];
    for (var c = 0; c < cols; c++) {
      columns.add([
        // Content duplicated once so shifting by up to one loop-height
        // always stays covered.
        for (var r = 0; r < loopRows * 2; r++)
          _coverTile(context, books[(c * 7 + r) % books.length]),
      ]);
    }
    _columns = columns;
    _columnLoopH = loopRows * (_tileH + _gap);
    _cachedBooks = widget.books;
    _cachedHeight = constraints.maxHeight;
  }

  /// Vertical offset of a column. Alternating columns drift in opposite
  /// directions (subtle parallax); each loops seamlessly over one
  /// column height because the tile sequence is doubled.
  double _columnTop(int col, double loopH) {
    final t = _controller.value;
    return col.isOdd ? -t * loopH : -(1 - t) * loopH;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.books.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(builder: (context, constraints) {
      final needsRebuild = _columns.isEmpty ||
          !identical(_cachedBooks, widget.books) ||
          _cachedHeight != constraints.maxHeight;
      if (needsRebuild) {
        _buildColumns(constraints);
      }
      final loopH = _columnLoopH;

      return ClipRect(
        child: RepaintBoundary(
          child: Transform.rotate(
            angle: _angle,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: constraints.maxWidth * math.sqrt2,
              height: constraints.maxHeight + loopH,
              child: AnimatedBuilder(
                animation: _controller,
                // Per-frame work: reposition PRE-BUILT column subtrees.
                builder: (context, _) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var c = 0; c < _columns.length; c++)
                        Positioned(
                          left: c * (_tileW + _gap),
                          top: _columnTop(c, loopH),
                          child: Column(children: _columns[c]),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    });
  }
}
