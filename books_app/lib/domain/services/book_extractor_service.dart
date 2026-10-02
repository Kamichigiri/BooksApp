import 'dart:io';
import 'package:books_app/domain/models/books.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:epubx/epubx.dart';

/// DTO holding extracted metadata and chapters from a document
class ExtractedBookInfo {
  final String title;
  final String author;
  final int numberOfPages;
  final List<Chapter> chapters;

  const ExtractedBookInfo({
    required this.title,
    required this.author,
    required this.numberOfPages,
    required this.chapters,
  });
}

class BookExtractorService {
  BookExtractorService._();

  Future<ExtractedBookInfo> extractEpubData({
    required String filePath,
    required int bookId,
  }) async {
    final bytes = await File(filePath).readAsBytes();

    final EpubBook epubBook = await EpubReader.readBook(bytes);

    final title = _cleanText(epubBook.Title) ?? 'Unknown Title';
    final author = _cleanText(epubBook.Author) ?? 'Unknown Author';

    final epubChapters = epubBook.Chapters ?? [];

    final chapters = <Chapter>[];

    var currentPage = 1;

    for (var i = 0; i < epubChapters.length; i++) {
      final epubChapter = epubChapters[i];

      final chapterTitle = _cleanText(epubChapter.Title) ?? 'Chapter ${i + 1}';

      // The chapter begins on the current page.
      final chapterStartPage = currentPage;

      final chapterText = _extractChapterText(epubChapter);

      final estimatedPages = _estimatePageCount(chapterText);

      chapters.add(
        Chapter(
          id: null,
          bookId: bookId,
          title: chapterTitle,
          pageNumber: chapterStartPage,
          chapterOrder: i + 1,
        ),
      );

      currentPage += estimatedPages;
    }

    return ExtractedBookInfo(
      title: title,
      author: author,
      numberOfPages: currentPage - 1,
      chapters: chapters,
    );
  }

  /// Extract metadata and table of contents from a local document
  static Future<ExtractedBookInfo> extractBookInfo({
    required String filePath,
    required BookFileType fileType,
    int? bookId,
  }) async {
    if (fileType == BookFileType.pdf) {
      return _extractPdfInfo(filePath, bookId: bookId);
    } else {
      return _extractFallbackInfo(filePath, bookId: bookId);
    }
  }

  /// Parse PDF metadata and bookmarks (Table of Contents)
  static Future<ExtractedBookInfo> _extractPdfInfo(
    String filePath, {
    int? bookId,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return _extractFallbackInfo(filePath, bookId: bookId);
    }

    try {
      final bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      // 1. Title & Author extraction
      final info = document.documentInformation;
      final cleanedFallback = _cleanFileName(filePath);

      String title = cleanedFallback;
      if (info.title.trim().isNotEmpty) {
        title = info.title.trim();
      }

      String author = 'Unknown Author';
      if (info.author.trim().isNotEmpty) {
        author = info.author.trim();
      } else {
        // Check if filename contains author hint (e.g., "Author - Title")
        final guessedAuthor = _guessAuthorFromFileName(filePath);
        if (guessedAuthor != null) {
          author = guessedAuthor;
        }
      }

      // 2. Page count
      final int numberOfPages = document.pages.count;

      // 3. Chapters / Bookmarks extraction
      final List<Chapter> chapters = [];
      _extractPdfBookmarks(
        document: document,
        bookmarks: document.bookmarks,
        chapters: chapters,
        bookId: bookId ?? -1,
      );

      document.dispose();

      return ExtractedBookInfo(
        title: title,
        author: author,
        numberOfPages: numberOfPages > 0 ? numberOfPages : 1,
        chapters: chapters,
      );
    } catch (_) {
      // Fallback cleanly if PDF parsing encounters an unstandardized stream
      return _extractFallbackInfo(filePath, bookId: bookId);
    }
  }

  /// Recursively extract chapters from PDF bookmark tree
  static void _extractPdfBookmarks({
    required PdfDocument document,
    required PdfBookmarkBase bookmarks,
    required List<Chapter> chapters,
    required int bookId,
    int depth = 0,
  }) {
    for (int i = 0; i < bookmarks.count; i++) {
      final PdfBookmark bookmark = bookmarks[i];
      final String rawTitle = bookmark.title.trim();

      int pageNumber = 1;
      try {
        final destPage = bookmark.destination!.page;
        final pageIndex = document.pages.indexOf(destPage);
        if (pageIndex >= 0) {
          pageNumber = pageIndex + 1;
        }
      } catch (_) {
        // Bookmark might not have an explicit page destination
      }

      final indent = depth > 0 ? '  ' * depth : '';
      final displayTitle = rawTitle.isNotEmpty
          ? '$indent$rawTitle'
          : 'Chapter ${chapters.length + 1}';

      chapters.add(Chapter(
        bookId: bookId,
        title: displayTitle,
        pageNumber: pageNumber,
        chapterOrder: chapters.length,
      ));

      // Recurse into nested subchapters if any exist
      if (bookmark.count > 0) {
        _extractPdfBookmarks(
          document: document,
          bookmarks: bookmark,
          chapters: chapters,
          bookId: bookId,
          depth: depth + 1,
        );
      }
    }
  }

  /// Fallback heuristic for non-PDF or files lacking metadata
  static ExtractedBookInfo _extractFallbackInfo(
    String filePath, {
    int? bookId,
  }) {
    final title = _cleanFileName(filePath);
    final author = _guessAuthorFromFileName(filePath) ?? 'Unknown Author';

    return ExtractedBookInfo(
      title: title,
      author: author,
      numberOfPages: 20,
      chapters: const [],
    );
  }

  /// Clean file name: "Atomic_Habits.pdf" -> "Atomic Habits"
  static String _cleanFileName(String filePath) {
    final nameWithExt = filePath.split(Platform.pathSeparator).last;
    final nameWithoutExt = nameWithExt
        .replaceAll(RegExp(r'\.(pdf|epub)$', caseSensitive: false), '')
        .replaceAll('_', ' ')
        .trim();

    // If filename is formatted "Author - Title", take Title
    if (nameWithoutExt.contains(' - ')) {
      final parts = nameWithoutExt.split(' - ');
      if (parts.length >= 2 && parts[1].trim().isNotEmpty) {
        return parts[1].trim();
      }
    }

    return nameWithoutExt.isNotEmpty ? nameWithoutExt : 'Untitled Book';
  }

  /// Heuristic to extract author if filename formatted "Author - Title"
  static String? _guessAuthorFromFileName(String filePath) {
    final nameWithExt = filePath.split(Platform.pathSeparator).last;
    final nameWithoutExt = nameWithExt
        .replaceAll(RegExp(r'\.(pdf|epub)$', caseSensitive: false), '')
        .replaceAll('_', ' ')
        .trim();

    if (nameWithoutExt.contains(' - ')) {
      final parts = nameWithoutExt.split(' - ');
      if (parts.isNotEmpty && parts[0].trim().isNotEmpty) {
        return parts[0].trim();
      }
    }
    return null;
  }

  static String? _cleanText(String? value) {
    if (value == null) return null;

    final text = value.trim();

    return text.isEmpty ? null : text;
  }

  static String _extractChapterText(EpubChapter chapter) {
    final buffer = StringBuffer();

    final title = _cleanText(chapter.Title);

    if (title != null) {
      buffer.writeln(title);
      buffer.writeln();
    }

    final html = chapter.HtmlContent;

    if (html != null && html.trim().isNotEmpty) {
      buffer.writeln(_htmlToText(html));
    }

    final subChapters = chapter.SubChapters;

    if (subChapters != null) {
      for (final subChapter in subChapters) {
        buffer.writeln(
          _extractChapterText(subChapter),
        );
      }
    }

    return buffer.toString().trim();
  }

  static String _htmlToText(String html) {
    var text = html;

    text = text.replaceAll(
      RegExp(
        r'<script[\s\S]*?</script>',
        caseSensitive: false,
      ),
      '',
    );

    text = text.replaceAll(
      RegExp(
        r'<style[\s\S]*?</style>',
        caseSensitive: false,
      ),
      '',
    );

    text = text.replaceAll(
      RegExp(
        r'</(p|div|section|article|h1|h2|h3|h4|h5|h6|li|blockquote)>',
        caseSensitive: false,
      ),
      '\n',
    );

    text = text.replaceAll(
      RegExp(
        r'<br\s*/?>',
        caseSensitive: false,
      ),
      '\n',
    );

    text = text.replaceAll(
      RegExp(
        r'<[^>]+>',
        caseSensitive: false,
      ),
      '',
    );

    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    text = text.replaceAll(
      RegExp(r'[ \t]+'),
      ' ',
    );

    text = text.replaceAll(
      RegExp(r'\n\s*\n\s*\n+'),
      '\n\n',
    );

    return text.trim();
  }

  static int _estimatePageCount(String text) {
    if (text.trim().isEmpty) {
      return 1;
    }

    // Temporary estimate.
    //
    // This is NOT the actual Vocsy page count.
    // It simply prevents every chapter from being assigned
    // the same page.
    const charactersPerPage = 1800;

    return (text.length / charactersPerPage).ceil().clamp(1, 999999);
  }
}
