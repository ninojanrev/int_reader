import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../models/book.dart';
import '../providers/library_provider.dart';
import '../screens/reader_screen.dart';
import '../widgets/book_detail_sheet.dart';

/// Full-page book details screen: metadata, reading progress, file info,
/// and quick actions.  Opened from the long-press sheet's "Info" row.
class BookInfoScreen extends StatefulWidget {
  final Book book;
  const BookInfoScreen({super.key, required this.book});

  @override
  State<BookInfoScreen> createState() => _BookInfoScreenState();
}

class _BookInfoScreenState extends State<BookInfoScreen> {
  String? _fileSizeText;
  String? _format;

  @override
  void initState() {
    super.initState();
    _loadExtraInfo();
  }

  Future<void> _loadExtraInfo() async {
    final file = File(widget.book.filePath);
    if (!await file.exists()) {
      if (mounted) setState(() { _fileSizeText = 'File not found'; });
      return;
    }
    final bytes = await file.length();
    final ext = p.extension(widget.book.filePath).toLowerCase().replaceFirst('.', '');
    final size = bytes < 1024 * 1024
        ? '${(bytes / 1024).toStringAsFixed(0)} KB'
        : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

    if (mounted) {
      setState(() {
        _fileSizeText = size;
        _format = ext.toUpperCase();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final book = widget.book;
    final percent = (book.progress * 100).round();
    final library = context.watch<LibraryState>();
    final categories = library.categoriesOfBook(book.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book info'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: book.isInProgress ? 'Continue reading' : 'Start reading',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Cover + title block ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'book-cover-${book.id}',
                child: Container(
                  width: 80,
                  height: 120,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    image: book.coverImagePath != null
                        ? DecorationImage(
                            image: FileImage(File(book.coverImagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.all(6),
                  child: book.coverImagePath == null
                      ? Text(
                          book.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ProgressChip(percent: percent, book: book),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- Categories ---
          if (categories.isNotEmpty) ...[
            _SectionTitle('Categories'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in categories)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // --- Reading progress ---
          _SectionTitle('Reading progress'),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: book.progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$percent% complete',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Ch ${book.currentChapter + 1} of ${book.totalChapters}',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- File details ---
          _SectionTitle('File details'),
          const SizedBox(height: 8),
          _InfoRow(label: 'Format', value: _format ?? '---'),
          _InfoRow(label: 'File size', value: _fileSizeText ?? 'Loading\u2026'),
          _InfoRow(label: 'File name', value: p.basename(book.filePath)),
          const SizedBox(height: 24),

          // --- Dates ---
          _SectionTitle('Dates'),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Added',
            value: _formatDate(book.addedAt),
          ),
          _InfoRow(
            label: 'Last read',
            value: book.lastReadAt != null ? _formatDate(book.lastReadAt!) : 'Never',
          ),
          const SizedBox(height: 24),

          // --- Actions ---
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReaderScreen(book: book),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: Text(book.isInProgress ? 'Continue Reading' : 'Start Reading'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showCategoriesEditor(context, book);
                  },
                  icon: const Icon(Icons.folder_outlined, size: 18),
                  label: const Text('Categories'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                removeBookWithUndo(context, book);
              },
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Remove from library'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressChip extends StatelessWidget {
  final int percent;
  final Book book;
  const _ProgressChip({required this.percent, required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color bg;
    final Color fg;
    final String label;

    if (book.progress >= 1.0) {
      bg = Colors.green.withValues(alpha: 0.15);
      fg = Colors.green.shade700;
      label = 'Finished';
    } else if (book.isInProgress) {
      bg = theme.colorScheme.primaryContainer;
      fg = theme.colorScheme.primary;
      label = '$percent% read';
    } else {
      bg = theme.colorScheme.surfaceContainerHighest;
      fg = theme.colorScheme.onSurfaceVariant;
      label = 'Not started';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
