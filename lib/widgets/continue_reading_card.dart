import 'dart:io';
import 'package:flutter/material.dart';
import '../models/book.dart';

/// The "continue reading" card shown at the top of the home screen —
/// cover image, title/author, and a progress bar.
class ContinueReadingCard extends StatelessWidget {
  final Book book;
  final VoidCallback? onTap;

  const ContinueReadingCard({super.key, required this.book, this.onTap});

  /// Generate a color based on the book's shelf name.
  Color _getShelfColor() {
    switch (book.shelf) {
      case 'Sci-fi':
        return const Color(0xFF7F77DD);
      case 'Classics':
        return const Color(0xFF1D9E75);
      case 'Non-fiction':
        return const Color(0xFF4A90D9);
      default:
        return const Color(0xFF5C6BC0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (book.progress * 100).round();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'book-cover-${book.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 52,
                  height: 78,
                  child: _buildCover(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.author,
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: book.progress,
                      minHeight: 4,
                      backgroundColor: theme.colorScheme.outlineVariant,
                      valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Chapter ${book.currentChapter + 1} · $percent%',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover() {
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
          colors: [color, color.withValues(alpha: 0.7)],
        ),
      ),
      padding: const EdgeInsets.all(4),
      alignment: Alignment.bottomLeft,
      child: Text(
        book.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 8,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
