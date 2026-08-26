import 'dart:io';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../theme/app_theme.dart';

/// A single cover tile in the library grid.
/// Shows cover image if available, otherwise a text-based gradient fallback.
class BookCoverTile extends StatelessWidget {
  final Book book;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const BookCoverTile({super.key, required this.book, this.onTap, this.onLongPress});

  /// Generate a color based on the book's shelf name.
  Color _getShelfColor() {
    final shelf = book.shelf;
    switch (shelf) {
      case 'Sci-fi':
        return AppColors.coverPurple;
      case 'Classics':
        return AppColors.coverTeal;
      case 'Non-fiction':
        return AppColors.coverBlue;
      default:
        return AppColors.coverIndigo;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Hero(
          tag: 'book-cover-${book.id}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: _buildCover(),
          ),
        ),
      ),
    );
  }

  Widget _buildCover() {
    // Try to load cover image from file
    if (book.coverImagePath != null) {
      final file = File(book.coverImagePath!);
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildTextFallback(),
      );
    }
    return _buildTextFallback();
  }

  Widget _buildTextFallback() {
    final color = _getShelfColor();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.7),
          ],
        ),
      ),
      padding: const EdgeInsets.all(6),
      alignment: Alignment.bottomLeft,
      child: Text(
        book.title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// The dashed "add book" tile shown at the end of the grid.
class AddBookTile extends StatelessWidget {
  final VoidCallback? onTap;

  const AddBookTile({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: DottedBorderBox(color: theme.colorScheme.outlineVariant),
      ),
    );
  }
}

/// Simple dashed-border container.
class DottedBorderBox extends StatelessWidget {
  final Color color;

  const DottedBorderBox({super.key, this.color = const Color(0xFFE3E1DA)});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color),
      child: Center(
        child: Icon(Icons.add, size: 20, color: color),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;

  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(6),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
