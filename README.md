# Int Reader

A fast, offline EPUB / TXT / Markdown / HTML / FB2 reader for Android,
built with Flutter.

Import books individually or in batches from a folder, organize them with
starred multi-select categories, and read in either paged (horizontal) or
scrolling (vertical) mode â€” with whole-book search, bookmarks, reading-time
stats, and daily reminders.

## Features

### Library
- Batch import: pick a folder and add every supported book at once, with
  duplicate detection (title + author), replace-on-import when a newer /
  larger file is found (optional per-book prompt), and an optional
  folder-name-as-category shortcut
- Multi-category organization: books can live in any number of categories;
  star categories to pin them as Library-tab sections
- "Recently added" strip plus per-category rows sorted by your default
  sort order (recently added / title / author / progress)
- Grouped search across titles, authors, and categories

### Reader
- Two reading modes: vertical scrolling or horizontal page turns with
  magnetic snap and RTL support â€” switchable mid-book
- Whole-book search: magnifier expands into a find-bar with match counter,
  prev/next navigation, snippet results, and in-text highlighting
- Bookmarks, chapter jump list, volume-key page turns
- Text appearance editor with live preview: font family (system, bundled,
  or imported TTF/OTF files), size, and line spacing â€” applied via
  Apply/Cancel so nothing changes until you confirm
- Reading themes: locked presets plus custom color themes with a live
  preview editor
- Progress is saved continuously (on swipes, app pause, and exit) and
  restored automatically; single-chapter books are tracked too
- Volume-key and swipe gestures, keep-screen-awake option

### Stats & habits
- Reading time tracked per day, current/best streaks, weekly chart,
  monthly goal, and a "Reading now" screen listing every book in progress
  (sortable by last opened, progress, or date added)

### Everything else
- Daily reading reminders (local notifications, survives reboot)
- Saved highlights & bookmarks screen
- Real storage usage reporting, orphaned-cover cleanup
- Instant dark/light mode switch

## Supported import formats

| Format | Notes |
|---|---|
| `.epub` | Full support incl. embedded covers and images |
| `.txt`  | Blank-line paragraphs grouped into chapters |
| `.md`   | Chapters split at `#` headings (fence-aware) |
| `.html` / `.htm` | Cleaned and split at heading boundaries |
| `.fb2`  | Sections â†’ chapters, inline markup mapped to HTML |

Books without embedded cover art get an auto-generated gradient cover.

## Getting started

1. Open this folder in Android Studio (or VS Code) and let it run
   `flutter pub get`.
2. Pick a device/emulator and hit **Run**.
3. On first folder import, grant the one-time "All files access" prompt.

## Project structure (reader core)

```
lib/services/converters/    TXT / MD / HTML / FB2 â†’ internal book model
lib/services/book_parser.dart        format dispatch facade
lib/services/search_index.dart       background-isolate search engine
lib/services/cover_generator.dart    generated gradient covers
lib/screens/reader_screen.dart       reader shell: modes, pagination, search
lib/database/database_helper.dart    SQLite schema (v4) + queries
```

See [`READER_SPEC.md`](READER_SPEC.md) for the full
architecture specification, algorithms, and tuning constants.

## License

All rights reserved by the project author.

