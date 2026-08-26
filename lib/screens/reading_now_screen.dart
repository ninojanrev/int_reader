import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_service.dart';
import '../models/book.dart';
import '../providers/library_provider.dart';
import '../widgets/book_detail_sheet.dart';
import 'reader_screen.dart';

/// Lists every book currently in progress (opened but not finished),
/// sortable by last opened / progress / date added.
class ReadingNowScreen extends StatefulWidget {
  const ReadingNowScreen({super.key});

  @override
  State<ReadingNowScreen> createState() => _ReadingNowScreenState();
}

class _ReadingNowScreenState extends State<ReadingNowScreen> {
  void _sortBooks(List<Book> books) {
    int cmpDesc(DateTime? a, DateTime? b) {
      final av = a ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bv = b ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bv.compareTo(av);
    }

    switch (settings.continueReadingSort) {
      case 'Progress':
        books.sort((a, b) => b.progress.compareTo(a.progress));
        break;
      case 'Date added':
        books.sort((a, b) => cmpDesc(a.addedAt, b.addedAt));
        break;
      default:
        books.sort((a, b) => cmpDesc(a.lastReadAt, b.lastReadAt));
    }
  }

  String _relativeDate(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = context.watch<LibraryState>();
    final books = [...library.inProgressBooks];
    _sortBooks(books);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading now'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.sort,
                color: theme.colorScheme.onSurfaceVariant),
            tooltip: 'Sort',
            onSelected: (v) async {
              await settings.setContinueReadingSort(v);
              if (mounted) setState(() {});
            },
            itemBuilder: (_) => [
              for (final option in ['Last opened', 'Progress', 'Date added'])
                CheckedPopupMenuItem(
                  value: option,
                  checked: settings.continueReadingSort == option,
                  child: Text(option),
                ),
            ],
          ),
        ],
      ),
      body: books.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.menu_book_outlined, size: 56,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text('Nothing in progress right now',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text('Open a book and it will appear here.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
              ]),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: books.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final book = books[index];
                final percent = (book.progress.clamp(0.0, 1.0) * 100).round();
                final last = book.lastReadAt;

                return Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                        color: theme.colorScheme.outlineVariant, width: 0.5)),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    leading: Container(
                      width: 44,
                      height: 62,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      child: book.coverImagePath != null &&
                              File(book.coverImagePath!).existsSync()
                          ? Image.file(File(book.coverImagePath!),
                              width: 44, height: 62, fit: BoxFit.cover)
                          : Icon(Icons.menu_book_outlined,
                              size: 20, color: theme.colorScheme.primary),
                    ),
                    title: Text(book.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(book.author, maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Expanded(child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: book.progress.clamp(0.0, 1.0),
                              minHeight: 4))),
                          const SizedBox(width: 8),
                          Text('$percent%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600)),
                        ]),
                      ],
                    ),
                    trailing: last != null
                        ? Text(_relativeDate(last),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant))
                        : null,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
                    ),
                    onLongPress: () =>
                        showBookDetailSheet(context, book),
                  ),
                );
              },
            ),
    );
  }
}


