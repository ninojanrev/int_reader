import 'package:flutter/material.dart';
import '../models/chapter.dart';
import '../models/bookmark.dart';

/// Table of contents bottom sheet with two tabs:
/// - **Contents**: chapter list (original behaviour)
/// - **Bookmarks**: bookmarks for the current book, with swipe-to-delete
class ReaderTocSheet extends StatefulWidget {
  final int currentChapterIndex;
  final ValueChanged<int> onChapterSelected;
  final List<ParsedChapter> chapters;
  final List<Bookmark> bookmarks;
  final ValueChanged<Bookmark> onDeleteBookmark;

  const ReaderTocSheet({
    super.key,
    required this.currentChapterIndex,
    required this.onChapterSelected,
    required this.chapters,
    this.bookmarks = const [],
    required this.onDeleteBookmark,
  });

  @override
  State<ReaderTocSheet> createState() => _ReaderTocSheetState();
}

class _ReaderTocSheetState extends State<ReaderTocSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasBookmarks = widget.bookmarks.isNotEmpty;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Tab bar
          TabBar(
            controller: _tabCtrl,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurface,
            indicatorColor: theme.colorScheme.primary,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: [
              const Tab(text: 'Contents'),
              Tab(child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Bookmarks'),
                  if (hasBookmarks) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${widget.bookmarks.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              )),
            ],
          ),
          // Tab content
          Flexible(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildContentsTab(theme),
                _buildBookmarksTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentsTab(ThemeData theme) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.chapters.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: theme.colorScheme.outlineVariant),
      itemBuilder: (context, index) {
        final chapter = widget.chapters[index];
        final isCurrent = index == widget.currentChapterIndex;
        return ListTile(
          title: Text(
            chapter.title,
            style: TextStyle(
              fontSize: 13,
              color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          trailing: isCurrent
              ? Icon(Icons.menu_book, size: 16, color: theme.colorScheme.primary)
              : null,
          onTap: () {
            widget.onChapterSelected(index);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildBookmarksTab(ThemeData theme) {
    if (widget.bookmarks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_border, size: 40, color: theme.colorScheme.outline),
              const SizedBox(height: 12),
              Text(
                'No bookmarks yet',
                style: TextStyle(fontSize: 14, color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap the bookmark icon in the reader to add one',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.outline.withValues(alpha: 0.7)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.bookmarks.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: theme.colorScheme.outlineVariant),
      itemBuilder: (context, index) {
        final bookmark = widget.bookmarks[index];
        final chapterLabel = bookmark.label ??
            'Chapter ${bookmark.chapterIndex + 1}';
        final isCurrent = bookmark.chapterIndex == widget.currentChapterIndex;
        return Dismissible(
          key: ValueKey(bookmark.id ?? 'bm_$index'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            color: theme.colorScheme.error,
            child: Icon(Icons.delete_outline, color: theme.colorScheme.onError),
          ),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Remove bookmark?'),
                content: Text('Remove "$chapterLabel"?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('Remove', style: TextStyle(color: theme.colorScheme.error)),
                  ),
                ],
              ),
            );
          },
          onDismissed: (_) => widget.onDeleteBookmark(bookmark),
          child: ListTile(
            leading: Icon(
              Icons.bookmark,
              size: 20,
              color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            title: Text(
              chapterLabel,
              style: TextStyle(
                fontSize: 13,
                color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            subtitle: Text(
              'Page ${bookmark.pageIndex + 1}',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
            ),
            onTap: () {
              widget.onChapterSelected(bookmark.chapterIndex);
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }
}
