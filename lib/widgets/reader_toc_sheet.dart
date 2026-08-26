import 'package:flutter/material.dart';
import '../models/chapter.dart';

/// Table of contents bottom sheet. Tapping a chapter jumps the
/// reader to that chapter's first page.
class ReaderTocSheet extends StatelessWidget {
  final int currentChapterIndex;
  final ValueChanged<int> onChapterSelected;
  final List<ParsedChapter> chapters;

  const ReaderTocSheet({
    super.key,
    required this.currentChapterIndex,
    required this.onChapterSelected,
    required this.chapters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Contents', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: chapters.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: theme.colorScheme.outlineVariant),
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                final isCurrent = index == currentChapterIndex;
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
                    onChapterSelected(index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
