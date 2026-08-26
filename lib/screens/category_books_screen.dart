import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../widgets/book_cover_tile.dart';
import '../widgets/book_detail_sheet.dart';
import '../providers/library_provider.dart';
import 'reader_screen.dart';

/// Full-screen view showing all books in a category, with swipeable
/// category tabs and a search bar. Category chips are derived live from
/// the provider so managing categories is reflected immediately.
class CategoryBooksScreen extends StatefulWidget {
  final String initialCategory;

  const CategoryBooksScreen({
    super.key,
    required this.initialCategory,
  });

  @override
  State<CategoryBooksScreen> createState() => _CategoryBooksScreenState();
}

class _CategoryBooksScreenState extends State<CategoryBooksScreen> {
  late final PageController _pageController;
  int _currentPage = 0;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  List<String> _categoriesFor(LibraryState library) =>
      ['All', ...library.browseCategories];

  @override
  void initState() {
    super.initState();
    final categories =
        _categoriesFor(context.read<LibraryState>());
    final idx = categories.indexOf(widget.initialCategory);
    _currentPage = idx >= 0 ? idx : 0;
    _pageController = PageController(initialPage: _currentPage);
    darkModeNotifier.addListener(_onDarkModeChanged);
  }

  @override
  void dispose() {
    darkModeNotifier.removeListener(_onDarkModeChanged);
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onDarkModeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = context.watch<LibraryState>();
    final categories = _categoriesFor(library);
    // Keep the selection valid if categories were renamed/deleted.
    if (_currentPage >= categories.length) _currentPage = 0;
    final currentCategory = categories[_currentPage];
    final showAddFab = currentCategory != 'All' && currentCategory != 'Uncategorized';

    return Scaffold(
      floatingActionButton: showAddFab
          ? FloatingActionButton.extended(
              onPressed: () => _showAddBooksSheet(currentCategory),
              icon: const Icon(Icons.add),
              label: const Text('Add books'),
            )
          : null,
      appBar: AppBar(
        title: Text(currentCategory),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search by title or author',
              leading: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
              ),
              trailing: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
              ],
              elevation: WidgetStateProperty.all(0),
              backgroundColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHigh),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 8)),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Category tabs
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = index == _currentPage;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              },
            ),
          ),
          // Page view
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: categories.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                final category = categories[index];
                var books = library.booksForCategory(category);
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  books = books.where((b) =>
                      b.title.toLowerCase().contains(q) ||
                      b.author.toLowerCase().contains(q)).toList();
                }
                books = library.sortBooks(books);
                if (books.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_stories_outlined, size: 56,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Text('No books in this category',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text('Import books or add them to this category',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
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
                      onLongPress: () =>
                          showBookDetailSheet(context, book),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Picker for adding existing books to [category]. Books already in the
  /// category are hidden. Adding keeps all of a book's other categories.
  void _showAddBooksSheet(String category) {
    final theme = Theme.of(context);
    final selected = <String>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final library = context.read<LibraryState>();
          final candidates = library.books
              .where((b) => !library.categoriesOfBook(b.id).contains(category))
              .toList();
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Add books to "$category"',
                      style: theme.textTheme.titleMedium),
                ),
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                if (candidates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('All books are already in this category.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: candidates.length,
                      itemBuilder: (context, index) {
                        final book = candidates[index];
                        return CheckboxListTile(
                          value: selected.contains(book.id),
                          onChanged: (v) => setSheetState(() => v!
                              ? selected.add(book.id)
                              : selected.remove(book.id)),
                          title: Text(book.title,
                              style: theme.textTheme.bodyMedium),
                          subtitle: Text(book.author,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                          controlAffinity: ListTileControlAffinity.trailing,
                        );
                      },
                    ),
                  ),
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(children: [
                    const Spacer(),
                    FilledButton(
                      onPressed: selected.isEmpty
                          ? null
                          : () async {
                              for (final bookId in selected) {
                                await library.addBookToCategory(
                                    bookId, category);
                              }
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(
                                      'Added ${selected.length} ${selected.length == 1 ? 'book' : 'books'} to "$category"'),
                                  duration: const Duration(seconds: 2),
                                ));
                              }
                            },
                      child: Text('Add (${selected.length})'),
                    ),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
