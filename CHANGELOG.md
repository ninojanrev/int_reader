# EPUB Reader - Changelog

> A Flutter-based Android EPUB reader. This document records every significant change
> made to the app during mockup/prototyping, with file references and rationale.

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [Phase 1 - Initial Mockup](#phase-1---initial-mockup)
3. [Phase 2 - Interactive Mockup Features](#phase-2---interactive-mockup-features)
4. [Phase 3 - Settings and Persistence](#phase-3---settings-and-persistence)
5. [Phase 4 - Dark Mode](#phase-4---dark-mode)
6. [Phase 5 - Material Design 3 Overhaul](#phase-5---material-design-3-overhaul)
7. [Phase 6 - Reader Improvements](#phase-6---reader-improvements)
8. [Phase 7 - Category Navigation](#phase-7---category-navigation)
9. [Phase 8 - Stats Enhancements](#phase-8---stats-enhancements)
10. [Phase 9 - Bug Fixes and Polish](#phase-9---bug-fixes-and-polish)

---

## Project Structure

```
epub_reader/
  lib/
    main.dart                          # App entry point, dark mode notifier
    data/
      sample_books.dart              # 15 sample books, saved items, weekly data
      sample_chapters.dart           # Sample chapter content for reader
    models/
      book.dart                      # Book data model
    screens/
      root_shell.dart                # Bottom nav shell (IndexedStack)
      home_screen.dart               # Library tab with search, categories, FAB
      reader_screen.dart             # Full EPUB reader with page turning
      saved_screen.dart              # Highlights and bookmarks with swipe-to-delete
      settings_screen.dart           # App settings with persistent preferences
      stats_screen.dart              # Reading statistics with streak and goal tracker
      category_books_screen.dart     # Full-screen category browser (NEW)
    services/
      settings_service.dart          # SharedPreferences persistence layer
    theme/
      app_theme.dart                 # AppColors, buildAppTheme(), M3 theme
    widgets/
      book_cover_tile.dart           # Colored cover placeholder tile
      continue_reading_card.dart     # Continue reading home card
      reader_options.dart            # ReaderTheme definitions, font map
      reader_settings_sheet.dart     # In-reader Aa display settings
      reader_toc_sheet.dart          # In-reader table of contents
      shelf_chip.dart               # (Legacy) shelf filter chip
```

**Dependencies** (pubspec.yaml):
- flutter (SDK)
- cupertino_icons: ^1.0.6
- shared_preferences: ^2.2.0 -- used for settings persistence
- flutter_lints: ^3.0.0 (dev)

---

## Phase 1 - Initial Mockup

> Git commits: 20d7894, 369dfe4, 9222d60

The barebones scaffold of the app: a 4-tab shell with placeholder screens.

| Feature | File(s) |
|---|---|
| Bottom navigation (Library, Stats, Saved, Settings) | lib/screens/root_shell.dart |
| Library grid with colored placeholder covers | lib/screens/home_screen.dart, lib/widgets/book_cover_tile.dart |
| Continue reading card | lib/widgets/continue_reading_card.dart |
| Reader screen with page turning | lib/screens/reader_screen.dart |
| Settings screen (static) | lib/screens/settings_screen.dart |
| Stats screen (static metrics) | lib/screens/stats_screen.dart |
| Saved screen (static list) | lib/screens/saved_screen.dart |
| Book data model | lib/models/book.dart |
| 15 sample books across 3 shelves | lib/data/sample_books.dart |
| 10 sample saved items | lib/data/sample_books.dart |
| Reader themes (Light, Sepia, Dark, OLED) | lib/widgets/reader_options.dart |

### Design Decisions

- IndexedStack in root_shell.dart preserves each tab scroll position and state.
- Colored Container placeholders instead of images until real EPUB cover art extraction is wired in.
- ReaderTheme class decouples reading appearance from AppColors.

---

## Phase 2 - Interactive Mockup Features

> Git commit: 5203f0e

### Library Tab (home_screen.dart)

| Feature | Details |
|---|---|
| Working search bar | Filters books by title or author in real-time. Clear button when text is present. |
| Long-press detail sheet | Bottom sheet with cover, title, author, shelf tag, progress, Continue/Start Reading, Details, Remove. |
| Profile dialog | Tap avatar for AlertDialog with user name, email, library stats. |
| Import flow | FAB opens bottom sheet with 3 options: Browse local files, Cloud import, Scan barcode/ISBN. |
| Shelf filter chips | Horizontal chip row to filter by shelf (All, Sci-fi, Classics, Non-fiction). |

### Reader Screen (reader_screen.dart)

| Feature | Details |
|---|---|
| Page turning | PageView.builder with horizontal swipe between flattened pages. |
| Progress slider | Bottom bar slider tracks position across all pages. |
| Text highlighting | Long-press or tap highlight icon to save page highlight with snackbar confirmation. |
| Table of contents | Bottom sheet listing all chapters; tapping jumps to that chapter. |
| Display settings | Aa bottom sheet with font family, font size slider, and reading theme picker. |

### Data (sample_books.dart)

- 15 books across 3 shelves (Sci-fi, Classics, Non-fiction): 4 in-progress, 2 finished, 9 not started.
- 10 saved items: realistic highlights and bookmarks.
- Weekly minutes data for stats chart.

---

## Phase 3 - Settings and Persistence

### Settings Service (services/settings_service.dart)

Centralized persistence layer using shared_preferences.

| Setting | Key | Default | Type |
|---|---|---|---|
| Dark mode | dark_mode | false | bool |
| Font family | font_family | Serif | String |
| Font size | font_size | 17 | double |
| Reading theme | reading_theme | Sepia | String |
| Sort order | sort_order | Recently added | String |
| Page turn style | page_turn_style | Tap and swipe | String |
| Keep screen awake | keep_screen_awake | true | bool |

- Singleton pattern: final settings = SettingsService() imported globally.
- Startup: settings.init() called in main() before runApp().
- Write-through: Every setter writes to SharedPreferences immediately.

### Settings Screen (settings_screen.dart)

| Section | Settings |
|---|---|
| Appearance | Dark mode toggle (persisted) |
| Reading | Font family, font size, reading theme, page turn style, keep screen awake |
| Library | Default sort order, manage collections, storage used |
| Backup and sync | Cloud backup toggle, sync across devices toggle |
| Notifications | Reading reminders toggle |
| About | App version, privacy policy, clear cache |

---

## Phase 4 - Dark Mode

### Architecture

darkModeNotifier (ValueNotifier<bool> in main.dart) is the single source of truth.
buildAppTheme(dark:) in app_theme.dart returns ThemeData with useMaterial3: true.
AppColors has static getters that read darkModeNotifier.value directly.

### Dark Mode Rebuild Fix

**Problem**: Toggling dark mode updated MaterialApp theme but child widgets did not rebuild
because IndexedStack reuses State objects.

**Solution**: Each tab screen now has a darkModeNotifier.addListener in initState
that calls setState(() {}) on theme change.

| Screen | Change |
|---|---|
| home_screen.dart | Added initState listener + dispose cleanup |
| saved_screen.dart | Added listener to existing initState + added dispose |
| stats_screen.dart | Converted from StatelessWidget to StatefulWidget |
| settings_screen.dart | Already had listener (unchanged) |

### Theme Color Usage

All screens migrated from hardcoded AppColors to Theme.of(context).colorScheme:
- Card backgrounds -> theme.colorScheme.surfaceContainerLow
- Borders -> theme.colorScheme.outlineVariant
- Text -> theme.colorScheme.onSurfaceVariant
- Primary actions -> theme.colorScheme.primary

---

## Phase 5 - Material Design 3 Overhaul

### Home Screen M3 Changes

| Before | After |
|---|---|
| Custom search bar | M3 SearchBar with leading, trailing, hintText |
| Custom chip row | M3 ChoiceChip for shelf filtering |
| Custom book cards | M3 Card with elevation: 0, surfaceContainerLow color |
| Custom FAB | M3 FloatingActionButton |
| Hardcoded TextStyle sizes | theme.textTheme.titleMedium, bodySmall etc. |

### Reader Screen M3 Changes

| Before | After |
|---|---|
| Custom top/bottom bars | M3-styled bars with theme.colorScheme.surface |
| Custom slider | M3 SliderTheme with trackHeight: 2 |
| Custom TOC sheet | M3 DraggableScrollableSheet with 28dp radius |

### Widget Updates

- book_cover_tile.dart: Wrapped in Hero for smooth transitions.
- continue_reading_card.dart: Uses Hero tag matching book_cover_tile.dart.
- reader_settings_sheet.dart: Font family buttons use accentMuted/accent for selected state.
- reader_toc_sheet.dart: Uses AppColors for current chapter highlighting.

---

## Phase 6 - Reader Improvements

### Immersive System UI

| Behavior | Implementation |
|---|---|
| Chrome hidden -> status bar hidden | SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky) |
| Chrome shown -> status bar visible | SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge) |
| Screen entry -> immediately immersive | Set in initState() |
| Screen exit -> restore normal UI | Restored in dispose() |

Uses immersiveSticky (not immersive) so users can swipe from edge to temporarily reveal system bars.

### Reader Settings Sheet (reader_settings_sheet.dart)

- Font size slider (13-24pt, 11 divisions)
- Font family selector (Serif/Georgia, Sans-Serif/Roboto, Monospace/RobotoMono)
- Reading theme picker (Light, Sepia, Dark, OLED Black) with visual preview thumbnails
- Changes apply live and persist via SettingsService.

### Reader TOC Sheet (reader_toc_sheet.dart)

- Lists all chapters from sampleChapters
- Current chapter highlighted in accent color with book icon
- Tapping a chapter jumps to that chapters first page via _jumpToChapter()

---

## Phase 7 - Category Navigation

### Home Screen Categories (home_screen.dart)

The old shelf chip row + flat grid was replaced with category sections:

| Component | Details |
|---|---|
| Category sections | Each shelf gets its own titled section |
| Horizontal scroll rows | ListView.builder showing book covers |
| View all button | Each section header has TextButton to open full browser |
| Dynamic categories | Derived from sampleBooks shelf values, no hardcoded list |

### Category Books Screen (category_books_screen.dart) - NEW

| Feature | Details |
|---|---|
| AppBar | Shows current category name |
| Search bar | M3 SearchBar in app bar bottom, filters by title or author |
| Swipeable tabs | ChoiceChip row + PageView.builder for left/right swiping |
| Full grid | 3-column GridView.builder for all books in selected category |
| Empty state | Icon + No books in this category message |
| Dark mode | Listens to darkModeNotifier for instant theme switching |
| Book import sync | Receives user-imported books from HomeScreen via static setter |

---

## Phase 8 - Stats Enhancements

### Reading Streak Section (stats_screen.dart)

| Element | Details |
|---|---|
| Animated fire icon | AnimatedBuilder + AnimationController pulsing scale 1.0 to 1.15 over 1200ms |
| Streak display | 6 day streak title + Best: 12 days subtitle |
| 7-day dot grid | Circles for M-S; filled blue with checkmark for read days |

### Monthly Goal Tracker (stats_screen.dart)

| Element | Details |
|---|---|
| Circular progress | CircularProgressIndicator animating 0% to 50% on screen entry (1500ms) |
| Percentage label | Centered text showing current percentage |
| Linear progress bar | Shows book progress (2/4 = 50%) |
| Page count | 1,284 / 3,000 pages text |

### Metric Grid and Weekly Chart

- 2x2 grid of Cards: Reading time (18h 40m), Books finished (7), Pages read (1,284), Streak (6 days)
- Bar chart of daily reading minutes (M-S), today highlighted in primary color
- Currently reading list with cover color, title, and completion percentage

---

## Phase 9 - Bug Fixes and Polish

### Dark Mode Card Desync Fix

**Problem**: Toggling dark mode updated background/text colors but cards, dividers,
and icons stayed white until manually interacted with.

**Root cause**: Screens using AppColors.surfaceCard (static getter) did not trigger
rebuilds. Theme.of(context) was only called by some widgets.

**Fix**: Migrated all card backgrounds, borders, and text colors to use
Theme.of(context).colorScheme throughout all screens.

### Dark Mode Transition Experiment

An animated color interpolation system was built and later reverted:

**Built**: AnimatedColors widget with 350ms animation that interpolated all AppColors
values between light and dark palettes on each animation tick.

**Problems encountered**:
1. _onTick updated static fields but never called setState, so UI froze during animation
2. Two competing theme systems caused visual desync

**Final decision**: Removed all animation code. Dark mode now switches instantly via
ValueListenableBuilder + buildAppTheme(dark:). Simpler and more reliable.

### Encoding Fix

Several files had non-ASCII characters encoded as Latin-1 instead of UTF-8,
causing Dart analyzer import errors. Fixed by re-encoding affected files.

### Swipe-to-Delete on Saved Items (saved_screen.dart)

- Dismissible widget with endToStart direction (swipe left)
- Red background with delete icon appears during swipe
- Confirmation dialog before removal
- 3-second undo snackbar to restore removed items

---

## File Reference Index

| File | Purpose | Key Changes |
|---|---|---|
| lib/main.dart | App entry, dark mode notifier | ValueListenableBuilder + settings.init() |
| lib/models/book.dart | Book data model | progress, currentChapter, shelf, isInProgress |
| lib/data/sample_books.dart | Sample data | 15 books, 10 saved items, weekly minutes |
| lib/data/sample_chapters.dart | Reader content | 5 chapters with multiple pages each |
| lib/services/settings_service.dart | SharedPreferences persistence | 7 settings with defaults |
| lib/theme/app_theme.dart | Colors + theme | AppColors (dynamic getters), buildAppTheme() (M3) |
| lib/screens/root_shell.dart | Bottom nav | IndexedStack + NavigationBar |
| lib/screens/home_screen.dart | Library tab | Search, categories, FAB, import, book detail |
| lib/screens/reader_screen.dart | EPUB reader | PageView, immersive UI, highlights, TOC, settings |
| lib/screens/saved_screen.dart | Saved items | Swipe-to-delete, undo, filter dropdown |
| lib/screens/settings_screen.dart | App settings | All sections with persistence |
| lib/screens/stats_screen.dart | Reading stats | Streak animation, goal tracker, charts |
| lib/screens/category_books_screen.dart | Category browser | Swipeable tabs, search, full grid |
| lib/widgets/book_cover_tile.dart | Cover placeholder | Hero animation, dashed add tile |
| lib/widgets/continue_reading_card.dart | Continue reading | Hero animation, progress bar |
| lib/widgets/reader_options.dart | Reader themes/fonts | 4 themes, 3 font families |
| lib/widgets/reader_settings_sheet.dart | Reader Aa sheet | Font size, family, theme pickers |
| lib/widgets/reader_toc_sheet.dart | TOC sheet | Chapter list with current indicator |
| lib/widgets/shelf_chip.dart | Shelf filter chip | Legacy - replaced by categories |

---

## Git History

| Commit | Message |
|---|---|
| 20d7894 | V. 1.0, Mostly mockup barebones design |
| 369dfe4 | v 1.0 Just mockup initial screens |
| 9222d60 | Minor changes to book cover tile widget to improve UI and performance |
| 5203f0e | What New - Home screen, reader highlights, dark mode, data |
| 23e6971 | Design and mockup changes - settings screen and service |

**Uncommitted changes**: Phases 3-9 (settings persistence, dark mode fixes,
M3 overhaul, immersive reader, category navigation, stats enhancements, bug fixes).

---

*Last updated: August 24, 2026*
