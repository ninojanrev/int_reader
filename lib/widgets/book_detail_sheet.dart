import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../providers/library_provider.dart';
import '../screens/reader_screen.dart';

/// Shared book actions used by the Library tab AND the category/author
/// screens: long-press detail sheet, multi-select category editor,
/// remove-with-undo.

/// The long-press bottom sheet: cover, metadata, Start Reading,
/// Categories editor, Remove with undo.
void showBookDetailSheet(BuildContext context, Book book) {
  final theme = Theme.of(context);
  final percent = ((book.progress) * 100).round();
  showModalBottomSheet(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 96,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        book.author,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          book.shelf,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (book.isInProgress)
                        Text(
                          '$percent% complete',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      else if (book.progress >= 1.0)
                        Text(
                          'Finished',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        Text(
                          'Not started',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
                  );
                },
                icon: const Icon(Icons.play_arrow, size: 20),
                label: Text(book.isInProgress ? 'Continue Reading' : 'Start Reading'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
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
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      removeBookWithUndo(context, book);
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Multi-select category editor: checkboxes for every category plus an
/// inline "New" action. Saving replaces the book's memberships; selecting
/// none puts it in Uncategorized.
void showCategoriesEditor(BuildContext context, Book book) {
  final library = context.read<LibraryState>();
  final theme = Theme.of(context);
  final selected = library.categoriesOfBook(book.id).toSet();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Categories',
                  style: theme.textTheme.titleMedium),
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  CheckboxListTile(
                    value: selected.contains('Uncategorized'),
                    onChanged: (v) => setSheetState(() =>
                        v! ? selected.add('Uncategorized') : selected.remove('Uncategorized')),
                    title: Row(children: [
                      Icon(Icons.inbox_outlined, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Text('Uncategorized', style: theme.textTheme.bodyMedium),
                    ]),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
                  for (final cat in library.allCategories)
                    CheckboxListTile(
                      value: selected.contains(cat),
                      onChanged: (v) => setSheetState(() =>
                          v! ? selected.add(cat) : selected.remove(cat)),
                      title: Row(children: [
                        Icon(Icons.folder_outlined, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(cat, style: theme.textTheme.bodyMedium)),
                      ]),
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final created =
                        await _promptNewCategory(sheetContext, library);
                    if (created) {
                      // Reload the sheet contents so the new one is checkable.
                      setSheetState(() {});
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () async {
                    await library.setBookCategories(book.id, selected);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(selected.isEmpty
                            ? 'Moved to "Uncategorized"'
                            : 'Saved categories for "${book.title}"'),
                        duration: const Duration(seconds: 2),
                      ));
                    }
                  },
                  child: const Text('Save'),
                ),
              ]),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Small dialog that creates a category via [library].
/// Returns whether a category was actually created.
Future<bool> _promptNewCategory(
    BuildContext sheetContext, LibraryState library) async {
  final controller = TextEditingController();
  final created = await showDialog<bool>(
    context: sheetContext,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Text('New Category'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: 'Category name',
          hintStyle: TextStyle(
              color: Theme.of(dialogContext).colorScheme.onSurfaceVariant),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext,
              controller.text.trim().isNotEmpty),
          child: const Text('Add'),
        ),
      ],
    ),
  );
  if (created == true) {
    return library.addCategory(controller.text.trim());
  }
  return false;
}

/// Remove a book and offer undo via snackbar.
void removeBookWithUndo(BuildContext context, Book book) {
  final library = context.read<LibraryState>();
  final savedBook = book;
  library.removeBook(book.id);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Removed "${savedBook.title}"'),
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'Undo',
        textColor: Theme.of(context).colorScheme.primary,
        onPressed: () => library.restoreBook(savedBook),
      ),
    ),
  );
}
