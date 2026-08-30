# Int Reader - Changelog

## v1.0.1 - Scrolling Mode Fixes (2026-08-30)
**APK:** `releases/int_reader-v1.0.0-scrolling-mode-fix.apk` (67.1MB)

### Bug Fixes

#### Scroll Position Save/Restore in Scrolling Mode
- Added `scroll_offset` column to books table (DB migration v4→v5)
- Added `scroll_fragment` column for fragment-level anchor (DB migration v5→v6)
- Scroll position now saved as fraction of maxScrollExtent (resolution-independent)
- Fragment-level anchor for precise restoration via `Scrollable.ensureVisible`
- Fraction-based fallback when fragment anchor unavailable (e.g., font size change)
- Per-chapter in-memory scroll offset map for cross-chapter navigation
- Restores position when reopening a book in scrolling mode
- Restores position when swiping between chapters
- Saves on app background/pause and dispose

#### Chapter Navigation in Scrolling Mode
- Created unified `_navigateToChapter` method handling save → state update → navigation → restore
- TOC chapter selection now properly updates UI (top bar title, bottom bar progress)
- Swipe/tap navigation no longer skips chapters (5→6→stuck bug fixed)
- Volume key navigation in scrolling mode also fixed

#### Gesture Handling in Scrolling Mode
- **Root cause:** Nested `GestureDetector` created 3-way gesture arena conflict
- Removed inner `GestureDetector` from `_buildReaderBody` vertical branch
- Moved horizontal swipe handling to outer `GestureDetector`
- Top bar buttons (book info, search, bookmark) now receive taps properly
- Tap zones (left/center/right) now work in scrolling mode
- Slider in bottom bar works for chapter navigation

### UI Improvements
- Bottom bar: removed chapter counter, shows only position + clock
- Stats screen: real cover images in "Currently reading" section
- Stats screen: replaced "Books in library" with average session length metric
- New `BookListTile` widget for list-style book display
- Grid/list view toggles on home screen and category books screen
- View mode preferences persisted in settings

### Performance Optimizations
- Background isolate for EPUB cache loading (`loadBookFromDisk`)
- Parallel image reads via `Future.wait` for faster cache loads
- Background pre-fragmentation of all chapters after initial load
- Cached Style map avoids repeated object creation
- DOM cache using `Html.fromElement` skips HTML-to-DOM conversion
- SubSlice builds only needed fragment instead of all fragments
- Measurement batch sizes reduced (7→3 first, 10→5 background)

### Technical Changes
- Database schema now at v6 (scroll_offset + scroll_fragment columns)
- `_isProgrammaticNavigation` flag prevents double save/restore
- `_chapterScrollOffsets` map stores both fraction and fragment index per chapter
- `_currentScrollFragment()` computes fragment index from cumulative heights
- `Scrollable.ensureVisible` used for fragment-level scroll restoration

---

## v1.0.0 - Initial Release (2026-08-30)
**Branch:** `main`

### Core Features
- Multi-format EPUB reader (.epub/.txt/.md/.html/.fb2)
- Custom reading themes with full customization
- Font management with system and custom fonts
- Text appearance editor (font weight, alignment, paragraph spacing, indent)
- Horizontal reader with measured-fragment pagination
- Vertical reader with lazy ListView.builder
- Magnetic snap physics for page turning
- RTL support for right-to-left languages
- Volume-key page turns
- Keep-screen-awake option
- Whole-book search with background isolate
- Multi-category system for organizing books
- Batch folder import
- Reading-now screen for quick access
- Reading statistics
- Cover generation and management
- Custom logo and launcher icons

### Reader Features
- Tap zones (left/center/right) for navigation
- Book info screen with metadata
- Bookmarks with TOC sheet
- Open last book on start
- Perception expander for focus
- Horizontal limiter (reading ruler)
- Reading mode switching (Paged/Scrolling)
- Horizontal direction options (Left to Right/Right to Left)

### Technical Implementation
- Flutter-based Android application
- SQLite database for book metadata and progress
- Background isolate for EPUB parsing
- Disk cache for instant book re-opening
- GitHub Actions workflow for automated builds
- 73 passing tests (DB, providers, fragmentation, search, catalog, physics)
