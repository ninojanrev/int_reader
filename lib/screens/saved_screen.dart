import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../models/highlight.dart';
import '../models/bookmark.dart';
import '../providers/library_provider.dart';
import 'reader_screen.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});
  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  String _filter = 'All';
  List<Highlight> _highlights = [];
  List<Bookmark> _bookmarks = [];
  bool _isLoading = true;
  int _loadedVersion = -1;

  @override
  void initState() {
    super.initState();
    // First load is triggered by build() watching savedVersion.
  }

  Future<void> _loadData() async {
    final library = context.read<LibraryState>();
    final highlights = await library.getAllHighlights();
    final bookmarks = await library.getAllBookmarks();
    if (mounted) {
      setState(() {
        _highlights = highlights;
        _bookmarks = bookmarks;
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredItems {
    if (_filter == 'All') return [..._highlights, ..._bookmarks];
    if (_filter == 'Highlights') return _highlights;
    return _bookmarks;
  }

  /// Null-safe book lookup; highlights/bookmarks of removed books still show.
  Book? _bookFor(String bookId) {
    final library = context.read<LibraryState>();
    for (final b in library.books) {
      if (b.id == bookId) return b;
    }
    return null;
  }

  void _openSavedItem(String bookId, int chapterIndex) {
    final book = _bookFor(bookId);
    if (book == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('That book is no longer in your library'),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          book: book,
          startChapterOverride: chapterIndex,
        ),
      ),
    );
  }

  void _removeHighlight(Highlight item) async {
    final library = context.read<LibraryState>();
    await library.deleteHighlight(item.id!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Highlight removed'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Theme.of(context).colorScheme.primary,
          onPressed: () async {
            final lib = context.read<LibraryState>();
            await lib.addHighlight(item);
          },
        ),
      ));
    }
  }

  void _removeBookmark(Bookmark item) async {
    final library = context.read<LibraryState>();
    await library.deleteBookmark(item.id!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Bookmark removed'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Theme.of(context).colorScheme.primary,
          onPressed: () async {
            final lib = context.read<LibraryState>();
            await lib.addBookmark(item);
          },
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Reload whenever highlights/bookmarks change anywhere in the app.
    final library = context.watch<LibraryState>();
    if (library.savedVersion != _loadedVersion) {
      _loadedVersion = library.savedVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadData();
      });
    }
    final items = _filteredItems;

    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Saved', style: theme.textTheme.headlineSmall),
              _buildFilterRow(),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bookmark_border, size: 56,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          Text('Nothing saved yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text('Highlights and bookmarks from your books appear here',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        if (item is Highlight) {
                          return _buildHighlightCard(item);
                        } else if (item is Bookmark) {
                          return _buildBookmarkCard(item);
                        }
                        return const SizedBox.shrink();
                      },
                    ),
        ),
      ]),
    );
  }

  Widget _buildFilterRow() {
    final theme = Theme.of(context);
    const options = ['All', 'Highlights', 'Bookmarks'];
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _filter,
        items: options.map((o) => DropdownMenuItem(value: o,
          child: Text(o, style: theme.textTheme.bodyMedium))).toList(),
        onChanged: (v) => setState(() => _filter = v ?? 'All'),
      ),
    );
  }

  Widget _buildHighlightCard(Highlight item) {
    final theme = Theme.of(context);
    final book = _bookFor(item.bookId);
    final title = book?.title ?? 'Removed book';

    return Dismissible(
      key: ValueKey('highlight-${item.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Text('Remove?', style: theme.textTheme.titleMedium),
            content: Text('Remove this highlight from "$title"?',
              style: theme.textTheme.bodyMedium),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true),
                child: Text('Remove', style: TextStyle(color: theme.colorScheme.error))),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => _removeHighlight(item),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline, color: Colors.white)),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openSavedItem(item.bookId, item.chapterIndex),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600)),
                    if (book != null) ...[
                      const SizedBox(height: 2),
                      Text(book.author, style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 8),
                    Text('\u201c${item.text}\u201d',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic, height: 1.4)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Text('Chapter ${item.chapterIndex + 1}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                      const Spacer(),
                      Icon(Icons.arrow_forward, size: 14,
                        color: theme.colorScheme.primary),
                    ]),
                  ],
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookmarkCard(Bookmark item) {
    final theme = Theme.of(context);
    final book = _bookFor(item.bookId);
    final title = book?.title ?? 'Removed book';
    final label = (item.label?.isNotEmpty ?? false)
        ? item.label!
        : 'Chapter ${item.chapterIndex + 1}';

    return Dismissible(
      key: ValueKey('bookmark-${item.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Text('Remove?', style: theme.textTheme.titleMedium),
            content: Text('Remove this bookmark from "$title"?',
              style: theme.textTheme.bodyMedium),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true),
                child: Text('Remove', style: TextStyle(color: theme.colorScheme.error))),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => _removeBookmark(item),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline, color: Colors.white)),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openSavedItem(item.bookId, item.chapterIndex),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.bookmark, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600)),
                    if (book != null) ...[
                      const SizedBox(height: 2),
                      Text(book.author, style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 8),
                    Text(label, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Row(children: [
                      Text('Chapter ${item.chapterIndex + 1}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                      const Spacer(),
                      Icon(Icons.arrow_forward, size: 14,
                        color: theme.colorScheme.primary),
                    ]),
                  ],
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
