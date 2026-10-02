// ─────────────────────────────────────────────────────────────────────────────
// BookFileType
// ─────────────────────────────────────────────────────────────────────────────

/// Supported book file formats
enum BookFileType {
  pdf,
  epub;

  String get name {
    switch (this) {
      case BookFileType.pdf:
        return 'PDF';
      case BookFileType.epub:
        return 'EPUB';
    }
  }

  static BookFileType fromString(String value) {
    return BookFileType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => BookFileType.pdf,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BookmarkColor
// ─────────────────────────────────────────────────────────────────────────────

/// Colour coding available for text highlights / bookmarks
enum BookmarkColor { yellow, red, green, blue, purple }

extension BookmarkColorExt on BookmarkColor {
  /// ARGB integer compatible with Flutter's Color constructor
  int get argb {
    switch (this) {
      case BookmarkColor.yellow:
        return 0xFFFFF176;
      case BookmarkColor.red:
        return 0xFFEF9A9A;
      case BookmarkColor.green:
        return 0xFFA5D6A7;
      case BookmarkColor.blue:
        return 0xFF90CAF9;
      case BookmarkColor.purple:
        return 0xFFCE93D8;
    }
  }

  String get label {
    switch (this) {
      case BookmarkColor.yellow:
        return 'Yellow';
      case BookmarkColor.red:
        return 'Red';
      case BookmarkColor.green:
        return 'Green';
      case BookmarkColor.blue:
        return 'Blue';
      case BookmarkColor.purple:
        return 'Purple';
    }
  }

  static BookmarkColor fromIndex(int index) =>
      BookmarkColor.values[index.clamp(0, BookmarkColor.values.length - 1)];
}

// ─────────────────────────────────────────────────────────────────────────────
// Book
// Fields: id · name · filePath · url · fileType ·
//         currentPage · numberOfPages · category · coverUrl · author · rating
// ─────────────────────────────────────────────────────────────────────────────

class Book {
  /// Unique identifier (auto-assigned by the database; null before first insert)
  final int? id;

  /// Display name / title of the book
  final String name;

  /// Absolute path to the local file on-device (null if remote-only)
  final String? filePath;

  /// Remote URL for network-served books (null if local-only)
  final String? url;

  /// PDF or EPUB
  final BookFileType fileType;

  /// Last page the user was reading (0-indexed)
  final int currentPage;

  /// Total number of pages (0 = unknown / not yet loaded)
  final int numberOfPages;

  /// Genre / shelf category (e.g. "Philosophy", "Sci-Fi")
  final String category;

  // ── Display metadata (shown in library UI) ──────────────────────────────────
  final String? coverUrl;
  final String author;
  final double rating;

  const Book({
    this.id,
    String? name,
    String? title,
    this.filePath,
    this.url,
    this.fileType = BookFileType.pdf,
    this.currentPage = 0,
    this.numberOfPages = 0,
    this.category = 'Any',
    this.coverUrl,
    this.author = '',
    this.rating = 0.0,
  }) : name = name ?? title ?? '';

  /// Alias for [name] for UI and reader convenience
  String get title => name;

  /// Progress percentage between 0.0 and 1.0
  double get progressPercentage =>
      numberOfPages > 0 ? (currentPage / numberOfPages).clamp(0.0, 1.0) : 0.0;

  /// True if reading has begun
  bool get isInProgress => currentPage > 0;

  /// True if the book has reached the last page
  bool get isCompleted =>
      numberOfPages > 0 && currentPage >= numberOfPages - 1;

  // ── SQLite serialisation ────────────────────────────────────────────────────

  /// Converts to a map suitable for sqflite insert/update.
  /// The [id] column is omitted when null so SQLite can auto-increment it.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'file_path': filePath,
      'url': url,
      'file_type': fileType.name.toLowerCase(),
      'current_page': currentPage,
      'number_of_pages': numberOfPages,
      'category': category,
      'cover_url': coverUrl,
      'author': author,
      'rating': rating,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  /// Reconstructs a [Book] from a sqflite row map.
  factory Book.fromMap(Map<String, dynamic> map) => Book(
        id: map['id'] as int?,
        name: map['name'] as String,
        filePath: map['file_path'] as String?,
        url: map['url'] as String?,
        fileType: BookFileType.fromString(map['file_type'] as String? ?? 'pdf'),
        currentPage: map['current_page'] as int? ?? 0,
        numberOfPages: map['number_of_pages'] as int? ?? 0,
        category: map['category'] as String? ?? '',
        coverUrl: map['cover_url'] as String?,
        author: map['author'] as String? ?? '',
        rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      );

  Book copyWith({
    int? id,
    String? name,
    String? title,
    String? filePath,
    String? url,
    BookFileType? fileType,
    int? currentPage,
    int? numberOfPages,
    String? category,
    String? coverUrl,
    String? author,
    double? rating,
  }) {
    return Book(
      id: id ?? this.id,
      name: name ?? title ?? this.name,
      filePath: filePath ?? this.filePath,
      url: url ?? this.url,
      fileType: fileType ?? this.fileType,
      currentPage: currentPage ?? this.currentPage,
      numberOfPages: numberOfPages ?? this.numberOfPages,
      category: category ?? this.category,
      coverUrl: coverUrl ?? this.coverUrl,
      author: author ?? this.author,
      rating: rating ?? this.rating,
    );
  }

  @override
  String toString() =>
      'Book(id: $id, name: $name, type: ${fileType.name}, page: $currentPage/$numberOfPages)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Bookmark
// Fields: id · bookId · text · chapter · textColor · page · createdAt
// ─────────────────────────────────────────────────────────────────────────────

class Bookmark {
  /// Unique identifier (auto-assigned by database)
  final int? id;

  /// Foreign key — the [Book.id] this bookmark belongs to
  final int bookId;

  /// The highlighted or noted text
  final String text;

  /// Chapter title or number where the bookmark sits
  final String chapter;

  /// Colour used to highlight the text
  final BookmarkColor textColor;

  /// Page number (0-indexed) where the bookmark lives
  final int page;

  final DateTime createdAt;

  const Bookmark({
    this.id,
    required this.bookId,
    String? text,
    String? note,
    this.chapter = '',
    BookmarkColor? textColor,
    BookmarkColor? color,
    required this.page,
    required this.createdAt,
  })  : text = text ?? note ?? '',
        textColor = textColor ?? color ?? BookmarkColor.yellow;

  /// Alias for textColor for UI components
  BookmarkColor get color => textColor;

  /// Alias for text / note for UI components
  String? get note => text.isEmpty ? null : text;

  // ── SQLite serialisation ────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'book_id': bookId,
      'text': text,
      'chapter': chapter,
      'text_color': textColor.index,
      'page': page,
      'created_at': createdAt.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) => Bookmark(
        id: map['id'] as int?,
        bookId: map['book_id'] as int,
        text: map['text'] as String? ?? '',
        chapter: map['chapter'] as String? ?? '',
        textColor: BookmarkColorExt.fromIndex(map['text_color'] as int? ?? 0),
        page: map['page'] as int? ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Bookmark copyWith({
    int? id,
    int? bookId,
    String? text,
    String? note,
    String? chapter,
    BookmarkColor? textColor,
    BookmarkColor? color,
    int? page,
    DateTime? createdAt,
  }) {
    return Bookmark(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      text: text ?? note ?? this.text,
      chapter: chapter ?? this.chapter,
      textColor: textColor ?? color ?? this.textColor,
      page: page ?? this.page,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Bookmark(id: $id, bookId: $bookId, page: $page, color: ${textColor.label})';
}

/// Type alias for backward compatibility with reader widgets
typedef BookBookmark = Bookmark;

// ─────────────────────────────────────────────────────────────────────────────
// Chapter (Table of Contents entry)
// Fields: id · bookId · title · pageNumber · chapterOrder
// ─────────────────────────────────────────────────────────────────────────────

class Chapter {
  final int? id;
  final int bookId;
  final String title;
  final int pageNumber; // 1-indexed page for viewer jump
  final int chapterOrder;

  const Chapter({
    this.id,
    required this.bookId,
    required this.title,
    required this.pageNumber,
    this.chapterOrder = 0,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'book_id': bookId,
      'title': title,
      'page_number': pageNumber,
      'chapter_order': chapterOrder,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Chapter.fromMap(Map<String, dynamic> map) => Chapter(
        id: map['id'] as int?,
        bookId: map['book_id'] as int,
        title: map['title'] as String? ?? 'Untitled Chapter',
        pageNumber: map['page_number'] as int? ?? 1,
        chapterOrder: map['chapter_order'] as int? ?? 0,
      );

  Chapter copyWith({
    int? id,
    int? bookId,
    String? title,
    int? pageNumber,
    int? chapterOrder,
  }) {
    return Chapter(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      title: title ?? this.title,
      pageNumber: pageNumber ?? this.pageNumber,
      chapterOrder: chapterOrder ?? this.chapterOrder,
    );
  }

  @override
  String toString() =>
      'Chapter(id: $id, bookId: $bookId, title: "$title", page: $pageNumber)';
}

