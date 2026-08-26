import 'package:flutter/material.dart';


/// Expanding find-bar for the reader: query field, match counter,
/// prev/next navigation, and a scrollable results list. Purely
/// presentational â€” the reader owns state and callbacks.
class ReaderSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String countText; // e.g. '3 / 17'; empty hides the counter
  final VoidCallback onClose;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<String> onQueryChanged;
  /// Pre-built result rows (snippets). Empty when no query/no matches.
  final List<Widget> resultRows;

  const ReaderSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.countText,
    required this.onClose,
    required this.onPrevious,
    required this.onNext,
    required this.onQueryChanged,
    required this.resultRows,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuery = controller.text.trim().isNotEmpty;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 4,
      child: SafeArea(
        bottom: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Close search',
                onPressed: onClose,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search in book',
                    hintStyle: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: onQueryChanged,
                ),
              ),
              if (hasQuery)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(countText,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up),
                tooltip: 'Previous match',
                onPressed: hasQuery ? onPrevious : null,
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                tooltip: 'Next match',
                onPressed: hasQuery ? onNext : null,
              ),
            ]),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Flexible(
            child: resultRows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      hasQuery ? 'No matches found' : '',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: resultRows,
                  ),
          ),
        ]),
      ),
    );
  }
}

/// Wraps every occurrence of [query] inside the plain segments of [html]
/// with an amber highlight span. Tag segments are never touched.
String highlightHtmlOccurrences(String html, String query) {
  if (query.trim().isEmpty) return html;

  const highlightStyle = 'background-color:#F9E79F;color:#111111';

  final tagRe = RegExp(r'<[^>]+>');
  final out = StringBuffer();
  var last = 0;

  void appendTextSegment(String segment) {
    if (segment.isEmpty) return;
    final lower = segment.toLowerCase();
    final q = query.toLowerCase();
    var cursor = 0;
    while (true) {
      final idx = lower.indexOf(q, cursor);
      if (idx == -1) break;
      out.write(segment.substring(cursor, idx));
      out.write('<span style="$highlightStyle">'
          '${segment.substring(idx, idx + q.length)}</span>');
      cursor = idx + q.length;
    }
    out.write(segment.substring(cursor));
  }

  for (final m in tagRe.allMatches(html)) {
    appendTextSegment(html.substring(last, m.start));
    out.write(m.group(0));
    last = m.end;
  }
  appendTextSegment(html.substring(last));

  return out.toString();
}


