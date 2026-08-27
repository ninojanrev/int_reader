import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../main.dart';
import '../widgets/book_cover_tile.dart';
import '../widgets/book_detail_sheet.dart';
import '../widgets/continue_reading_card.dart';
import '../widgets/cover_backdrop.dart';
import '../providers/library_provider.dart';
import '../services/file_service.dart';
import '../services/settings_service.dart';
import '../services/storage_access_service.dart';
import 'category_books_screen.dart';
import 'reading_now_screen.dart';
import 'reader_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    darkModeNotifier.addListener(_onDarkModeChanged);
    _searchFocus.addListener(_onSearchFocusChanged);
  }

  void _onSearchFocusChanged() {
    if (mounted) setState(() {});
  }

  bool get _searching => _searchFocus.hasFocus || _searchQuery.isNotEmpty;

  /// Public getter for RootShell's back-button handling.
  bool get isSearching => _searching;

  /// Close search bar — called by RootShell when back is pressed.
  void closeSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() => _searchQuery = '');
  }

  @override
  void dispose() {
    darkModeNotifier.removeListener(_onDarkModeChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onDarkModeChanged() {
    if (mounted) setState(() {});
  }

  Book? get _continueReadingBook {
    final library = context.read<LibraryState>();
    final inProgress = library.inProgressBooks;
    return inProgress.isEmpty ? null : inProgress.first;
  }

  void _openReader(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
    );
  }

  void _openCategory(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryBooksScreen(
          initialCategory: category,
        ),
      ),
    );
  }

  void _showBookDetail(Book book) =>
      showBookDetailSheet(context, book);

  void _showImportDialog() async {
    final filePath = await fileService.pickEpubFile();
    if (!mounted || filePath == null) return;
    final outcome = await context.read<LibraryState>().importBook(
          filePath,
          resolveConflict: _resolveConflict,
        );
    if (!mounted) return;
    final message = switch (outcome) {
      LibraryState.importOutcomeAdded => 'Book imported successfully',
      LibraryState.importOutcomeUpdated => 'Book updated with the new version',
      LibraryState.importOutcomeKept =>
        'Already in your library — existing version kept',
      _ => 'Failed to import book',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  /// Conflict policy from current settings:
  /// - Replace toggle off -> always keep existing
  /// - Auto mode -> larger file wins
  /// - Ask mode -> per-book dialog (free choice)
  Future<ImportConflictAction> _resolveConflict(
      Book existing, int newSize) async {
    if (!settings.replaceOnImport) {
      return ImportConflictAction.keepExisting;
    }
    final oldSize = await fileService.epubFileSize(existing);
    if (settings.importConflictMode != 'Ask every time') {
      return newSize > oldSize
          ? ImportConflictAction.replaceExisting
          : ImportConflictAction.keepExisting;
    }
    if (!mounted) return ImportConflictAction.keepExisting;

    String mb(int bytes) => bytes < 1024 * 1024
        ? '${(bytes / 1024).toStringAsFixed(0)} KB'
        : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

    final replace = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('"${existing.title}" already exists',
            style: Theme.of(context).textTheme.titleMedium),
        content: Text(
          'New file: ${mb(newSize)}\n'
          'Existing: ${mb(oldSize)}\n\n'
          'Replace the stored copy with the new one?',
          style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep existing')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Replace')),
        ],
      ),
    );
    return replace == true
        ? ImportConflictAction.replaceExisting
        : ImportConflictAction.keepExisting;
  }

  /// FAB entry point: choose between single-file and folder import.
  void _showImportChoiceSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('Add books', style: theme.textTheme.titleMedium),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ListTile(
            leading: Icon(Icons.picture_as_pdf_outlined,
                color: theme.colorScheme.primary),
            title: const Text('Import a file'),
            subtitle: Text('Pick a single book file',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
            onTap: () {
              Navigator.pop(sheetContext);
              _showImportDialog();
            },
          ),
          ListTile(
            leading:
                Icon(Icons.folder_open, color: theme.colorScheme.primary),
            title: const Text('Import a folder'),
            subtitle: Text('Add every supported book in the folder',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
            onTap: () {
              Navigator.pop(sheetContext);
              _batchImportFromFolder();
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _batchImportFromFolder() async {
    final folder = await fileService.pickFolder();
    if (!mounted || folder == null) return;

    // Scoped storage: make sure we may read shared-storage folders.
    final granted = await storageAccessService.ensureAccess();
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Storage access is required to read that folder. '
            'Grant "All files access" and try again.'),
        duration: Duration(seconds: 4)));
      return;
    }

    final scan = await fileService.listEpubsInFolder(folder);
    if (!mounted) return;
    if (scan.accessDenied) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Can\u2019t access that folder. Grant "All files access" to '
            'Int Reader in system settings and try again.'),
        duration: Duration(seconds: 4)));
      return;
    }
    final epubPaths = scan.bookPaths;
    if (epubPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No supported book files found in that folder'),
        duration: Duration(seconds: 2)));
      return;
    }

    // Pre-import options: optionally file everything under a category
    // named after the folder.
    final folderName = p.basename(folder.replaceAll('\\', '/'));
    String? addToCategory;
    final useCategory = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var useAsCategory = true;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Text('Import from "$folderName"',
                style: Theme.of(dialogContext).textTheme.titleMedium),
            content: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${epubPaths.length} EPUB file${epubPaths.length == 1 ? '' : 's'} found',
                style: Theme.of(dialogContext).textTheme.bodyMedium),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: useAsCategory,
                onChanged: (v) =>
                    setDialogState(() => useAsCategory = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text('Add books to category "$folderName"',
                    style: Theme.of(dialogContext).textTheme.bodyMedium),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Import')),
            ],
          ),
        );
      },
    );
    if (!mounted || useCategory != true) return;
    addToCategory = folderName;

    // Progress dialog; updated via the onProgress callback.
    var total = epubPaths.length;
    late final BuildContext dialogContextHolder;
    final progressUpdater = ValueNotifier<int>(0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        dialogContextHolder = dialogContext;
        return ValueListenableBuilder<int>(
          valueListenable: progressUpdater,
          builder: (context, value, _) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Importing books\u2026',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: total == 0 ? null : value / total),
              const SizedBox(height: 12),
              Text('$value of $total',
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ),
        );
      },
    );

    try {
      final result = await context.read<LibraryState>().importBooks(
            epubPaths,
            onProgress: (d, t) {
              total = t;
              progressUpdater.value = d;
            },
            resolveConflict: _resolveConflict,
            addToCategory: addToCategory,
          );
      if (!mounted) return;
      final messages = <String>['Added ${result.added}'];
      if (result.updated > 0) {
        messages.add('updated ${result.updated}');
      }
      if (result.unchanged > 0) {
        messages.add('kept ${result.unchanged}');
      }
      if (result.failed > 0) messages.add('${result.failed} failed');
      if (addToCategory.isNotEmpty) {
        messages.add('filed under "$addToCategory"');
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(messages.join(' \u00b7 ')),
        duration: const Duration(seconds: 3)));
    } finally {
      if (dialogContextHolder.mounted) Navigator.pop(dialogContextHolder);
      progressUpdater.dispose();
    }
  }

  void _showProfileDialog() {
    final library = context.read<LibraryState>();
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                'PJ',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Int Reader',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'https://github.com/ninojanrev/int-reader',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${library.books.length} books in library',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryState>();
    final continueBook = _continueReadingBook;
    final categories = library.displayCategories;
    final showBackdrop = settings.animatedLibraryBackdrop &&
        !library.isLoading &&
        !library.isEmpty &&
        !_searching;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated cover mosaic behind everything (subtle, non-interactive).
          if (showBackdrop) ...[
            Positioned.fill(
              child: IgnorePointer(
                child: CoverBackdrop(books: library.books),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Theme.of(context)
                      .scaffoldBackgroundColor
                      .withValues(alpha: 0.62),
                ),
              ),
            ),
          ],
          SafeArea(
            child: library.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _buildHeader(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: _buildSearchBar(),
                    ),
                    Expanded(
                      child: library.isEmpty && !_searching
                          ? _buildEmptyState()
                          : _searching
                              ? _buildSearchResults(library)
                              : _buildLibraryBody(
                                  library, continueBook, categories),
                    ),
                  ]),
          ),
        ],
      ),
      floatingActionButton:
          _searching || library.isLoading || library.isEmpty
              ? null
              : FloatingActionButton(
                  onPressed: _showImportChoiceSheet,
                  child: const Icon(Icons.add),
                ),
    );
  }

  Widget _buildLibraryBody(LibraryState library, Book? continueBook,
      List<String> categories) {
    final recent = library.recentlyAddedBooks.take(_categoryPreviewLimit).toList();
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
      if (continueBook != null) ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle('Continue reading'),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReadingNowScreen()),
              ),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ContinueReadingCard(
          book: continueBook,
          onTap: () => _openReader(continueBook),
        ),
      ],
      if (recent.isNotEmpty) ...[
        const SizedBox(height: 20),
        const Text('Recently added',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: _buildRecentRow(recent),
        ),
      ],
      for (final category in categories) ...[
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(category,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            TextButton(
              onPressed: () => _openCategory(category),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: _buildCategoryRow(library, category),
        ),
      ],
      const SizedBox(height: 12),
    ]);
  }

  /// Horizontal strip for the Recently added section.
  Widget _buildRecentRow(List<Book> books) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 16, right: 8),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: SizedBox(
            width: 90,
            child: BookCoverTile(
              book: book,
              onTap: () => _openReader(book),
              onLongPress: () => _showBookDetail(book),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('No books yet', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Import your first book to get started',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _showImportDialog,
            icon: const Icon(Icons.add),
            label: const Text('Import Book'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good evening',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Your library',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: _showProfileDialog,
          child: CircleAvatar(
            radius: 17,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              'PJ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return Row(children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  style: const TextStyle(fontSize: 13),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search books, authors, categories',
                    hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
      if (_searching) ...[
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {
            _searchController.clear();
            _searchFocus.unfocus();
            setState(() => _searchQuery = '');
          },
          child: const Text('Cancel'),
        ),
      ],
    ]);
  }

  // ================= Search results =================

  Widget _buildSearchResults(LibraryState library) {
    final theme = Theme.of(context);
    final q = _searchQuery.trim().toLowerCase();

    if (q.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.manage_search, size: 56,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('Search your library',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('Find books by title, group by author,\nor jump to a category',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant)),
        ]),
      );
    }

    final bookHits =
        library.sortBooks(library.books.where((b) =>
            b.title.toLowerCase().contains(q)).toList());

    final authorHits = <String, List<Book>>{};
    for (final b in library.sortBooks(library.books)) {
      if (b.author.toLowerCase().contains(q)) {
        authorHits.putIfAbsent(b.author, () => []).add(b);
      }
    }

    final categoryHits = [
      ...library.allCategories,
      if (library.booksForCategory('Uncategorized').isNotEmpty)
        'Uncategorized',
    ].where((c) => c.toLowerCase().contains(q)).toList();

    final nothing =
        bookHits.isEmpty && authorHits.isEmpty && categoryHits.isEmpty;
    if (nothing) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off, size: 56,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('No results for \u201c$_searchQuery\u201d',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('Try a different title, author, or category',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant)),
        ]),
      );
    }

    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
      if (bookHits.isNotEmpty) ...[
        _searchSectionHeader('Books', bookHits.length),
        for (final book in bookHits)
          _buildBookResultRow(theme, book),
      ],
      if (authorHits.isNotEmpty) ...[
        _searchSectionHeader('Authors', authorHits.length),
        for (final entry in authorHits.entries)
          Card(elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?',
                  style: TextStyle(color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600))),
              title: Text(entry.key, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text('${entry.value.length} ${entry.value.length == 1 ? 'book' : 'books'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
              trailing: Icon(Icons.chevron_right, size: 18,
                color: theme.colorScheme.onSurfaceVariant),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => AuthorBooksScreen(author: entry.key, books: entry.value))),
            )),
      ],
      if (categoryHits.isNotEmpty) ...[
        _searchSectionHeader('Categories', categoryHits.length),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final cat in categoryHits)
            ActionChip(label: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(cat == 'Uncategorized' ? Icons.inbox_outlined : Icons.folder_outlined,
                size: 15, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(cat),
            ]),
            onPressed: () => _openCategory(cat)),
        ]),
      ],
    ]);
  }

  Widget _searchSectionHeader(String title, int count) {
    final theme = Theme.of(context);
    return Padding(padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(children: [
        Text(title.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary, fontWeight: FontWeight.w700,
          letterSpacing: 0.8)),
        const SizedBox(width: 6),
        Text('$count', style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant)),
      ]));
  }

  Widget _buildBookResultRow(ThemeData theme, Book book) {
    final percent = (book.progress * 100).round();
    final status = book.progress >= 1.0
        ? 'Finished'
        : book.isInProgress ? '$percent% read' : 'Not started';
    return Card(elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
      child: InkWell(borderRadius: BorderRadius.circular(14),
        onTap: () => _showBookDetail(book),
        child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
          Container(width: 42, height: 60,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(5)),
            alignment: Alignment.center,
            child: Icon(Icons.menu_book_outlined, size: 20,
              color: theme.colorScheme.primary)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(status, style: theme.textTheme.labelSmall?.copyWith(
              color: book.progress >= 1.0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant)),
          ])),
          Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurfaceVariant),
        ]))));
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
  }

  static const _categoryPreviewLimit = 10;

  Widget _buildCategoryRow(LibraryState library, String category) {
    final books = library.sortBooks(_searchQuery.isEmpty
        ? library.booksForCategory(category)
        : library.booksForCategory(category).where((b) =>
            b.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            b.author.toLowerCase().contains(_searchQuery.toLowerCase())).toList());
    // Preview cap: the row shows at most N books; "View all" has the rest.
    final preview = books.take(_categoryPreviewLimit).toList();

    if (preview.isEmpty) {
      return const Center(child: Text('No books yet'));
    }
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 16, right: 8),
      itemCount: preview.length,
      itemBuilder: (context, index) {
        final book = preview[index];
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: SizedBox(
            width: 90,
            child: BookCoverTile(
              book: book,
              onTap: () => _openReader(book),
              onLongPress: () => _showBookDetail(book),
            ),
          ),
        );
      },
    );
  }
}

/// Grid of all books by one author, opened from search results.
class AuthorBooksScreen extends StatelessWidget {
  final String author;
  final List<Book> books;

  const AuthorBooksScreen({super.key, required this.author, required this.books});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(author)),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.65,
        ),
        itemCount: books.length,
        itemBuilder: (context, i) {
          final book = books[i];
          return BookCoverTile(
            book: book,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
            ),
            onLongPress: () => showBookDetailSheet(context, book),
          );
        },
      ),
    );
  }
}




