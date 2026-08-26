# Contributing to EPUB Reader

Thanks for your interest in contributing! This guide covers the architecture,
coding conventions, and setup instructions to get you productive quickly.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Project Architecture](#project-architecture)
3. [Coding Conventions](#coding-conventions)
4. [Theme and Dark Mode](#theme-and-dark-mode)
5. [Adding a New Screen](#adding-a-new-screen)
6. [Adding a New Widget](#adding-a-new-widget)
7. [Settings and Persistence](#settings-and-persistence)
8. [Common Patterns](#common-patterns)
9. [Running Tests and Analysis](#running-tests-and-analysis)
10. [Pull Request Guidelines](#pull-request-guidelines)

---

## Quick Start

### Prerequisites

- Flutter SDK 3.0+ (run flutter --version to check)
- Android Studio or VS Code with Flutter plugin
- An Android emulator or physical device

### Setup

git clone <repo-url>
cd epub_reader
flutter pub get
flutter run

### Verify your setup

flutter analyze   # Should show 0 errors
flutter test      # Run unit tests

---

## Project Architecture

### Directory Layout

lib/
  main.dart                 App entry, darkModeNotifier, MaterialApp
  data/                     Sample data for mockup (books, chapters, saved items)
  models/                   Data classes (Book, SavedItem)
  screens/                  One file per screen (Home, Reader, Stats, Saved, Settings, CategoryBooks)
  services/                 Persistence layer (SettingsService via shared_preferences)
  theme/                    AppColors + buildAppTheme()
  widgets/                  Reusable UI components (BookCoverTile, ContinueReadingCard, reader sheets)

### Navigation Architecture

RootShell (root_shell.dart)
  IndexedStack with 4 tabs:
    0: HomeScreen       Library with categories, search, FAB
    1: StatsScreen      Reading statistics, streaks, goals
    2: SavedScreen      Highlights and bookmarks
    3: SettingsScreen   App preferences

NavigationBar at the bottom controls tab switching.
IndexedStack preserves each tab state when switching.

ReaderScreen is pushed via MaterialPageRoute (not a tab).
CategoryBooksScreen is pushed via MaterialPageRoute from HomeScreen.

### State Management

The app uses plain Flutter state management:
- StatefulWidget + setState for screen-level state
- ValueNotifier<bool> (darkModeNotifier) for global dark mode
- ValueListenableBuilder in MaterialApp for theme rebuilding
- SharedPreferences for persistence (SettingsService)

No external state management packages (Provider, Riverpod, Bloc) are used.
Keep it simple unless there is a strong reason to add one.

---

## Coding Conventions

### File Naming

- snake_case for all Dart files: home_screen.dart, book_cover_tile.dart
- One public class per file, file named after the class
- Private classes prefixed with underscore: _HomeScreenState

### Class Naming

- PascalCase for classes: HomeScreen, BookCoverTile, ReaderTheme
- Private classes with underscore: _HomeScreenState, _SettingsRow
- Constants: camelCase for variables, PascalCase for enum-like values

### Widget Conventions

- Use const constructors wherever possible (avoid const only when referencing dynamic values like AppColors getters)
- Prefer StatelessWidget when no mutable state is needed
- Extract reusable widgets into lib/widgets/
- Use Key in constructors: const MyWidget({super.key})
- Prefer descriptive parameter names: book, onTap, onLongPress

### Import Order

1. dart: imports
2. package:flutter/ imports
3. package:epub_reader/ imports (relative paths preferred)

### Comments

- Add /// doc comments on public classes and methods
- Use inline comments sparingly, only for non-obvious logic
- No commented-out code in committed files

---

## Theme and Dark Mode

### How It Works

1. darkModeNotifier (ValueNotifier<bool>) in main.dart is the source of truth.
2. MaterialApp uses ValueListenableBuilder to rebuild with buildAppTheme(dark: isDark).
3. AppColors has static getters that read darkModeNotifier.value directly.
4. Each tab screen listens to darkModeNotifier in initState for rebuilds.

### Critical Rule: Use Theme.of(context) in Widgets

For card backgrounds, borders, text, and icons, always use:
  theme.colorScheme.surfaceContainerLow    (card backgrounds)
  theme.colorScheme.outlineVariant          (borders and dividers)
  theme.colorScheme.onSurfaceVariant        (secondary text)
  theme.colorScheme.primary                 (accents and highlights)

Do NOT use AppColors for these in widget build methods.
AppColors is only for static colors (cover swatches, accent) or in widgets
that do not need to rebuild on theme change (like reader_options.dart).

### Why This Matters

Theme.of(context) creates a dependency on Flutters Theme InheritedWidget.
When MaterialApp rebuilds with a new theme, all widgets using Theme.of(context)
are automatically rebuilt. AppColors static getters do not trigger rebuilds,
so cards and text stay the old color until manually interacted with.

### Adding Dark Mode Support to a New Screen

1. Convert StatelessWidget to StatefulWidget if not already.
2. Add in initState:
     darkModeNotifier.addListener(_onDarkModeChanged);
3. Add in dispose:
     darkModeNotifier.removeListener(_onDarkModeChanged);
4. Add the listener method:
     void _onDarkModeChanged() { if (mounted) setState(() {}); }
5. Use Theme.of(context) for all colors in build().

---

## Adding a New Screen

1. Create lib/screens/my_screen.dart with a StatefulWidget.
2. Add the darkModeNotifier listener (see Theme section above).
3. Use Theme.of(context) for all colors.
4. If it is a new tab, add it to RootShell._tabs and add a NavigationDestination.
5. If it is a pushed screen, add a MaterialPageRoute in the calling code.

### Template

class MyScreen extends StatefulWidget {
  const MyScreen({super.key});
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  @override
  void initState() {
    super.initState();
    darkModeNotifier.addListener(_onDarkModeChanged);
  }

  @override
  void dispose() {
    darkModeNotifier.removeListener(_onDarkModeChanged);
    super.dispose();
  }

  void _onDarkModeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      // Use theme.colorScheme for colors
    );
  }
}

---

## Adding a New Widget

1. Create lib/widgets/my_widget.dart.
2. Use StatelessWidget unless the widget needs mutable state.
3. Accept parameters in the constructor (book, onTap, etc.).
4. For colors, use Theme.of(context) if the widget may appear in dark mode.
5. Use AppColors only for static values (cover swatches, accent color).

### When to Extract a Widget

- The same UI pattern appears in 2+ places
- A build method is getting too long (over 80 lines)
- A piece of UI has its own complex state

---

## Settings and Persistence

All persistent settings go through SettingsService (services/settings_service.dart).

### Adding a New Setting

1. Add a key constant: static const _kMySetting = "my_setting";
2. Add a cached field: bool mySetting = false;
3. Add a setter:
     Future<void> setMySetting(bool v) async {
       mySetting = v;
       await _prefs.setBool(_kMySetting, v);
     }
4. Load it in init(): mySetting = _prefs.getBool(_kMySetting) ?? false;
5. Add a UI row in settings_screen.dart.
6. Import settings from services/settings_service.dart in your screen.

### Important

- Always provide a sensible default in the init() fallback.
- Write to SharedPreferences immediately in the setter (write-through).
- The settings service is a global singleton (final settings = SettingsService()).

---

## Common Patterns

### Bottom Sheets

All bottom sheets use:
- backgroundColor: theme.colorScheme.surface
- shape: RoundedRectangleBorder with borderRadius: BorderRadius.vertical(top: Radius.circular(28))
- DraggableScrollableSheet for sheets that need scroll
- Drag handle: Container(width: 36, height: 4) at the top

### Cards

All cards use:
- elevation: 0
- color: theme.colorScheme.surfaceContainerLow
- shape: RoundedRectangleBorder with borderRadius: BorderRadius.circular(16)
- side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)

### Snackbars

- duration: Duration(seconds: 2) for info, Duration(seconds: 3) for undo
- Use SnackBarAction for interactive snackbars (undo, view)
- Style text with theme.textTheme for dark mode support

### Hero Animations

- Book covers use Hero tag: "book-cover-{book.id}"
- Wrap both the source (grid tile) and destination (reader top bar) in Hero widgets

### Reader Screen Specific

- Use SystemChrome for immersive mode (immersiveSticky when chrome hidden)
- Reader themes are in reader_options.dart (ReaderTheme class)
- Reader uses sampleChapters data, not real EPUB files yet
- Page turning uses PageView.builder with flattened pages list

---

## Running Tests and Analysis

### Static Analysis

flutter analyze

This runs the Dart analyzer with flutter_lints rules. The project should
have 0 errors and 0 warnings. Info-level hints are acceptable.

If you see errors about missing imports or undefined methods, run:

flutter pub get

### Tests

flutter test

Currently there are no unit tests. Adding tests for new features is encouraged.

### Build Check

flutter build apk --debug

Run this before submitting a PR to ensure the app compiles for Android.

---

## Pull Request Guidelines

### Before Submitting

1. Run flutter analyze and fix all errors.
2. Test on both light and dark mode.
3. Test on a physical device or emulator (not just web).
4. Check that new screens have the darkModeNotifier listener.
5. Verify all colors use Theme.of(context) for dark mode support.

### PR Description

- What does this PR change?
- Why is the change needed?
- How to test it (steps to reproduce the new behavior)
- Screenshots or screen recordings for UI changes

### Commit Messages

- Use imperative mood: "Add search bar" not "Added search bar"
- Keep the subject line under 72 characters
- Reference issues when applicable: Fixes #42

---

*Last updated: August 24, 2026*
