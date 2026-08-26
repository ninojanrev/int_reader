# READER_SPEC.md — Book Reader Module Specification

**Version:** 1.0 · **Reference implementation:** Int Reader (Flutter) · **Target:** Kotlin/Android

A format-agnostic e-book reader module supporting paged (horizontal) and scrolled (vertical) reading modes, whole-book search with visual highlights, bookmarks, multi-category organization, reading-time statistics, and import of EPUB/TXT/Markdown/HTML/FB2 files.

---

## 1. Goals & Non-Goals

**Goals**
- Buttery page turns in both modes (zero jank while swiping/typing)
- Faithful text flow: never cut a line or sentence across page boundaries
- Format-blind downstream pipeline: any parser emits one internal book model
- Full settings integration; all options persisted

**Non-Goals**
- PDF/Mobi/AZW (different rendering engines; no viable pure parsers)
- Per-character selection highlighting via platform text selectors (custom overlay approach required; deferred)

---

## 2. Module Layout

```
reader:parsing    ParsedBook + format parsers + CoverGenerator
reader:paging     Fragmenter, Measurer, PagePacker, SnapPhysics
reader:search     TextIndexer, QuoteAwareSplitter helpers, SearchRepository
reader:storage    Room/SQLite: books, categories, book_categories,
                  highlights, bookmarks, daily_stats
feature:reader    Reader screen, chrome bars, settings sheets, search UI
```

---

## 3. Internal Book Model

```kotlin
data class ParsedBook(
    val title: String,
    val author: String?,          // null → "Unknown Author" upstream
    val chapters: List<ParsedChapter>,
    val coverBytes: ByteArray?,   // embedded art; may be null
    val images: Map<String, ByteArray>, // inline image resources
)
data class ParsedChapter(val title: String, val htmlContent: String, val index: Int)
```

Every parser emits this. Downstream (pagination, UI, progress, stats) is **format-blind**.

---

## 4. Persistence Schema (v4)

```sql
books(id TEXT PK, title, author, file_path, cover_image_path?,
      shelf DEFAULT 'Uncategorized', progress REAL DEFAULT 0,
      current_chapter INT DEFAULT 0, current_page INT DEFAULT 0,
      total_chapters INT DEFAULT 0, added_at INT NOT NULL,
      last_read_at INT?)

categories(id INTEGER PK AUTOINCREMENT, name TEXT UNIQUE COLLATE NOCASE,
           starred INTEGER NOT NULL DEFAULT 0)

book_categories(book_id TEXT, category_id INTEGER,
                PRIMARY KEY(book_id, category_id),
                FK book_id → books ON DELETE CASCADE,
                FK category_id → categories ON DELETE CASCADE)

highlights(id PK, book_id FK CASCADE, chapter_index, page_index,
           text, created_at)
bookmarks(id PK, book_id FK CASCADE, chapter_index, page_index,
          label?, created_at)

daily_stats(date TEXT PK 'yyyy-MM-dd', minutes REAL NOT NULL DEFAULT 0)
```

Migrations are append-only (`ALTER TABLE ADD COLUMN` / new tables); never rewrite user rows.

---

## 5. Import Pipeline

1. Copy source → `<docs>/books/<uuid><original-ext>` (preserve extension)
2. Parse via facade → `ParsedBook`
3. Cover = embedded bytes, else **generated**: brand gradient + title initials + author (`Canvas`/`Picture` → PNG), saved to `<docs>/books/<id>/cover.png`
4. Insert row (`total_chapters`, `cover_image_path`)
5. Batch mode adds:
   - Duplicate detection: title+author match, case-insensitive
   - Conflict policy setting: *skip* / *ask per book* / *replace-if-larger*
   - Replace = **in-place update**: overwrite stored file, regenerate cover, bump `total_chapters`, keep same ID → progress/categories/highlights/bookmarks survive
   - Optional folder-name-as-category (union membership for added + replaced books)
6. Failure handling: per-file try/catch; partial-file cleanup; batch summary counts `{added, updated, unchanged, failed}`

---

## 6. Text Fragmentation Pipeline

Clean first: strip XML prologs/DOCTYPEs/comments, decode CDATA, extract `<body>` inner HTML.

### 6.1 Top-level element splitter
Walk tags with depth counter (void elements & self-closing don't increment). Emit each top-level element as an atomic fragment. Fallback: unparseable input returns whole cleaned text.

### 6.2 Horizontal pipeline (page-constrained)
1. `splitLongBlocks`: blocks > 700 chars → chunks ≤ ~500 chars cut at **sentence boundaries**, re-wrapped in original tags
2. **Quote-aware gate**: a boundary is valid only when no double quote is open — straight `"` toggles parity; curly `“` opens, `”` closes (floor at zero); singles ignored (apostrophes false-trigger). Safety valve: force-split at 2× target if quotes never rebalance
3. `groupFragments`: merge consecutive blocks up to ~400 chars (boundaries still only at block edges)

### 6.3 Vertical pipeline (scroll mode)
Natural top-level blocks **only** — no splitting, no merging. A scrolling list has no page-height constraint, so authored paragraphs render exactly as written; seams become structurally impossible.

---

## 7. Pagination (Horizontal Mode)

### 7.1 Measurement pass
Offscreen layout of every fragment at content width (= viewport − horizontal padding). Record each height.

### 7.2 Greedy packing (pseudocode)

```text
usableH = viewportH - 24 - 8        // padding + safety slack
pages = []; chapterFirstPage = []
for each chapter ch:
    chapterFirstPage += pages.size
    start = 0; acc = 0
    for i, h in fragmentHeights(ch):
        if h > usableH:                       // oversized fragment
            flush current page if open
            emit ceil(h / usableH) sub-pages  // pixel-sliced fallback
            start = i + 1; acc = 0
        else:
            gap = (i > start) ? 12 : 0
            if acc > 0 && acc + gap + h > usableH:
                pages.add(Page(ch, start..i-1)); start = i; acc = h
            else: acc += gap + h
    pages.add(Page(ch, start, lastFrag))       // always close chapter
```

### 7.3 Rendering
Each page renders **only its own fragments** (top-aligned Column). Oversized fragments render via clip+translate windows. **Never share rendered-item instances between simultaneously visible pages** — causes state/view theft (blank pages mid-swipe).

---

## 8. Vertical Mode

One chapter per pager page; content is a lazy recycled list over natural blocks (no inner scroll view — the list scrolls itself). Items build only when entering viewport (+ ~250 px cache extent); off-screen items recycle. No inter-item artificial padding — authored margins suffice.

---

## 9. Position Save & Restore

- Write points: page/chapter change (debounce 600 ms), app pause, reader exit (immediate flush)
- Fraction: horizontal = globalPage ÷ (totalPages−1); vertical = chapter ÷ chapters
- On open: clamp saved indices against freshly parsed counts (files change between sessions)
- Continue-reading pick: most recent `lastReadAt` among books that were opened (`lastReadAt != null`) and unfinished — *not* gated on progress > 0 (single-chapter books mathematically stay at 0)

---

## 10. Search (find-in-book)

**Engine (background dispatcher):**
1. For each chapter: strip tags per block → plain + lowercase copies (built once, cached per session)
2. Case-insensitive substring scan → hits `{chapter, item, start, end}`; stale-response token discards out-of-order completions

**UI:** magnifier button expands chrome into find-bar: `[close] [field] [n/m] [↑] [↓]`; results list below (±48-char snippets, `Ch N` labels, matched term bolded, cap display at 100 rows)

**Commit-based highlighting:** typing updates results only. Highlights apply at commit points (Enter/arrows/result-tap): tag-safe tokenizer wraps query occurrences in *text segments* only with amber spans (active match stronger style optional). Render caches invalidate once per commit — typing never triggers rebuilds.

**Navigation:** horizontal → map `(chapter, item)` to packed page index → animate. Vertical → two-step landing: if item's view isn't inflated, proportional scroll jump, next frame precise alignment.

**Known limitation:** entity-encoded characters (`&amp;`) won't match raw `&` queries.

---

## 11. Navigation & Hardware

| Input | Behavior |
|---|---|
| Tap | Toggle chrome bars |
| Swipe ←/→ (horizontal mode) | Page turn; magnetic snap: slow drag commits past **45%** width; flick >400 px/s always turns |
| Swipe ↑/↓ (vertical mode) | Scroll within chapter; cross threshold → next/prev chapter |
| Swipe ←/→ (vertical mode) | Next/prev chapter (animated 300 ms) |
| Volume Down / Up | Next / previous page-chapter; consumed (no volume change); settings toggle, both modes |

Position restore always clamps against the fresh parse.

---

## 12. Reading-Time Stats & Streaks

- Stopwatch accumulates during open reader; flushed every 60 s, on pause, and on close (< 5 s sessions ignored)
- Upsert into `daily_stats`
- Streaks: consecutive days ending today/yesterday; best streak = longest run over history
- Weekly chart = last 7 calendar days (Mon-start), future days dimmed
- Monthly goal card: days-read-this-month vs fixed target (20)

---

## 13. Settings Surface

Appearance: dark mode (instant switch — zero theme animation duration), animated library backdrop toggle.
Reading: text appearance editor (**draft model with live preview + Apply/Cancel** covering family/size/spacing), import font, reading theme (locked presets + custom themes w/ color pickers + live preview), page-turn style (reserved), keep-screen-awake, mode, flip direction, volume keys.
Library: default sort (Recently added / Title / Author / Progress), manage categories (+ star), storage used (real disk scan).
Import: replace-on-import master + conflict policy.
Notifications: daily reminder toggle + time picker (exact-alarm-free inexact scheduling + boot receiver).
About: logo, version, author, GitHub link.

---

## 14. Performance Rules (hard-won)

1. Never share rendered-item instances across simultaneously visible pages → theft/blanking
2. Pre-build pager neighbors at settle (offscreen limit 1) → first swipe instant
3. Lazy per-item construction while scrolling; dispose off-screen
4. Suspend all animation clocks for non-visible tabs/screens
5. Background thread for indexing/matching; stale-response tokens
6. Commit-based invalidation; debounce style changes ~400 ms; debounce position writes 600 ms
7. Snippet/highlight passes tokenize tags vs text — never regex across markup
8. Clamp restored positions after re-parse
9. Fixed-size preview containers in editors (sliders must not push layout)

---

## 15. Tuning Constants Reference

```
PAGE_TURN_DEBOUNCE        600 ms
PROGRESS_FLUSH_INTERVAL   60 s
MIN_SESSION_MS            5000
SEARCH_DEBOUNCE           250 ms
SEARCH_SNIPPET_RADIUS     48 chars
SEARCH_MIN_QUERY_LEN      2
RESULT_ROW_CAP            100
LONG_BLOCK_THRESHOLD      700 chars
MERGE_GROUP_TARGET        400 chars
SENTENCE_CHUNK_TARGET     500 chars
QUOTE_FORCE_SPLIT         2 × chunk target
FRAG_GAP                  12 px
MEASURE_SLACK             8 px
MAGNETIC_SNAP_THRESHOLD   0.45 (of page width)
FLICK_COMMIT_VELOCITY     400 px/s
CHAPTER_SWIPE_VELOCITY    500 px/s (or ≥80 px displacement)
COVER_WIDTH               600 px (generated)
READING_THEME_FALLBACK    "Sepia"
MONTHLY_DAY_GOAL          20 days
```

---

## 16. Kotlin/Android Concept Mapping

| Flutter piece | Android equivalent |
|---|---|
| Horizontal `PageView.builder` | `ViewPager2` + `FragmentStateAdapter` / Compose `HorizontalPager` |
| `ListView.builder` (lazy vertical) | `RecyclerView` / Compose `LazyColumn` |
| `compute()` background isolate | Coroutines on `Dispatchers.Default` |
| `SharedPreferences` settings wrapper | DataStore (Preferences) |
| Runtime font loader (TTF/OTF) | Downloadable Fonts API / `Typeface.createFromAsset` |
| Wake-lock plugin | `FLAG_KEEP_SCREEN_ON` on reader window |
| HTML rendering (`flutter_html`) | `HtmlCompat` Spannable text, or ReadiumKit for full EPUB fidelity |
| Offscreen measure pass | Inflate in an off-screen parent or precompute with a shared `TextMeasurer` |
| GlobalKey ensure-visible | `LinearLayoutManager.scrollToPositionWithOffset` after diff settles |
| Local notifications + boot receiver | WorkManager/AlarmManager + `BOOT_COMPLETED` receiver |

---

*End of specification.*
