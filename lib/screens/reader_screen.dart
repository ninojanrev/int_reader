import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../models/bookmark.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/reader_options.dart';
import '../widgets/reader_settings_sheet.dart';
import '../services/settings_service.dart';
import '../services/theme_catalog.dart';
import '../services/font_service.dart';
import '../services/volume_key_service.dart';
import '../widgets/magnetic_page_physics.dart';
import '../services/epub_parser.dart';
import '../services/book_cache_service.dart';
import '../providers/library_provider.dart';
import '../widgets/reader_toc_sheet.dart';
import '../widgets/text_appearance_editor.dart';
import '../widgets/reader_search_bar.dart';
import '../widgets/book_loading_screen.dart';
import '../widgets/perception_expander.dart';
import '../widgets/horizontal_limiter.dart';
import '../services/search_index.dart';
import 'book_info_screen.dart';

class ReaderScreen extends StatefulWidget {  final Book book;

  /// When set, opens the book at this chapter instead of the last-read
  /// position (used by the Saved tab to jump to a highlight/bookmark).
  final int? startChapterOverride;
  const ReaderScreen({super.key, required this.book, this.startChapterOverride});
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  PageController? _pageController;
  int _currentPageIndex = 0; // chapter index (both modes)
  int _currentSlice = 0; // page-within-chapter (horizontal mode only)
  bool _chromeVisible = false;
  bool _bookmarked = false;
  String _fontFamily = 'Serif';
  double _fontSize = 17;
  String _readingTheme = 'Sepia';
  double _lineHeight = 1.6;
  double _pageMargin = 12.0;
  double _fontWeight = 400;
  String _textAlign = 'Justify';
  double _paragraphSpacing = 16;
  double _paragraphIndent = 0;
  bool _perceptionExpander = false;
  bool _horizontalLimiter = false;
  late String _readingMode;
  late String _horizontalDirection;

  ParsedEpub? _parsedEpub;
  bool _isLoading = true;
  String? _loadError;
  Timer? _progressSaveTimer;
  final Map<int, String> _inlinedHtmlCache = {};
  late LibraryState _library;

  final Stopwatch _readingStopwatch = Stopwatch();
  Timer? _statsFlushTimer;

  // --- Horizontal pagination state ---
  // Chapters are split into block-level fragments (never mid-line), each
  // fragment is measured once, and whole fragments are greedily packed
  // into viewport-sized pages.
  List<_ReaderPage> _pages = const [];
  List<int> _chapterFirstPage = const []; // prefix index into _pages
  bool _pagesMeasured = false;
  bool _measureScheduled = false;
  List<GlobalKey>? _measureKeys;
  double _viewportW = 0;
  double _viewportH = 0;
  Timer? _remeasureDebounce;

  // Incremental measurement: which chapters have been measured.
  int _measuredChapterStart = 0;
  int _measuredChapterEnd = 0; // exclusive
  bool _incrementalPhase = false; // true while background batches run

  // Rendered-content caches (invalidated when text metrics change).
  final Map<int, List<String>> _fragmentsCache = {};

  // Per-slot page caches: each horizontal page index / vertical chapter
  // owns its OWN widget instances, so two live slots can never share and
  // steal render objects from each other mid-swipe.
  final Map<int, Widget> _sliceContentCache = {};
  final Map<int, Widget> _verticalPageCache = {};
  // Per-fragment widget cache for vertical mode's lazy ListView: a
  // fragment lives in exactly one slot of one chapter's list, so instance
  // reuse is safe here (unlike PageView pages).
  final Map<int, List<Widget>> _verticalFragmentCache = {};
  // Natural-block strings for vertical mode (separate from the horizontal
  // pagination pipeline).
  final Map<int, List<String>> _verticalFragmentsCache = {};
  String _contentCacheSig = '';

  // In-memory bookmark lookup so page flips don't hit the database.
  final Set<int> _bookmarkedChapters = {};
  List<Bookmark> _currentBookmarks = [];

  final ScrollController _verticalScrollController = ScrollController();

  // ---- In-reader search (find in book) ----
  bool _searchActive = false;
  String _searchQuery = '';
  final List<SearchHit> _searchHits = [];
  int _activeHit = -1;
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  // Stripped plain text per chapter item, for matching.
  final Map<int, List<String>> _searchTextCache = {};
  // Per-fragment GlobalKeys for vertical-mode ensureVisible navigation.
  final Map<int, Map<int, GlobalKey>> _verticalItemKeys = {};

  // Status-bar clock in the bottom bar; refreshed periodically.
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  String get _clockText =>
      '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

  bool get _isHorizontal => _readingMode == 'Paged';
  int get _totalPages => _pages.length;
  double get _contentW => (_viewportW - 48).clamp(50.0, _viewportW);
  double get _sliceContentH => (_viewportH - _pageMargin * 2).clamp(100.0, _viewportH);

  String get _currentContentSig =>
      '$_fontFamily|$_fontSize|$_lineHeight|$_readingTheme|${_contentW.round()}|$_pageMargin';

  /// Clear page caches when any text metric changes.
  void _ensureCachesValid() {
    final sig = _currentContentSig;
    if (sig == _contentCacheSig) return;
    _contentCacheSig = sig;
    _sliceContentCache.clear();
    _verticalPageCache.clear();
    _verticalFragmentCache.clear();
    _verticalFragmentsCache.clear();
  }

  /// Theme/font resolution through the catalogs: built-in presets plus
  /// user-created themes and imported fonts, with safe fallbacks.
  ReaderTheme get _resolvedTheme =>
      ThemeCatalog.fromSettings(settings).resolve(_readingTheme);
  String get _resolvedFontFamily =>
      fontService.resolveFamily(_fontFamily, readerFontFamilies);

  List<ParsedChapter> get _chapters => _parsedEpub?.chapters ?? [];
  ParsedChapter? get _currentChapter =>
      _currentPageIndex < _chapters.length
          ? _chapters[_currentPageIndex]
          : null;

  List<String> _fragmentsFor(int chapterIdx) {
    return _fragmentsCache.putIfAbsent(chapterIdx, () {
      final html = _htmlFor(_chapters[chapterIdx]);
      final frags = EpubParserService.chapterFragments(html);
      // Never render nothing: fall back to the whole chapter.
      if (frags.isEmpty || frags.every((f) => f.trim().isEmpty)) {
        return [html];
      }
      return frags;
    });
  }

  /// Vertical mode uses NATURAL blocks (no sentence splitting, no size
  /// merging) so paragraphs flow exactly as authored — no mid-sentence
  /// seams between list items. ListView handles tall items fine.
  List<String> _verticalFragmentsFor(int chapterIdx) {
    return _verticalFragmentsCache.putIfAbsent(chapterIdx, () {
      final html = _htmlFor(_chapters[chapterIdx]);
      final blocks = EpubParserService.chapterBlocksForScrolling(html);
      if (blocks.isEmpty || blocks.every((f) => f.trim().isEmpty)) {
        return [html];
      }
      return blocks;
    });
  }

  /// Build fresh widgets for a chapter's fragments on every call.
  /// NEVER cache or share Widget instances across slots: PageView can keep
  /// two pages alive at once (mid-swipe, sub-slices), and mounting the same
  /// instance in two Element positions steals the render object, blanking
  /// the other page. Caching happens per-slot instead (see caches above).
  /// Joined HTML for one horizontal page (single Html widget per page).
  /// Combined rendered height of fragments [first..last] within a chapter.
  /// Each fragment is a separate widget in a Column, so no CSS margin
  /// collapse occurs between fragments — just sum their measured heights.
  /// [base] is the chapter's offset into [flatHeights].
  double _combinedHeightForPage(
      int chapterIdx, int first, int last, List<double> flatHeights, int base) {
    final frags = _fragmentsFor(chapterIdx);
    var total = 0.0;
    for (var i = first; i <= last && i < frags.length; i++) {
      total += flatHeights[base + i];
    }
    return total;
  }

  /// Vertical mode content: a LAZY list over the chapter's NATURAL blocks
  /// (paragraphs/headings as authored — no sentence splitting, no size
  /// merging), so text flows exactly like a book with no mid-sentence
  /// seams. Only blocks entering the viewport (plus cacheExtent) are
  /// built. Per-block widgets are cached per chapter — each block lives
  /// in exactly one slot, so instance reuse cannot trigger stealing.
  Widget _verticalContent(ReaderTheme theme, int chapterIdx) {
    final frags = _verticalFragmentsFor(chapterIdx);
    final fragWidgets =
        _verticalFragmentCache.putIfAbsent(chapterIdx, () {
      final keys = _verticalItemKeys.putIfAbsent(chapterIdx, () => {});
      return [
        for (var i = 0; i < frags.length; i++)
          SizedBox(
            key: keys.putIfAbsent(i, () => GlobalKey()),
            width: _contentW,
            child: _styledHtml(frags[i], theme),
          ),
      ];
    });
    return ListView.builder(
      controller: _verticalScrollController,
      itemCount: fragWidgets.length,
      itemBuilder: (context, index) => fragWidgets[index],
    );
  }

  /// Cached per vertical chapter — one chapter visible at a time.
  Widget _cachedVerticalContent(ReaderTheme theme, int chapterIdx) {
    return _verticalPageCache.putIfAbsent(
        chapterIdx, () => _verticalContent(theme, chapterIdx));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _fontFamily = settings.fontFamily;
    _fontSize = settings.fontSize;
    _readingTheme = settings.readingTheme;
    _lineHeight = settings.lineHeight;
    _pageMargin = settings.pageMargin;
    _fontWeight = settings.fontWeight;
    _textAlign = settings.textAlign;
    _paragraphSpacing = settings.paragraphSpacing;
    _paragraphIndent = settings.paragraphIndent;
    _perceptionExpander = settings.perceptionExpander;
    _horizontalLimiter = settings.horizontalLimiter;
    _readingMode = settings.readingMode;
    _horizontalDirection = settings.horizontalDirection;
    final startChapter =
        (widget.startChapterOverride ?? widget.book.currentChapter)
            .clamp(0, 1 << 30);
    _currentPageIndex = startChapter;
    _currentSlice = widget.book.currentPage.clamp(0, 1 << 30);
    // Vertical mode needs the controller immediately; horizontal defers
    // until measurement completes to avoid the page-0 flicker.
    if (!_isHorizontal) {
      _pageController = PageController(initialPage: _currentPageIndex);
    }
    if (settings.keepScreenAwake) WakelockPlus.enable();
    _readingStopwatch.start();
    _statsFlushTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _flushReadingTime();
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    if (settings.volumeKeysTurnPages) {
      volumeKeyService.startListening(_onVolumeKey);
    }
    _loadEpub();
  }

  void _onVolumeKey(VolumeKey key) {
    if (!mounted) return;
    if (key == VolumeKey.down) {
      _goToNextPage();
    } else {
      _goToPreviousPage();
    }
  }

  /// Move one page forward (horizontal mode: one page; vertical: chapter).
  void _goToNextPage() {
    if (_isHorizontal && _pagesMeasured && _totalPages > 0 && _pageController != null) {
      final current = _globalPageFor(_currentPageIndex, _currentSlice);
      final rtl = _horizontalDirection == 'Right to left';
      // In RTL the visual "next" page is at a lower index.
      final target = (rtl ? current - 1 : current + 1).clamp(0, _totalPages - 1);
      _pageController!.animateToPage(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } else if (!_isHorizontal) {
      _jumpToChapterAnimated(_currentPageIndex + 1);
    }
  }

  void _goToPreviousPage() {
    if (_isHorizontal && _pagesMeasured && _totalPages > 0 && _pageController != null) {
      final current = _globalPageFor(_currentPageIndex, _currentSlice);
      final rtl = _horizontalDirection == 'Right to left';
      final target = (rtl ? current + 1 : current - 1).clamp(0, _totalPages - 1);
      _pageController!.animateToPage(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } else if (!_isHorizontal) {
      _jumpToChapterAnimated(_currentPageIndex - 1);
    }
  }

  /// Animated jump to a neighbouring vertical chapter (clamped).
  void _jumpToChapterAnimated(int chapterIndex) {
    if (_pageController == null || !_pageController!.hasClients) return;
    final target =
        chapterIndex.clamp(0, _chapters.isEmpty ? 0 : _chapters.length - 1);
    _pageController!.animateToPage(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _library = context.read<LibraryState>();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _progressSaveTimer?.cancel();
      _saveProgress();
      _flushReadingTime();
    }
  }

  void _flushReadingTime() {
    final elapsedMs = _readingStopwatch.elapsedMilliseconds;
    if (elapsedMs < 5000) return;
    _readingStopwatch.reset();
    dbHelper
        .addReadingTime(DateTime.now(), elapsedMs / 60000.0)
        .catchError((_) {});
  }

  void _saveProgress() {
    final total = _totalPages;
    double progress;
    if (_isHorizontal && _pagesMeasured && total > 1) {
      progress = _globalPageFor(_currentPageIndex, _currentSlice) / (total - 1);
    } else {
      progress = _progressFor(_currentPageIndex);
    }
    _library.updateProgress(
        widget.book.id, _currentPageIndex, _currentSlice, progress);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    volumeKeyService.stopListening();
    _clockTimer?.cancel();
    _progressSaveTimer?.cancel();
    _statsFlushTimer?.cancel();
    _remeasureDebounce?.cancel();
    _readingStopwatch.stop();
    _flushReadingTime();
    WakelockPlus.disable();
    _saveProgress();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _verticalScrollController.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  double _progressFor(int chapterIndex) => _chapters.length > 1
      ? chapterIndex / (_chapters.length - 1)
      : 0.0;

  Future<void> _loadEpub() async {
    try {
      ParsedEpub parsed;

      // Try loading from disk cache first (instant). Falls back to
      // full EPUB parsing in a background isolate for books imported
      // before caching was added.
      if (await bookCache.hasCache(widget.book.id)) {
        parsed = await bookCache.load(widget.book.id) as ParsedEpub;
      } else {
        parsed = await compute(parseEpubInIsolate, widget.book.filePath);
      }

      if (!mounted) return;
      setState(() {
        _parsedEpub = parsed;
        _isLoading = false;
        _currentPageIndex = (widget.startChapterOverride ??
                widget.book.currentChapter)
            .clamp(0, parsed.chapters.length - 1);
        _currentSlice = widget.book.currentPage.clamp(0, 1 << 30);
      });
      // Load bookmarks once; page flips then check the in-memory set.
      final bookmarks =
          await _library.getBookmarksForBook(widget.book.id);
      if (!mounted) return;
      setState(() {
        _bookmarkedChapters
          ..clear()
          ..addAll(bookmarks.map((b) => b.chapterIndex));
        _bookmarked = _bookmarkedChapters.contains(_currentPageIndex);
        _currentBookmarks = bookmarks;
      });
      if (!_isHorizontal) {
        _restoreCurrentPageAfterLayoutChange();
      }
      // Horizontal mode jumps after the measurement pass completes.
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = 'Failed to load book: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Jump the PageView back to the stored location once laid out.
  void _restoreCurrentPageAfterLayoutChange() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pageController == null || !_pageController!.hasClients) return;
      final target =
          _isHorizontal ? _globalPageFor(_currentPageIndex, _currentSlice) : _currentPageIndex;
      if (_pageController!.page?.round() != target) {
        _pageController!.jumpToPage(target);
      }
    });
  }

  // ================= Measurement =================

  // Scratch data, only non-null during a measure pass.
  List<Widget>? _measureFragments;

  /// Offscreen layout pass measuring fragments, then greedy-packing
  /// whole fragments into viewport-sized pages.
  ///
  /// Uses incremental measurement: the current chapter ± a small buffer is
  /// measured first so the reader opens instantly; the remaining chapters
  /// are measured in background batches of 10.
  void _runMeasurement() {
    _measureScheduled = false;
    if (!mounted || _chapters.isEmpty || !_isHorizontal) return;

    // Phase 1: measure current chapter ± 2 (min 7 chapters total).
    final bufferStart = (_currentPageIndex - 2).clamp(0, _chapters.length);
    final bufferEnd = (_currentPageIndex + 5).clamp(0, _chapters.length);
    _measuredChapterStart = bufferStart;
    _measuredChapterEnd = bufferEnd;
    _measureBatch(bufferStart, bufferEnd, isFirstBatch: true);
  }

  /// Measure chapters [start, end) and pack into pages.
  /// On the first batch, creates the PageController.
  void _measureBatch(int start, int end, {required bool isFirstBatch}) {
    if (!mounted || start >= end) return;

    final keys = <GlobalKey>[];
    final widgets = <Widget>[];
    final chapterOffsets = <int>[];
    final fragmentCounts = <int>[];
    for (var ch = start; ch < end; ch++) {
      chapterOffsets.add(keys.length);
      final frags = _fragmentWidgets(_resolvedTheme, ch);
      fragmentCounts.add(frags.length);
      for (final w in frags) {
        final key = GlobalKey();
        keys.add(key);
        widgets.add(KeyedSubtree(key: key, child: w));
      }
    }

    setState(() {
      _measureKeys = keys;
      _measureFragments = widgets;
    });

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final usableH = _sliceContentH;
      final flatHeights = <double>[
        for (final key in keys) key.currentContext?.size?.height ?? 0,
      ];

      // Greedy-pack whole fragments into pages for this batch,
      // using combined HTML height (accounts for margin collapse).
      final batchPages = <_ReaderPage>[];
      final batchChapterFirstPage = <int>[];
      for (var ch = start; ch < end; ch++) {
        final chLocal = ch - start;
        batchChapterFirstPage.add(batchPages.length);
        final count = fragmentCounts[chLocal];
        final base = chapterOffsets[chLocal];
        var pageStart = 0;
        for (var i = 0; i < count; i++) {
          final h = flatHeights[base + i];
          if (h > usableH) {
            if (i > pageStart) {
              batchPages.add(_ReaderPage(ch, pageStart, i - 1));
            }
            final slices = (h / usableH).ceil();
            for (var s = 0; s < slices; s++) {
              batchPages.add(_ReaderPage(ch, i, i, subSlice: s, subSliceCount: slices));
            }
            pageStart = i + 1;
            continue;
          }
          final combined = _combinedHeightForPage(ch, pageStart, i, flatHeights, base);
          if (combined > usableH && i > pageStart) {
            batchPages.add(_ReaderPage(ch, pageStart, i - 1));
            pageStart = i;
          }
        }
        if (pageStart < count) {
          batchPages.add(_ReaderPage(ch, pageStart, count == 0 ? 0 : count - 1));
        } else if (count == 0) {
          batchPages.add(_ReaderPage(ch, 0, 0));
        }
      }

      if (isFirstBatch) {
        // Build initial page list: measured chapters + one placeholder per
        // unmeasured chapter so the PageView has a stable item count.
        final allPages = <_ReaderPage>[];
        final allChapterFirstPage = <int>[];
        for (var ch = 0; ch < _chapters.length; ch++) {
          allChapterFirstPage.add(allPages.length);
          if (ch >= start && ch < end) {
            // Measured: use real pages.
            final offset = ch - start;
            final chStart = offset > 0 ? batchChapterFirstPage[offset - (start > 0 ? 0 : 0)] : 0;
            final chEnd = offset < batchChapterFirstPage.length
                ? (offset + 1 < batchChapterFirstPage.length
                    ? batchChapterFirstPage[offset + 1]
                    : batchPages.length)
                : batchPages.length;
            for (var p = chStart; p < chEnd && p < batchPages.length; p++) {
              allPages.add(batchPages[p]);
            }
          } else {
            // Unmeasured: single placeholder page for the whole chapter.
            allPages.add(_ReaderPage(ch, 0, 0));
          }
        }

        _chapterFirstPage = allChapterFirstPage;
        final pagesInChapter = (_currentPageIndex + 1 < allChapterFirstPage.length
                ? allChapterFirstPage[_currentPageIndex + 1]
                : allPages.length) -
            allChapterFirstPage[_currentPageIndex];
        final slice = _currentSlice.clamp(0, (pagesInChapter - 1).clamp(0, 1 << 30));
        final targetPage = (allChapterFirstPage[_currentPageIndex] + slice)
            .clamp(0, allPages.isEmpty ? 0 : allPages.length - 1);
        _pageController = PageController(initialPage: targetPage);

        setState(() {
          _pages = allPages;
          _pagesMeasured = true;
          _measureKeys = null;
          _measureFragments = null;
        });

        // Schedule background measurement for the remaining chapters.
        if (end < _chapters.length) {
          _incrementalPhase = true;
          SchedulerBinding.instance.addPostFrameCallback((_) {
            _measureRemainingBatch();
          });
        }
      } else {
        // Background batch: replace placeholder pages for measured chapters
        // with real pages. Preserve pages from earlier batches.
        _mergeBatchPages(start, end, batchPages, batchChapterFirstPage);
        _measureKeys = null;
        _measureFragments = null;

        if (end >= _chapters.length) {
          _incrementalPhase = false;
        } else {
          // Schedule next batch.
          SchedulerBinding.instance.addPostFrameCallback((_) {
            _measureRemainingBatch();
          });
        }
      }
    });
  }

  /// Measure the next batch of 10 chapters in the background.
  void _measureRemainingBatch() {
    if (!mounted || !_incrementalPhase) return;
    final start = _measuredChapterEnd;
    final end = (start + 10).clamp(0, _chapters.length);
    if (start >= end) {
      _incrementalPhase = false;
      return;
    }
    _measuredChapterEnd = end;
    _measureBatch(start, end, isFirstBatch: false);
  }

  /// Merge a background batch's pages into the live page list,
  /// replacing placeholder pages for the measured chapters.
  void _mergeBatchPages(
      int start, int end, List<_ReaderPage> batchPages, List<int> batchChapterFirst) {
    // Build new page list: keep unmeasured chapters' placeholders,
    // replace measured chapters with real pages.
    final newPages = <_ReaderPage>[];
    final newChapterFirst = <int>[];
    for (var ch = 0; ch < _chapters.length; ch++) {
      newChapterFirst.add(newPages.length);
      if (ch >= start && ch < end) {
        // This chapter was just measured — use batch pages.
        final offset = ch - start;
        final chStart = batchChapterFirst[offset];
        final chEnd = offset + 1 < batchChapterFirst.length
            ? batchChapterFirst[offset + 1]
            : batchPages.length;
        for (var p = chStart; p < chEnd && p < batchPages.length; p++) {
          newPages.add(batchPages[p]);
        }
      } else if (ch >= _measuredChapterStart && ch < _measuredChapterEnd && ch < start) {
        // Already measured in an earlier batch — keep existing pages.
        final oldStart = _chapterFirstPage[ch];
        final oldEnd = ch + 1 < _chapterFirstPage.length
            ? _chapterFirstPage[ch + 1]
            : _pages.length;
        for (var p = oldStart; p < oldEnd && p < _pages.length; p++) {
          newPages.add(_pages[p]);
        }
      } else {
        // Not yet measured — placeholder.
        newPages.add(_ReaderPage(ch, 0, 0));
      }
    }

    setState(() {
      _pages = newPages;
      _chapterFirstPage = newChapterFirst;
    });
  }

  /// Invalidate measurements when text metrics change (font/size/spacing).
  void _scheduleRemasure() {
    if (!_isHorizontal) return;
    _remeasureDebounce?.cancel();
    _remeasureDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _pagesMeasured = false;
        _pages = const [];
        _chapterFirstPage = const [];
        _sliceContentCache.clear();
        _measureScheduled = false;
      });
    });
  }

  int _startPageOf(int chapter) => chapter < _chapterFirstPage.length
      ? _chapterFirstPage[chapter]
      : 0;

  int _pagesInChapter(int chapter) {
    if (chapter >= _chapterFirstPage.length) return 1;
    final next = chapter + 1 < _chapterFirstPage.length
        ? _chapterFirstPage[chapter + 1]
        : _pages.length;
    return (next - _chapterFirstPage[chapter]).clamp(1, 1 << 30);
  }

  int _globalPageFor(int chapter, int slice) {
    if (!_pagesMeasured || _pages.isEmpty) return chapter;
    return _startPageOf(chapter) + slice.clamp(0, _pagesInChapter(chapter) - 1);
  }

  (int, int) _locatePage(int page) {
    if (page < 0 || page >= _pages.length) {
      return (_currentPageIndex.clamp(0, _chapters.length - 1), 0);
    }
    final rec = _pages[page];
    return (rec.chapter, page - _chapterFirstPage[rec.chapter]);
  }

  // ================= Navigation =================

  void _jumpToChapter(int chapterIndex) {
    if (chapterIndex < 0 || chapterIndex >= _chapters.length) return;
    final target =
        _isHorizontal ? _globalPageFor(chapterIndex, 0) : chapterIndex;
    setState(() {
      _currentPageIndex = chapterIndex;
      _currentSlice = 0;
    });
    _pageController?.jumpToPage(target);
  }

  void _onPageChanged(int page) {
    if (_isHorizontal && _pagesMeasured && _totalPages > 0) {
      final loc = _locatePage(page);
      _currentPageIndex = loc.$1;
      _currentSlice = loc.$2;
    } else {
      _currentPageIndex = page;
      _currentSlice = 0;
    }
    setState(() {
      _bookmarked = _bookmarkedChapters.contains(_currentPageIndex);
    });
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer(const Duration(milliseconds: 600), () {
      _saveProgress();
    });
    _warmNeighbourPages();
  }

  /// Pre-build the adjacent pages right after settling so the next swipe
  /// finds them ready instead of parsing HTML mid-gesture.
  void _warmNeighbourPages() {
    if (!_isHorizontal || !_pagesMeasured) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pagesMeasured) return;
      final current =
          _isHorizontal ? _globalPageFor(_currentPageIndex, _currentSlice) : 0;
      final theme = _resolvedTheme;
      for (final page in [current - 1, current + 1]) {
        if (page >= 0 && page < _totalPages) {
          _sliceContentCache.putIfAbsent(
              page, () => _buildSliceContent(theme, page));
        }
      }
      // Keep the cache bounded: drop pages far from the current one.
      if (_sliceContentCache.length > 12) {
        _sliceContentCache.removeWhere((key, _) =>
            (key - current).abs() > 8);
      }
    });
  }

  // ================= In-reader search =================

  List<String> _searchItemsFor(int chapterIdx) =>
      _isHorizontal ? _fragmentsFor(chapterIdx) : _verticalFragmentsFor(chapterIdx);

  List<String> _searchTextsFor(int chapterIdx) {
    return _searchTextCache.putIfAbsent(chapterIdx, () {
      return [
        for (final item in _searchItemsFor(chapterIdx))
          SearchTextUtils.stripTags(item),
      ];
    });
  }

  void _openSearch() {
    setState(() {
      _searchActive = true;
      _chromeVisible = false;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    _searchFocus.unfocus();
    setState(() {
      _searchActive = false;
      _searchQuery = '';
      _searchController.clear();
      _searchHits.clear();
      _activeHit = -1;
      // Drop cached rendered content so highlight spans disappear.
      _committedHighlightQuery = '';
      _sliceContentCache.clear();
      _verticalPageCache.clear();
      _verticalFragmentCache.clear();
    });
    if (!_isHorizontal) _restoreCurrentPageAfterLayoutChange();
  }

  void _onSearchQueryChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _runSearch(value);
    });
  }

  int _searchToken = 0;

  /// Background-isolate search. Updates ONLY the results list — render
  /// caches and in-text highlights change exclusively at commit points
  /// (Enter / arrows / tapping a result), so typing never triggers page
  /// rebuilds.
  Future<void> _runSearch(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.length < 2) {
      setState(() {
        _searchQuery = query;
        _searchHits.clear();
        _activeHit = -1;
      });
      return;
    }

    final token = ++_searchToken;
    final itemsPerChapter = [
      for (var ch = 0; ch < _chapters.length; ch++) _searchItemsFor(ch),
    ];

    final result = await compute(buildAndSearchEntry, (itemsPerChapter, query));
    if (!mounted || token != _searchToken) return; // stale response

    setState(() {
      _searchQuery = query;
      _searchHits
        ..clear()
        ..addAll(result.hits);
      _activeHit = result.hits.isEmpty ? -1 : 0;
      // Plain chapters from the worker become the snippet source.
      _searchTextCache.clear();
      for (var ch = 0; ch < result.plainChapters.length; ch++) {
        _searchTextCache[ch] = result.plainChapters[ch];
      }
    });
  }

  /// The query currently rendered into highlight spans. Distinct from the
  /// live typing query: caches invalidate only when this changes.
  String _committedHighlightQuery = '';

  /// Commit point: if the query changed since the last commit, drop
  /// rendered-content caches once so pages rebuild with fresh highlights.
  void _commitHighlightQuery() {
    final q = _searchQuery.trim();
    if (_committedHighlightQuery == q) return;
    _committedHighlightQuery = q;
    _sliceContentCache.clear();
    _verticalPageCache.clear();
    _verticalFragmentCache.clear();
  }

  void _stepHit(int delta) {
    if (_searchHits.isEmpty) return;
    var next = (_activeHit + delta) % _searchHits.length;
    if (next < 0) next += _searchHits.length;
    _commitHighlightQuery();
    setState(() => _activeHit = next);
    _goToHit(_searchHits[next]);
  }

  Future<void> _goToHit(SearchHit hit) async {
    // Committing before navigating ensures the destination page builds
    // with highlight spans in place.
    _commitHighlightQuery();
    if (_isHorizontal && _pagesMeasured && _totalPages > 0) {
      final page = _pageContainingFragment(hit.chapterIdx, hit.itemIdx);
      if (page >= 0 && _pageController != null && _pageController!.hasClients) {
        await _pageController!.animateToPage(
          page,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    } else if (!_isHorizontal) {
      await _ensureVerticalItemVisible(hit.chapterIdx, hit.itemIdx);
    }
  }

  int _pageContainingFragment(int chapter, int frag) {
    for (var p = 0; p < _pages.length; p++) {
      final rec = _pages[p];
      if (rec.chapter == chapter &&
          frag >= rec.firstFrag &&
          frag <= rec.lastFrag) {
        return p;
      }
    }
    return -1;
  }

  GlobalKey? _verticalItemKey(int chapterIdx, int itemIdx) {
    return _verticalItemKeys[chapterIdx]?[itemIdx];
  }

  /// Bring a vertical block into view. If its element isn't built yet
  /// (far offscreen), jump proportionally first and retry next frame.
  Future<void> _ensureVerticalItemVisible(int chapterIdx, int itemIdx) async {
    final key = _verticalItemKey(chapterIdx, itemIdx);
    final ctx = key?.currentContext;

    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        alignment: 0.3,
      );
      return;
    }

    // Not built yet: approximate scroll position, then retry once.
    if (_verticalScrollController.hasClients) {
      final total =
          _verticalFragmentsFor(chapterIdx).length.clamp(1, 1 << 30);
      final max = _verticalScrollController.position.maxScrollExtent;
      final target = ((chapterIdx + itemIdx / total) /
              math.max(1, _chapters.length)) *
          max;
      _verticalScrollController.jumpTo(target.clamp(0.0, max));
      await Future.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      final retryCtx = key?.currentContext;
      if (retryCtx != null && retryCtx.mounted) {
        await Scrollable.ensureVisible(
          retryCtx,
          duration: const Duration(milliseconds: 200),
          alignment: 0.3,
        );
      }
    }
  }

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
    SystemChrome.setEnabledSystemUIMode(_chromeVisible
        ? SystemUiMode.edgeToEdge
        : SystemUiMode.immersiveSticky);
  }

  void _openToc() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        expand: false,
        builder: (context, scrollController) => ReaderTocSheet(
          currentChapterIndex: _currentPageIndex,
          onChapterSelected: _jumpToChapter,
          chapters: _chapters,
          bookmarks: _currentBookmarks,
          onDeleteBookmark: _deleteBookmarkFromSheet,
        ),
      ),
    );
  }

  void _openDisplaySettings() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) {
        // StatefulBuilder so the sheet rebuilds itself when selections
        // change (modal routes don't rebuild when the page behind them does).
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return ReaderSettingsSheet(
              readingTheme: _readingTheme,
              readingMode: _readingMode,
              horizontalDirection: _horizontalDirection,
              pageMargin: _pageMargin,
              textSummary:
                  '$_fontFamily \u00b7 ${_fontSize.round()}pt \u00b7 ${_fontWeightLabel()} \u00b7 ${_textAlignLabel()} \u00b7 ${_lineHeight.toStringAsFixed(1)}x',
              readerBrightness: settings.readerBrightness,
              perceptionExpander: _perceptionExpander,
              horizontalLimiter: _horizontalLimiter,
              onEditTextAppearance: () {
                Navigator.pop(sheetContext);
                _openTextAppearanceEditor();
              },
              onReadingThemeChanged: (val) {
                setState(() => _readingTheme = val);
                settings.setReadingTheme(val);
                setSheetState(() {});
              },
              onReadingModeChanged: (val) {
                setState(() {
                  _readingMode = val;
                  if (val != 'Paged') _currentSlice = 0;
                  _pagesMeasured = false;
                  _measureScheduled = false;
                  _sliceContentCache.clear();
                });
                settings.setReadingMode(val);
                setSheetState(() {});
                if (!_isHorizontal) _restoreCurrentPageAfterLayoutChange();
              },
              onHorizontalDirectionChanged: (val) {
                setState(() => _horizontalDirection = val);
                settings.setHorizontalDirection(val);
                setSheetState(() {});
                _restoreCurrentPageAfterLayoutChange();
              },
              onPageMarginChanged: (val) {
                setState(() => _pageMargin = val);
                settings.setPageMargin(val);
                _scheduleRemasure();
                setSheetState(() {});
              },
              onBrightnessChanged: (val) {
                settings.setReaderBrightness(val);
                setSheetState(() {});
              },
              onPerceptionExpanderChanged: (val) {
                setState(() => _perceptionExpander = val);
                settings.setPerceptionExpander(val);
                setSheetState(() {});
              },
              onHorizontalLimiterChanged: (val) {
                setState(() => _horizontalLimiter = val);
                settings.setHorizontalLimiter(val);
                setSheetState(() {});
              },
            );
          },
        );
      },
    );
  }

  /// Opens the shared draft-style editor; Apply commits to reader state
  /// + settings and triggers re-pagination. Cancel changes nothing.
  Future<void> _openTextAppearanceEditor() async {
    if (!mounted) return;
    final applied = await showTextAppearanceEditor(
      context,
      fontFamily: _fontFamily,
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      fontWeight: _fontWeight,
      textAlign: _textAlign,
      paragraphSpacing: _paragraphSpacing,
      paragraphIndent: _paragraphIndent,
      previewTheme: _resolvedTheme,
      onApply: (family, size, spacing, weight, align, paraSpacing, paraIndent) {
        settings.setFontFamily(family);
        settings.setFontSize(size);
        settings.setLineHeight(spacing);
        settings.setFontWeight(weight);
        settings.setTextAlign(align);
        settings.setParagraphSpacing(paraSpacing);
        settings.setParagraphIndent(paraIndent);
        setState(() {
          _fontFamily = family;
          _fontSize = size;
          _lineHeight = spacing;
          _fontWeight = weight;
          _textAlign = align;
          _paragraphSpacing = paraSpacing;
          _paragraphIndent = paraIndent;
        });
      },
    );
    if (applied && mounted) _scheduleRemasure();
  }

  void _toggleBookmark() async {
    final library = context.read<LibraryState>();
    final isCurrentlyBookmarked =
        _bookmarkedChapters.contains(_currentPageIndex);
    if (isCurrentlyBookmarked) {
      final bookmarks = await library.getBookmarksForBook(widget.book.id);
      final existing =
          bookmarks.where((b) => b.chapterIndex == _currentPageIndex).firstOrNull;
      if (existing != null && existing.id != null) {
        await library.deleteBookmark(existing.id!);
      }
      _bookmarkedChapters.remove(_currentPageIndex);
    } else {
      await library.addBookmark(Bookmark(
        bookId: widget.book.id,
        chapterIndex: _currentPageIndex,
        pageIndex: 0,
        label: _currentChapter?.title,
        createdAt: DateTime.now(),
      ));
      _bookmarkedChapters.add(_currentPageIndex);
    }
    setState(() => _bookmarked = !isCurrentlyBookmarked);
  }

  void _deleteBookmarkFromSheet(Bookmark bookmark) async {
    final library = context.read<LibraryState>();
    if (bookmark.id != null) {
      await library.deleteBookmark(bookmark.id!);
    }
    // Refresh the in-memory sets.
    final bookmarks = await library.getBookmarksForBook(widget.book.id);
    if (!mounted) return;
    setState(() {
      _bookmarkedChapters
        ..clear()
        ..addAll(bookmarks.map((b) => b.chapterIndex));
      _bookmarked = _bookmarkedChapters.contains(_currentPageIndex);
      _currentBookmarks = bookmarks;
    });
  }

  TextAlign _textAlignValue() => switch (_textAlign) {
        'Left' => TextAlign.left,
        'Center' => TextAlign.center,
        'Right' => TextAlign.right,
        _ => TextAlign.justify,
      };

  FontWeight _fontWeightValue() => FontWeight.values
      .where((w) => w.value == _fontWeight.round())
      .firstOrNull ??
      FontWeight.w400;

  String _fontWeightLabel() {
    switch (_fontWeight.round()) {
      case 100: return 'Thin';
      case 200: return 'ExtraLight';
      case 300: return 'Light';
      case 400: return 'Normal';
      case 500: return 'Medium';
      case 600: return 'SemiBold';
      case 700: return 'Bold';
      default: return 'Normal';
    }
  }

  String _textAlignLabel() {
    switch (_textAlign) {
      case 'left': return 'Left';
      case 'justify': return 'Justify';
      case 'center': return 'Center';
      case 'right': return 'Right';
      default: return 'Justify';
    }
  }

  Widget _styledHtml(String htmlContent, ReaderTheme theme) {
    final data = (_searchActive && _committedHighlightQuery.length >= 2)
        ? highlightHtmlOccurrences(htmlContent, _committedHighlightQuery)
        : htmlContent;
    return Html(
      data: data,
      style: {
        'body': Style(
          fontFamily: _resolvedFontFamily,
          fontSize: FontSize(_fontSize),
          fontWeight: _fontWeightValue(),
          lineHeight: LineHeight.number(_lineHeight),
          textAlign: _textAlignValue(),
          color: theme.text,
          margin: Margins.all(0),
        ),
        'p': Style(
          margin: Margins.only(bottom: _paragraphSpacing),
        ),
        'h1': Style(margin: Margins.only(bottom: 12), fontWeight: FontWeight.bold),
        'h2': Style(margin: Margins.only(bottom: 10), fontWeight: FontWeight.bold),
        'h3': Style(margin: Margins.only(bottom: 8), fontWeight: FontWeight.bold),
        'h4': Style(margin: Margins.only(bottom: 8), fontWeight: FontWeight.bold),
        'h5': Style(margin: Margins.only(bottom: 6), fontWeight: FontWeight.bold),
        'h6': Style(margin: Margins.only(bottom: 6), fontWeight: FontWeight.bold),
        'div': Style(margin: Margins.all(0)),
        'blockquote': Style(
          margin: Margins.only(left: 24, top: 0, bottom: 16, right: 0),
          border: Border(
            left: BorderSide(color: theme.text.withValues(alpha: 0.3), width: 3),
          ),
        ),
        'strong': Style(fontWeight: FontWeight.bold),
        'b': Style(fontWeight: FontWeight.bold),
        'em': Style(fontStyle: FontStyle.italic),
        'i': Style(fontStyle: FontStyle.italic),
        'u': Style(textDecoration: TextDecoration.underline),
        'code': Style(
          fontFamily: 'monospace',
          fontSize: FontSize(_fontSize * 0.9),
          backgroundColor: theme.text.withValues(alpha: 0.08),
        ),
        'pre': Style(
          fontFamily: 'monospace',
          fontSize: FontSize(_fontSize * 0.9),
          backgroundColor: theme.text.withValues(alpha: 0.08),
          whiteSpace: WhiteSpace.pre,
        ),
      },
    );
  }

  String _htmlFor(ParsedChapter chapter) {
    return _inlinedHtmlCache.putIfAbsent(
      chapter.index,
      () => EpubParserService.inlineImages(
          chapter.htmlContent, _parsedEpub?.images ?? const {}),
    );
  }

  /// Vertical mode: one chapter per page, scrolls internally via its own
  /// lazy ListView (fragments build only as they appear). Cached per
  /// chapter — a single chapter is only ever mounted in one place.
  Widget _buildVerticalPage(ReaderTheme theme, ParsedChapter chapter) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: _cachedVerticalContent(theme, chapter.index),
    );
  }

  /// Horizontal mode: cached per page index — adjacent pages never share
  /// widget instances, so mid-swipe both pages are safe.
  Widget _buildHorizontalSlice(ReaderTheme theme, int page) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, _pageMargin, 24, _pageMargin),
      child: _sliceContentCache.putIfAbsent(
        page,
        () => _buildSliceContent(theme, page),
      ),
    );
  }

  /// Fresh per-fragment widgets — used only by the measurement pass and
  /// the rare subSlice (over-tall fragment) pages.
  List<Widget> _fragmentWidgets(ReaderTheme theme, int chapterIdx) {
    return [
      for (final frag in _fragmentsFor(chapterIdx))
        SizedBox(width: _contentW, child: _styledHtml(frag, theme)),
    ];
  }

  /// Whether a page is a placeholder (chapter not yet fully measured).
  bool _isPlaceholderPage(int page) {
    if (page < 0 || page >= _pages.length) return false;
    final ch = _pages[page].chapter;
    final frags = _fragmentsFor(ch);
    final chapterPageCount = (ch + 1 < _chapterFirstPage.length
        ? _chapterFirstPage[ch + 1]
        : _pages.length) - _chapterFirstPage[ch];
    // Placeholder: single page for a chapter with multiple fragments.
    return chapterPageCount == 1 && frags.length > 1;
  }

  Widget _buildSliceContent(ReaderTheme theme, int page) {
    final rec = _pages[page];

    // Placeholder page: chapter not yet measured — show full chapter
    // in a scrollable ListView so the user can still read while
    // background measurement runs.
    if (_isPlaceholderPage(page)) {
      final frags = _fragmentsFor(rec.chapter);
      return SizedBox(
        width: _contentW,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: frags.length,
          itemBuilder: (context, i) => _styledHtml(frags[i], theme),
        ),
      );
    }

    // Fast path: Column of fragment widgets — matches measurement exactly
    // so margins behave identically (no margin collapse mismatch).
    if (rec.subSliceCount <= 1) {
      final frags = _fragmentsFor(rec.chapter);
      return SizedBox(
        width: _contentW,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = rec.firstFrag; i <= rec.lastFrag && i < frags.length; i++)
              SizedBox(width: _contentW, child: _styledHtml(frags[i], theme)),
          ],
        ),
      );
    }
    // Over-tall fragment pixel-sliced across its own pages.
    final widgets = _fragmentWidgets(theme, rec.chapter);
    return LayoutBuilder(builder: (context, constraints) {
      final h = constraints.maxHeight;
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: constraints.maxWidth,
          maxWidth: constraints.maxWidth,
          minHeight: 0,
          maxHeight: double.infinity,
          child: Transform.translate(
            offset: Offset(0, -(rec.subSlice * h).toDouble()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rec.firstFrag < widgets.length) widgets[rec.firstFrag],
              ],
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = _resolvedTheme;

    if (_isLoading) {
      return BookLoadingScreen(
        bookTitle: widget.book.title,
        coverImagePath: widget.book.coverImagePath,
        theme: theme,
      );
    }
    if (_loadError != null) {
      return Scaffold(
        backgroundColor: theme.background,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 48, color: theme.text.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(_loadError!, style: TextStyle(color: theme.text)),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
          ]),
        ),
      );
    }
    if (_chapters.isEmpty) {
      return Scaffold(
        backgroundColor: theme.background,
        body: Center(child: Text('No chapters found', style: TextStyle(color: theme.text))),
      );
    }

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          _viewportW = constraints.maxWidth;
          _viewportH = constraints.maxHeight;
          _ensureCachesValid();
          if (_isHorizontal && !_pagesMeasured && !_measureScheduled && _measureKeys == null) {
            _measureScheduled = true;
            SchedulerBinding.instance
                .addPostFrameCallback((_) => _runMeasurement());
          }
          return Stack(children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final dx = details.localPosition.dx;
                final w = _viewportW;
                if (dx < w * 0.33) {
                  _goToPreviousPage();
                } else if (dx > w * 0.67) {
                  _goToNextPage();
                } else {
                  _toggleChrome();
                }
              },
              child: _buildReaderBody(theme),
            ),
            // Reading aids overlays (below chrome, above content).
            if (_perceptionExpander)
              Positioned.fill(child: PerceptionExpander(
                padding: _pageMargin + 32,
                color: theme.text.withValues(alpha: 0.08),
              )),
            if (_horizontalLimiter)
              Positioned.fill(child: HorizontalLimiter(
                bandHeight: 160,
                dimColor: theme.text.withValues(alpha: 0.12),
              )),
            // Find-bar replaces the top chrome while searching.
            if (_searchActive)
              Positioned(
                top: 0, left: 0, right: 0,
                child: ReaderSearchBar(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  countText: _searchHits.isEmpty
                      ? ''
                      : '${_activeHit + 1} / ${_searchHits.length}',
                  onClose: _closeSearch,
                  onPrevious: () => _stepHit(-1),
                  onNext: () => _stepHit(1),
                  onQueryChanged: _onSearchQueryChanged,
                  resultRows: _buildSearchResultRows(theme),
                ),
              )
            else ...[
              _buildTopBar(theme, _currentChapter?.title ?? ''),
            ],
            _buildBottomBar(theme),
            if (_measureKeys != null) _buildMeasurementLayer(theme),
          ]);
        }),
      ),
    );
  }

  Widget _buildReaderBody(ReaderTheme theme) {
    if (_isHorizontal) {
      if (!_pagesMeasured || _totalPages == 0) {
        return const Center(child: CircularProgressIndicator());
      }
      return PageView.builder(
        controller: _pageController!,
        itemCount: _totalPages,
        scrollDirection: Axis.horizontal,
        reverse: _horizontalDirection == 'Right to left',
        // Inflate the adjacent page as soon as we settle, so its HTML is
        // parsed during idle time instead of mid-gesture on first swipe.
        allowImplicitScrolling: true,
        physics: const MagneticPagePhysics(),
        onPageChanged: _onPageChanged,
        itemBuilder: (context, page) => _buildHorizontalSlice(theme, page),
      );
    }
    // Vertical mode: horizontal swipes move between chapters
    // (left = next, right = previous); vertical drags pass through to the
    // inner PageView via the gesture arena.
    double? dragDx;
    return GestureDetector(
      onHorizontalDragStart: (_) => dragDx = 0,
      onHorizontalDragUpdate: (details) => dragDx = (dragDx ?? 0) + details.delta.dx,
      onHorizontalDragEnd: (details) {
        final dx = dragDx ?? 0;
        final velocity = details.primaryVelocity ?? 0;
        final committed = velocity.abs() > 500 || dx.abs() > 80;
        if (!committed) return;
        if (dx < 0 || velocity < -500) {
          _jumpToChapterAnimated(_currentPageIndex + 1); // left = next
        } else {
          _jumpToChapterAnimated(_currentPageIndex - 1); // right = prev
        }
        dragDx = null;
      },
      child: PageView.builder(
        controller: _pageController!,
        itemCount: _chapters.length,
        scrollDirection: Axis.vertical,
        allowImplicitScrolling: true,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) =>
            _buildVerticalPage(theme, _chapters[index]),
      ),
    );
  }

  /// Invisible full-width column of every fragment used purely for layout
  /// measurement (Offstage: no paint, no hit-testing).
  Widget _buildMeasurementLayer(ReaderTheme theme) {
    final fragments = _measureFragments!;
    return Positioned(
      left: 0,
      top: 0,
      width: _contentW,
      child: Offstage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: fragments,
        ),
      ),
    );
  }

  /// Snippet rows for the search results list.
  List<Widget> _buildSearchResultRows(ReaderTheme theme) {
    final rows = <Widget>[];
    for (var i = 0; i < _searchHits.length && i < 100; i++) {
      final hit = _searchHits[i];
      final texts = _searchTextsFor(hit.chapterIdx);
      final text = hit.itemIdx < texts.length ? texts[hit.itemIdx] : '';
      final snippet =
          SearchTextUtils.snippet(text, hit.start, hit.end);
      final chapterLabel = 'Ch ${hit.chapterIdx + 1}';
      final isActive = i == _activeHit;

      rows.add(ListTile(
        dense: true,
        selected: isActive,
        leading: Text(chapterLabel,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary)),
        title: Text(snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () {
          setState(() => _activeHit = i);
          _goToHit(hit);
        },
      ));
    }
    if (_searchHits.length > 100) {
      rows.add(Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Showing first 100 of ${_searchHits.length} matches',
            style: Theme.of(context).textTheme.bodySmall),
      ));
    }
    return rows;
  }

  Widget _buildTopBar(ReaderTheme theme, String chapterTitle) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      top: _chromeVisible ? 0 : -80,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() < 300) return;
            final choices = ThemeCatalog.fromSettings(settings).choices();
            if (choices.isEmpty) return;
            final currentIdx = choices.indexWhere((c) => c.key == _readingTheme);
            final nextIdx = velocity < 0
                ? (currentIdx + 1) % choices.length
                : (currentIdx - 1 + choices.length) % choices.length;
            final next = choices[nextIdx];
            setState(() => _readingTheme = next.key);
            settings.setReadingTheme(next.key);
          },
          child: Container(
            color: theme.chrome,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
            IconButton(
                icon: Icon(Icons.arrow_back, color: theme.text),
                onPressed: () => Navigator.of(context).maybePop()),
            Hero(
                tag: 'book-cover-${widget.book.id}',
                child: Container(width: 24, height: 36, decoration: BoxDecoration(
                    color: theme.chrome, borderRadius: BorderRadius.circular(3)))),
            const SizedBox(width: 8),
            Expanded(child: Text(chapterTitle, textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.text))),
            IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Search in book',
                color: theme.text,
                onPressed: _openSearch),
            IconButton(
                icon: Icon(_bookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: _bookmarked ? AppColors.accent : theme.text),
                onPressed: _toggleBookmark),
            IconButton(
                icon: Icon(Icons.info_outline, color: theme.text),
                tooltip: 'Book info',
                onPressed: () {
                  _saveProgress();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => BookInfoScreen(book: widget.book)),
                  );
                }),
          ]),
        ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(ReaderTheme theme) {
    final total = _totalPages;
    final usePages = _isHorizontal && _pagesMeasured && total > 0;
    final globalPage = usePages ? _globalPageFor(_currentPageIndex, _currentSlice) : 0;
    final percent = usePages
        ? (total > 1 ? globalPage / (total - 1) : 0.0)
        : _progressFor(_currentPageIndex);
    final posLabel = usePages
        ? '${globalPage + 1} / $total'
        : '${_currentPageIndex + 1} / ${_chapters.length}';
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      bottom: _chromeVisible ? 0 : -120,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Container(
          color: theme.chrome,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SliderTheme(
                data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
                child: Slider(
                    value: percent.clamp(0.0, 1.0),
                    activeColor: AppColors.accent,
                    inactiveColor: theme.text.withValues(alpha: 0.2),
                    onChanged: (val) {
                      final maxTarget = usePages
                          ? total - 1
                          : _chapters.length - 1;
                      if (maxTarget <= 0 || _pageController == null) return;
                      _pageController!.jumpToPage(
                          (val * maxTarget).round().clamp(0, maxTarget));
                    })),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(
                child: Text(
                  '$posLabel   \u00b7   Ch ${_currentPageIndex + 1}   \u00b7   $_clockText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11, color: theme.text.withValues(alpha: 0.7)),
                ),
              ),
              Row(children: [
                IconButton(icon: Icon(Icons.format_list_bulleted, size: 20, color: theme.text), onPressed: _openToc),
                IconButton(icon: Icon(Icons.text_fields, size: 20, color: theme.text), onPressed: _openDisplaySettings),
              ]),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// One horizontal page: a [chapter] plus the inclusive range of its
/// pre-measured fragments that fit on this page.
class _ReaderPage {
  final int chapter;
  final int firstFrag;
  final int lastFrag;
  final int subSlice;
  final int subSliceCount;
  const _ReaderPage(this.chapter, this.firstFrag, this.lastFrag,
      {this.subSlice = 0, this.subSliceCount = 1});
}









