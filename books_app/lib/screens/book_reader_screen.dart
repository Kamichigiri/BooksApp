import 'dart:async';

import 'package:books_app/domain/database/app_database.dart';
import 'package:books_app/domain/models/books.dart';
import 'package:books_app/widgets/bar_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:vocsy_epub_viewer/epub_viewer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Reader Theming
// ─────────────────────────────────────────────────────────────────────────────
enum ReaderTheme { light, dark, sepia }

extension ReaderThemeExt on ReaderTheme {
  Color get background {
    switch (this) {
      case ReaderTheme.light:
        return const Color(0xFFFAFAFA);
      case ReaderTheme.dark:
        return const Color(0xFF121212);
      case ReaderTheme.sepia:
        return const Color(0xFFF5ECD7);
    }
  }

  Color get foreground {
    switch (this) {
      case ReaderTheme.light:
        return const Color(0xFF1A1A2E);
      case ReaderTheme.dark:
        return const Color(0xFFE8E8F0);
      case ReaderTheme.sepia:
        return const Color(0xFF3B2E1A);
    }
  }

  Color get appBarColor {
    switch (this) {
      case ReaderTheme.light:
        return const Color(0xFFFFFFFF);
      case ReaderTheme.dark:
        return const Color(0xFF1E1E2E);
      case ReaderTheme.sepia:
        return const Color(0xFFEBDFC8);
    }
  }

  String get label {
    switch (this) {
      case ReaderTheme.light:
        return 'Light';
      case ReaderTheme.dark:
        return 'Dark';
      case ReaderTheme.sepia:
        return 'Sepia';
    }
  }

  IconData get icon {
    switch (this) {
      case ReaderTheme.light:
        return Icons.light_mode_rounded;
      case ReaderTheme.dark:
        return Icons.dark_mode_rounded;
      case ReaderTheme.sepia:
        return Icons.wb_incandescent_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reading Mode
// ─────────────────────────────────────────────────────────────────────────────
enum ReadingMode { paginated, continuous }

// ─────────────────────────────────────────────────────────────────────────────
// BookReaderScreen
// ─────────────────────────────────────────────────────────────────────────────
class BookReaderScreen extends StatefulWidget {
  final Book book;

  const BookReaderScreen({super.key, required this.book});

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  late Book _book;
  List<Bookmark> _bookmarks = [];
  ReaderTheme _theme = ReaderTheme.light;
  ReadingMode _readingMode = ReadingMode.paginated;
  double _fontSize = 16.0;
  bool _showControls = true;
  bool _showToc = false;
  bool _showBookmarkPanel = false;
  int _currentPage = 0;
  int _totalPages = 20;

  // ── PDF Controller ─────────────────────────────────────────────────────────
  final PdfViewerController _pdfController = PdfViewerController();
  PdfScrollDirection _pdfScrollDirection = PdfScrollDirection.horizontal;
  StreamSubscription<dynamic>? _epubLocatorSubscription;

  // ── PageView controller for demo ───────────────────────────────────────────
  late PageController _demoPageController;

  // ── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _controlsAnimCtrl;
  late Animation<double> _controlsFadeAnim;
  late AnimationController _bookmarkPanelAnimCtrl;
  late Animation<Offset> _bookmarkPanelSlideAnim;

  // ── Prefs key (reader UI settings only) ────────────────────────────────────
  String get _prefsKey => 'reader_${widget.book.name.hashCode}';

  // ── Sample TOC ────────────────────────────────────────────────────────────
  final List<_TocEntry> _tocEntries = const [
    _TocEntry(title: 'Introduction', page: 1),
    _TocEntry(title: 'Chapter 1 — Origins', page: 3),
    _TocEntry(title: 'Chapter 2 — The Turning Point', page: 7),
    _TocEntry(title: 'Chapter 3 — Into the Unknown', page: 11),
    _TocEntry(title: 'Chapter 4 — Resolution', page: 15),
    _TocEntry(title: 'Epilogue', page: 18),
    _TocEntry(title: 'Bibliography', page: 20),
  ];

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _currentPage = _book.currentPage;
    _demoPageController = PageController(initialPage: _currentPage);

    _controlsAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _controlsFadeAnim =
        CurvedAnimation(parent: _controlsAnimCtrl, curve: Curves.easeOut);

    _bookmarkPanelAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bookmarkPanelSlideAnim = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _bookmarkPanelAnimCtrl, curve: Curves.easeOut));

    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _book.fileType == BookFileType.epub) {
        _openEpubReader();
      }
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _saveSettings();
    _controlsAnimCtrl.dispose();
    _bookmarkPanelAnimCtrl.dispose();
    _pdfController.dispose();
    _demoPageController.dispose();
    unawaited(_epubLocatorSubscription?.cancel());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── Persistence ────────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    // Load reader UI settings from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('${_prefsKey}_theme') ?? 0;
    final fontSize = prefs.getDouble('${_prefsKey}_fontSize') ?? 16.0;

    // Load fresh book and bookmarks from SQLite (only possible if book has a db id)
    List<Bookmark> bookmarks = [];
    if (_book.id != null) {
      final dbBook = await AppDatabase.instance.getBook(_book.id!);
      if (dbBook != null) {
        _book = dbBook;
        _currentPage = _book.currentPage;
        if (_book.numberOfPages > 0) {
          _totalPages = _book.numberOfPages;
        }
      }
      bookmarks = await AppDatabase.instance.getBookmarksForBook(_book.id!);
    }

    if (!mounted) return;
    setState(() {
      _theme = ReaderTheme.values[themeIndex.clamp(0, 2)];
      _fontSize = fontSize;
      _bookmarks = bookmarks;
    });
  }

  void _savePrefs() {
    _saveSettings();
  }

  Future<void> _saveSettings() async {
    // Only UI preferences go to SharedPreferences; data is in SQLite
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_prefsKey}_theme', _theme.index);
    await prefs.setDouble('${_prefsKey}_fontSize', _fontSize);

    // Persist current page back to DB if the book has an id
    if (_book.id != null) {
      await AppDatabase.instance.updateBookProgress(
        bookId: _book.id!,
        currentPage: _currentPage,
        numberOfPages: _totalPages,
      );
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _controlsAnimCtrl.forward();
    } else {
      _controlsAnimCtrl.reverse();
    }
  }

  void _toggleToc() => setState(() => _showToc = !_showToc);

  void _toggleBookmarkPanel() {
    setState(() => _showBookmarkPanel = !_showBookmarkPanel);
    if (_showBookmarkPanel) {
      _bookmarkPanelAnimCtrl.forward();
    } else {
      _bookmarkPanelAnimCtrl.reverse();
    }
  }

  void _toggleReadingMode() {
    setState(() {
      _readingMode = _readingMode == ReadingMode.paginated
          ? ReadingMode.continuous
          : ReadingMode.paginated;
      _pdfScrollDirection = _readingMode == ReadingMode.paginated
          ? PdfScrollDirection.horizontal
          : PdfScrollDirection.vertical;
    });
  }

  Future<void> _openEpubReader() async {
    if (_book.filePath == null || _book.filePath!.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No EPUB file is available to open.')),
      );
      return;
    }

    try {
      await VocsyEpub.setConfig(
        themeColor: Theme.of(context).primaryColor,
        identifier: (_book.id ?? _book.name.hashCode).toString(),
        scrollDirection: EpubScrollDirection.ALLDIRECTIONS,
        allowSharing: true,
        enableTts: false,
        nightMode: _theme == ReaderTheme.dark,
      );

      _epubLocatorSubscription ??= VocsyEpub.locatorStream.listen(
        (locator) => debugPrint('EPUB locator: $locator'),
      );

      await VocsyEpub.open(
        _book.filePath!,
        lastLocation: null,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open EPUB: $e')),
      );
    }
  }

  bool get _isCurrentPageBookmarked =>
      _bookmarks.any((b) => b.page == _currentPage);

  Future<void> _addBookmark(
    BookmarkColor color, {
    String text = '',
    String chapter = '',
  }) async {
    if (_isCurrentPageBookmarked) return;
    final bm = Bookmark(
      bookId: _book.id ?? -1,
      text: text,
      chapter: chapter,
      textColor: color,
      page: _currentPage,
      createdAt: DateTime.now(),
    );
    // Persist to SQLite if book has an id
    Bookmark saved = bm;
    if (_book.id != null) {
      final newId = await AppDatabase.instance.insertBookmark(bm);
      saved = bm.copyWith(id: newId);
    }
    setState(() => _bookmarks = [..._bookmarks, saved]);
    _showBookmarkAddedSnack(color);
  }

  Future<void> _removeBookmark(int page) async {
    final bm = _bookmarks.firstWhere((b) => b.page == page,
        orElse: () => Bookmark(
              bookId: _book.id ?? -1,
              text: '',
              page: page,
              createdAt: DateTime.now(),
            ));
    if (bm.id != null) {
      await AppDatabase.instance.deleteBookmark(bm.id!);
    }
    setState(
        () => _bookmarks = _bookmarks.where((b) => b.page != page).toList());
  }

  void _showBookmarkAddedSnack(BookmarkColor color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Color(color.argb),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text('Bookmark added — page ${_currentPage + 1}'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E1E2E),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _goToPage(int page) {
    final clamped = page.clamp(0, _totalPages - 1);
    if (_book.filePath != null && _book.fileType == BookFileType.pdf) {
      _pdfController.jumpToPage(clamped + 1);
    } else {
      _demoPageController.jumpToPage(clamped);
    }
    setState(() => _currentPage = clamped);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bgColor = _theme.background;
    final fgColor = _theme.foreground;
    final appBarColor = _theme.appBarColor;
    final progress = _totalPages > 1 ? _currentPage / (_totalPages - 1) : 0.0;

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: bgColor,
        appBarTheme: AppBarTheme(backgroundColor: appBarColor),
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        body: GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // ── Main Content ──────────────────────────────────────────────
              _buildReaderContent(fgColor),

              // ── Top AppBar ────────────────────────────────────────────────
              _buildTopBar(appBarColor, fgColor, progress),

              // ── Bottom Controls ───────────────────────────────────────────
              _buildBottomBar(appBarColor, fgColor, progress),

              // ── TOC Overlay ───────────────────────────────────────────────
              if (_showToc) _buildTocOverlay(bgColor, fgColor),

              // ── Bookmark Panel ────────────────────────────────────────────
              _buildBookmarkPanel(bgColor, fgColor),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reader Content ─────────────────────────────────────────────────────────
  Widget _buildReaderContent(Color fgColor) {
    if (_book.filePath == null || _book.filePath!.isEmpty) {
      return _buildDemoContent(fgColor);
    }
    if (_book.fileType == BookFileType.pdf) {
      return _buildPdfContent();
    }
    // EPUB — prompt to open native viewer
    return _buildEpubPlaceholder(fgColor);
  }

  Widget _buildPdfContent() {
    final isUrl = _book.filePath!.startsWith('http');
    if (isUrl) {
      return SfPdfViewer.network(
        _book.filePath!,
        controller: _pdfController,
        scrollDirection: _pdfScrollDirection,
        pageLayoutMode: _readingMode == ReadingMode.paginated
            ? PdfPageLayoutMode.single
            : PdfPageLayoutMode.continuous,
        initialPageNumber: _currentPage + 1,
        enableDoubleTapZooming: true,
        enableTextSelection: true,
        canShowScrollHead: false,
        canShowScrollStatus: false,
        onPageChanged: (PdfPageChangedDetails d) {
          setState(() => _currentPage = d.newPageNumber - 1);
          _savePrefs();
        },
        onDocumentLoaded: (PdfDocumentLoadedDetails d) {
          setState(() => _totalPages = d.document.pages.count);
          if (_book.id != null) {
            AppDatabase.instance.updateBookProgress(
              bookId: _book.id!,
              currentPage: _currentPage,
              numberOfPages: d.document.pages.count,
            );
          }
        },
      );
    } else {
      return SfPdfViewer.asset(
        _book.filePath!,
        controller: _pdfController,
        scrollDirection: _pdfScrollDirection,
        pageLayoutMode: _readingMode == ReadingMode.paginated
            ? PdfPageLayoutMode.single
            : PdfPageLayoutMode.continuous,
        initialPageNumber: _currentPage + 1,
        enableDoubleTapZooming: true,
        enableTextSelection: true,
        canShowScrollHead: false,
        canShowScrollStatus: false,
        onPageChanged: (PdfPageChangedDetails d) {
          setState(() => _currentPage = d.newPageNumber - 1);
          _savePrefs();
        },
        onDocumentLoaded: (PdfDocumentLoadedDetails d) {
          setState(() => _totalPages = d.document.pages.count);
          if (_book.id != null) {
            AppDatabase.instance.updateBookProgress(
              bookId: _book.id!,
              currentPage: _currentPage,
              numberOfPages: d.document.pages.count,
            );
          }
        },
      );
    }
  }

  Widget _buildEpubPlaceholder(Color fgColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_rounded,
                size: 72, color: fgColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Open EPUB Reader',
              style: TextStyle(color: fgColor, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap below to launch the native EPUB viewer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fgColor.withValues(alpha: 0.72),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openEpubReader,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open EPUB'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoContent(Color fgColor) {
    return Column(
      children: [
        // Spacer for top bar
        const SizedBox(height: 100),
        Expanded(
          child: PageView.builder(
            scrollDirection: _readingMode == ReadingMode.paginated
                ? Axis.horizontal
                : Axis.vertical,
            controller: _demoPageController,
            physics: _readingMode == ReadingMode.paginated
                ? const PageScrollPhysics()
                : const BouncingScrollPhysics(),
            onPageChanged: (page) {
              setState(() {
                _currentPage = page;
                _totalPages = 20;
              });
              _savePrefs();
            },
            itemCount: 20,
            itemBuilder: (context, index) => _DemoPage(
              pageIndex: index,
              fontSize: _fontSize,
              fgColor: fgColor,
              bgColor: _theme.background,
              bookmark: _bookmarks.where((b) => b.page == index).firstOrNull,
            ),
          ),
        ),
        // Spacer for bottom bar
        const SizedBox(height: 110),
      ],
    );
  }

  // ── Top Bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar(Color appBarColor, Color fgColor, double progress) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _controlsFadeAnim,
        child: IgnorePointer(
          ignoring: !_showControls,
          child: Container(
            decoration: BoxDecoration(
              color: appBarColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_rounded,
                              color: fgColor, size: 20),
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _book.title,
                                style: TextStyle(
                                  color: fgColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _book.author,
                                style: TextStyle(
                                  color: fgColor.withValues(alpha: 0.5),
                                  fontSize: 11.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        BarIconButton(
                          icon: Icons.format_list_bulleted_rounded,
                          color: fgColor,
                          tooltip: 'Table of Contents',
                          onTap: _toggleToc,
                        ),
                        BarIconButton(
                          icon: _isCurrentPageBookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: _isCurrentPageBookmarked
                              ? const Color(0xFFE53935)
                              : fgColor,
                          tooltip: _isCurrentPageBookmarked
                              ? 'Remove Bookmark'
                              : 'Bookmark this page',
                          onTap: _isCurrentPageBookmarked
                              ? () => _removeBookmark(_currentPage)
                              : _showAddBookmarkDialog,
                        ),
                        BarIconButton(
                          icon: Icons.bookmarks_rounded,
                          color: fgColor,
                          tooltip: 'All Bookmarks',
                          onTap: _toggleBookmarkPanel,
                        ),
                      ],
                    ),
                  ),
                  // Progress bar
                  LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: fgColor.withValues(alpha: 0.08),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFFE53935)),
                    minHeight: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Bottom Bar ─────────────────────────────────────────────────────────────
  Widget _buildBottomBar(Color appBarColor, Color fgColor, double progress) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _controlsFadeAnim,
        child: IgnorePointer(
          ignoring: !_showControls,
          child: Container(
            decoration: BoxDecoration(
              color: appBarColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Page slider
                    Row(
                      children: [
                        Text(
                          'Pg ${_currentPage + 1}',
                          style: TextStyle(
                            color: fgColor.withValues(alpha: 0.55),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 7),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 16),
                              activeTrackColor: const Color(0xFFE53935),
                              inactiveTrackColor:
                                  fgColor.withValues(alpha: 0.12),
                              thumbColor: const Color(0xFFE53935),
                              overlayColor: const Color(0xFFE53935)
                                  .withValues(alpha: 0.15),
                            ),
                            child: Slider(
                              value: _currentPage.toDouble(),
                              min: 0,
                              max: (_totalPages - 1).toDouble().clamp(1, 9999),
                              onChanged: (v) => _goToPage(v.round()),
                            ),
                          ),
                        ),
                        Text(
                          'Pg $_totalPages',
                          style: TextStyle(
                            color: fgColor.withValues(alpha: 0.55),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Controls row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        BottomControlItem(
                          icon: Icons.text_fields_rounded,
                          label: '${_fontSize.toInt()}px',
                          color: fgColor,
                          onTap: _showFontSizeDialog,
                        ),
                        BottomControlItem(
                          icon: _theme.icon,
                          label: _theme.label,
                          color: fgColor,
                          onTap: _showThemeSelector,
                        ),
                        BottomControlItem(
                          icon: _readingMode == ReadingMode.paginated
                              ? Icons.auto_stories_rounded
                              : Icons.swap_vert_rounded,
                          label: _readingMode == ReadingMode.paginated
                              ? 'Pages'
                              : 'Scroll',
                          color: fgColor,
                          onTap: _toggleReadingMode,
                        ),
                        BottomControlItem(
                          icon: Icons.percent_rounded,
                          label: '${(progress * 100).toStringAsFixed(0)}%',
                          color: fgColor,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── TOC Overlay ────────────────────────────────────────────────────────────
  Widget _buildTocOverlay(Color bgColor, Color fgColor) {
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: _toggleToc,
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: MediaQuery.of(context).size.width * 0.78,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                color: bgColor,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
                        child: Row(
                          children: [
                            const Icon(Icons.format_list_bulleted_rounded,
                                color: Color(0xFFE53935), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Table of Contents',
                                style: TextStyle(
                                  color: fgColor,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close_rounded,
                                  color: fgColor.withValues(alpha: 0.4)),
                              onPressed: _toggleToc,
                            ),
                          ],
                        ),
                      ),
                      Divider(
                          height: 1, color: fgColor.withValues(alpha: 0.08)),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _tocEntries.length,
                          itemBuilder: (_, i) {
                            final entry = _tocEntries[i];
                            final isCurrent = _currentPage >= entry.page - 1 &&
                                (i == _tocEntries.length - 1 ||
                                    _currentPage < _tocEntries[i + 1].page - 1);
                            return _TocItem(
                              entry: entry,
                              isActive: isCurrent,
                              fgColor: fgColor,
                              onTap: () {
                                _goToPage(entry.page - 1);
                                _toggleToc();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bookmark Side Panel ────────────────────────────────────────────────────
  Widget _buildBookmarkPanel(Color bgColor, Color fgColor) {
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      width: MediaQuery.of(context).size.width * 0.82,
      child: SlideTransition(
        position: _bookmarkPanelSlideAnim,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            color: bgColor,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.bookmarks_rounded,
                            color: Color(0xFFE53935), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bookmarks',
                            style: TextStyle(
                              color: fgColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: fgColor.withValues(alpha: 0.4)),
                          onPressed: _toggleBookmarkPanel,
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: fgColor.withValues(alpha: 0.08)),
                  if (_bookmarks.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bookmark_border_rounded,
                                size: 52,
                                color: fgColor.withValues(alpha: 0.15)),
                            const SizedBox(height: 12),
                            Text(
                              'No bookmarks yet',
                              style: TextStyle(
                                  color: fgColor.withValues(alpha: 0.35),
                                  fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _bookmarks.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 1, color: fgColor.withValues(alpha: 0.06)),
                        itemBuilder: (_, i) {
                          final bm = _bookmarks[i];
                          return _BookmarkItem(
                            bookmark: bm,
                            fgColor: fgColor,
                            onTap: () {
                              _goToPage(bm.page);
                              _toggleBookmarkPanel();
                            },
                            onDelete: () => _removeBookmark(bm.page),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────
  void _showAddBookmarkDialog() {
    BookmarkColor selectedColor = BookmarkColor.yellow;
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
            0,
            0,
            0,
            MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _theme.appBarColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _theme.foreground.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Bookmark — Page ${_currentPage + 1}',
                  style: TextStyle(
                    color: _theme.foreground,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Colour',
                  style: TextStyle(
                    color: _theme.foreground.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: BookmarkColor.values.map((c) {
                    final sel = c == selectedColor;
                    return GestureDetector(
                      onTap: () => setModal(() => selectedColor = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 10),
                        width: sel ? 44 : 36,
                        height: sel ? 44 : 36,
                        decoration: BoxDecoration(
                          color: Color(c.argb),
                          shape: BoxShape.circle,
                          border: sel
                              ? Border.all(
                                  color:
                                      _theme.foreground.withValues(alpha: 0.6),
                                  width: 2.5)
                              : null,
                          boxShadow: sel
                              ? [
                                  BoxShadow(
                                    color:
                                        Color(c.argb).withValues(alpha: 0.55),
                                    blurRadius: 10,
                                  )
                                ]
                              : null,
                        ),
                        child: sel
                            ? const Icon(Icons.check_rounded,
                                size: 18, color: Colors.black54)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: noteCtrl,
                  style: TextStyle(color: _theme.foreground),
                  decoration: InputDecoration(
                    hintText: 'Add a note (optional)',
                    hintStyle: TextStyle(
                        color: _theme.foreground.withValues(alpha: 0.35)),
                    filled: true,
                    fillColor: _theme.foreground.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _addBookmark(
                        selectedColor,
                        text: noteCtrl.text.trim(),
                      );
                    },
                    child: const Text('Save Bookmark',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFontSizeDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _theme.appBarColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _theme.foreground.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Font Size',
                  style: TextStyle(
                      color: _theme.foreground,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('A',
                      style: TextStyle(
                          color: _theme.foreground.withValues(alpha: 0.5),
                          fontSize: 13)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: const Color(0xFFE53935),
                        thumbColor: const Color(0xFFE53935),
                        inactiveTrackColor:
                            _theme.foreground.withValues(alpha: 0.12),
                      ),
                      child: Slider(
                        value: _fontSize,
                        min: 12,
                        max: 28,
                        divisions: 8,
                        label: '${_fontSize.toInt()}px',
                        onChanged: (v) {
                          setModal(() => _fontSize = v);
                          setState(() => _fontSize = v);
                        },
                      ),
                    ),
                  ),
                  Text('A',
                      style: TextStyle(
                          color: _theme.foreground.withValues(alpha: 0.5),
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _theme.foreground.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'The quick brown fox jumps over the lazy dog.',
                  style: TextStyle(
                    color: _theme.foreground,
                    fontSize: _fontSize,
                    height: 1.65,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _theme.appBarColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _theme.foreground.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Reading Theme',
                style: TextStyle(
                    color: _theme.foreground,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ReaderTheme.values.map((t) {
                final sel = t == _theme;
                return GestureDetector(
                  onTap: () {
                    setState(() => _theme = t);
                    _savePrefs();
                    Navigator.of(ctx).pop();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: t.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sel
                            ? const Color(0xFFE53935)
                            : Colors.grey.withValues(alpha: 0.2),
                        width: sel ? 2 : 1,
                      ),
                      boxShadow: sel
                          ? [
                              BoxShadow(
                                color: const Color(0xFFE53935)
                                    .withValues(alpha: 0.2),
                                blurRadius: 10,
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Icon(t.icon, color: t.foreground, size: 24),
                        const SizedBox(height: 8),
                        Text(
                          t.label,
                          style: TextStyle(
                            color: t.foreground,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Demo Page Widget
// ─────────────────────────────────────────────────────────────────────────────
class _DemoPage extends StatelessWidget {
  final int pageIndex;
  final double fontSize;
  final Color fgColor;
  final Color bgColor;
  final Bookmark? bookmark;

  const _DemoPage({
    required this.pageIndex,
    required this.fontSize,
    required this.fgColor,
    required this.bgColor,
    this.bookmark,
  });

  static const _contents = [
    'In the beginning there was a story. And the story breathed life into the world, word by word, sentence by sentence, carrying the weight of dreams and the lightness of hope.\n\nThe author stared at the blank page, knowing that every letter was a footstep into unknown territory. To write was to be brave.',
    'Chapter One: The Awakening\n\nShe opened her eyes to a world reborn. The morning light filtered through the curtains like liquid amber, painting the walls in hues of warmth she had almost forgotten existed. The city outside hummed like a great, sleeping beast.',
    'The city hummed with a thousand voices, each one a melody in the great symphony of existence. Marcus walked through the cobblestone streets, his coat pulled tight against the autumn chill. Leaves crunched underfoot, each step echoing through the empty lane.',
    'There are moments in life that redefine everything that came before. This was one of those moments. The letter lay open on the table, its words rearranging the architecture of possibility. He read it once, twice, a third time — still unable to believe.',
    '"You never truly know a person," Elena said softly, "until you\'ve seen them choose between what they want and what they know is right." He had no answer for her. Some truths arrive too large for words, filling the room like a flood of warm, honest light.',
    'The library stood at the edge of the old quarter, its stone façade worn smooth by centuries of weather and wonder. Inside, the smell of aged paper and cedar wood wrapped around visitors like a familiar embrace. She ran her fingers along the spines.',
    'Chapter Two: The Reckoning\n\n"Every decision you\'ve made has led you here," the old man said, his voice low and deliberate. "Now the question isn\'t what you regret. The question is what you choose to do next." The fire crackled in agreement.',
    'Dawn arrived quietly, as it always does — not with announcement but with a slow brightening, the night giving way without ceremony or drama. She watched from the hilltop as the valley below came alive with pale gold and soft violet.',
    'There is a particular kind of grief that comes not from loss, but from nearly losing something. From standing at the edge of the abyss, looking down, and stepping back. From knowing, viscerally, what could have been — and wasn\'t.',
    'The map spread across the entire table, edges curling slightly where age had claimed them. He had memorized every detail, every contour — yet still the landscape seemed to hold secrets he hadn\'t yet earned the right to know.',
    'Chapter Three: Into the Unknown\n\nThe expedition set out at first light, twelve souls stepping into a wilderness that hadn\'t been mapped in living memory. Their equipment was good. Their courage was better. What they found would change everything.',
    'Language is a strange vessel. It holds our thoughts like water in cupped hands — imperfect, incomplete, always leaking at the edges. Yet we drink from it anyway, grateful for what remains.',
    'In science, we call it entropy — the tendency of systems to move toward disorder. In life, we call it Tuesday. She laughed at her own joke, and the sound of it, genuine and warm, surprised even her.',
    'The mountain didn\'t care about human ambition. It simply was — ancient, immovable, indifferent. Yet still they climbed. That, perhaps, was the most human thing about it: the climbing in spite of indifference.',
    'Chapter Four: Resolution\n\nHe had rehearsed this moment ten thousand times in his mind. Now that it had arrived, he found that no rehearsal could have prepared him for the simple, devastating weight of it. Some things can only be lived.',
    'Peace, she discovered, wasn\'t the absence of noise. It was the presence of something quieter than noise — a stillness that existed underneath, independent of circumstance. She had always assumed peace was something to be found. It turned out to be something to be returned to.',
    'The letters never arrived. Or perhaps they did, and were swallowed by the distance between them — a distance that was not measured in miles but in choices, in silences, in all the small surrenders that accumulate into a life.',
    'Epilogue\n\nYears later, when she told the story, she always began in the same place: not at the beginning, but at the moment everything changed. "There are two ways to tell a story," she would say. "Chronologically — or honestly."',
    'What we leave behind is rarely what we intended. The great irony of legacy is that it is shaped not by the sculptor but by those who encounter the work afterwards, who bring their own eyes, their own wounds, their own wild interpretations.',
    'Bibliography & Notes\n\nThe ideas explored in this volume draw from a vast tradition of philosophical and literary thought. Readers seeking to explore further are encouraged to begin with the primary sources referenced throughout — for there is no substitute for encountering a great mind directly.',
  ];

  @override
  Widget build(BuildContext context) {
    final content = _contents[pageIndex % _contents.length];
    final isChapter = content.startsWith('Chapter') ||
        content.startsWith('Epilogue') ||
        content.startsWith('Bibliography');

    return Container(
      color: bgColor,
      child: Stack(
        children: [
          // Bookmark colour accent at top if bookmarked
          if (bookmark != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(bookmark!.color.argb),
                      Color(bookmark!.color.argb).withValues(alpha: 0.3),
                    ],
                  ),
                ),
              ),
            ),
          // Page content
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isChapter) ...[
                  const SizedBox(height: 40),
                  Container(
                    width: 36,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  content,
                  style: TextStyle(
                    color: fgColor,
                    fontSize: fontSize,
                    height: 1.78,
                    letterSpacing: 0.08,
                    fontWeight: isChapter ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 60),
                // Page number footer
                Center(
                  child: Text(
                    '— ${pageIndex + 1} —',
                    style: TextStyle(
                      color: fgColor.withValues(alpha: 0.25),
                      fontSize: 13,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bookmark note badge
          if (bookmark?.note != null)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(bookmark!.color.argb).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Color(bookmark!.color.argb).withValues(alpha: 0.3),
                      blurRadius: 8,
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bookmark_rounded,
                        size: 12, color: Colors.black54),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        bookmark!.note!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting Widgets
// ─────────────────────────────────────────────────────────────────────────────

// ── TOC ───────────────────────────────────────────────────────────────────────
class _TocEntry {
  final String title;
  final int page;
  const _TocEntry({required this.title, required this.page});
}

class _TocItem extends StatelessWidget {
  final _TocEntry entry;
  final bool isActive;
  final Color fgColor;
  final VoidCallback onTap;

  const _TocItem({
    required this.entry,
    required this.isActive,
    required this.fgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFE53935).withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 3,
              height: isActive ? 24 : 0,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Text(
                entry.title,
                style: TextStyle(
                  color: isActive
                      ? const Color(0xFFE53935)
                      : fgColor.withValues(alpha: 0.72),
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14.5,
                ),
              ),
            ),
            Text(
              '${entry.page}',
              style: TextStyle(
                  color: fgColor.withValues(alpha: 0.3), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bookmark Item ─────────────────────────────────────────────────────────────
class _BookmarkItem extends StatelessWidget {
  final Bookmark bookmark;
  final Color fgColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BookmarkItem({
    required this.bookmark,
    required this.fgColor,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Color(bookmark.color.argb),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(bookmark.color.argb).withValues(alpha: 0.4),
                    blurRadius: 6,
                  )
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Page ${bookmark.page + 1}',
                    style: TextStyle(
                      color: fgColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (bookmark.note != null && bookmark.note!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      bookmark.note!,
                      style: TextStyle(
                          color: fgColor.withValues(alpha: 0.5), fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    '${bookmark.createdAt.day}/${bookmark.createdAt.month}/${bookmark.createdAt.year}',
                    style: TextStyle(
                        color: fgColor.withValues(alpha: 0.28), fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Color(bookmark.color.argb).withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                bookmark.color.label,
                style: TextStyle(
                  color: Color(bookmark.color.argb),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  size: 18, color: fgColor.withValues(alpha: 0.28)),
              onPressed: onDelete,
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}
