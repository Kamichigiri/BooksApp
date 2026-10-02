import 'package:books_app/domain/models/books.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppDatabase — singleton SQLite wrapper
// Tables: books · bookmarks · chapters
// ─────────────────────────────────────────────────────────────────────────────

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static Database? _db;

  /// Curated default library seeded when database is first created or empty
  static const List<Book> initialBooks = [
    Book(
      name: 'The Great Odyssey',
      author: 'Homer & Scholars',
      coverUrl:
          'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?auto=format&fit=crop&q=80&w=400',
      rating: 4.8,
      category: 'Classics',
      numberOfPages: 20,
    ),
    Book(
      name: 'Design Systems',
      author: 'Alla Kholmatova',
      coverUrl:
          'https://images.unsplash.com/photo-1544947950-fa07a98d237f?auto=format&fit=crop&q=80&w=400',
      rating: 4.9,
      category: 'Design',
      numberOfPages: 20,
    ),
    Book(
      name: 'Echoes of the Past',
      author: 'Marcus Aurelius',
      coverUrl:
          'https://images.unsplash.com/photo-1512820790803-83ca734da794?auto=format&fit=crop&q=80&w=400',
      rating: 4.7,
      category: 'Philosophy',
      numberOfPages: 20,
    ),
    Book(
      name: 'Chronicles of Space',
      author: 'Dr. Evelyn Carter',
      coverUrl:
          'https://images.unsplash.com/photo-1610116306796-6fea9f4fae38?auto=format&fit=crop&q=80&w=400',
      rating: 4.5,
      category: 'Sci-Fi',
      numberOfPages: 20,
    ),
    Book(
      name: 'Silent Whispers',
      author: 'Sarah J. Penner',
      coverUrl:
          'https://images.unsplash.com/photo-1618666012174-83b441c0bc76?auto=format&fit=crop&q=80&w=400',
      rating: 4.6,
      category: 'Mystery',
      numberOfPages: 20,
    ),
    Book(
      name: 'The Path of Wisdom',
      author: 'Alan Watts',
      coverUrl:
          'https://images.unsplash.com/photo-1532012197267-da84d127e765?auto=format&fit=crop&q=80&w=400',
      rating: 4.9,
      category: 'Philosophy',
      numberOfPages: 20,
    ),
  ];

  /// Sample chapters for default books
  static const List<Map<String, dynamic>> _sampleChapters = [
    {'title': 'Introduction', 'page': 1},
    {'title': 'Chapter 1 — Origins', 'page': 3},
    {'title': 'Chapter 2 — The Turning Point', 'page': 7},
    {'title': 'Chapter 3 — Into the Unknown', 'page': 11},
    {'title': 'Chapter 4 — Resolution', 'page': 15},
    {'title': 'Epilogue', 'page': 18},
    {'title': 'Bibliography', 'page': 20},
  ];

  Future<Database> get database async {
    _db ??= await _openDatabase();
    return _db!;
  }

  // ── Open / migrate ──────────────────────────────────────────────────────────

  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = join(dbPath, 'books_app.db');

    return openDatabase(
      fullPath,
      version: 2,
      onConfigure: (db) async {
        // Enforce SQLite foreign key constraints (cascading deletes)
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ── books table ───────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE books (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        name            TEXT    NOT NULL,
        file_path       TEXT,
        url             TEXT,
        file_type       TEXT    NOT NULL DEFAULT 'pdf',
        current_page    INTEGER NOT NULL DEFAULT 0,
        number_of_pages INTEGER NOT NULL DEFAULT 0,
        category        TEXT    NOT NULL DEFAULT '',
        cover_url       TEXT,
        author          TEXT    NOT NULL DEFAULT '',
        rating          REAL    NOT NULL DEFAULT 0.0
      )
    ''');

    // ── bookmarks table ────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE bookmarks (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id     INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
        text        TEXT    NOT NULL DEFAULT '',
        chapter     TEXT    NOT NULL DEFAULT '',
        text_color  INTEGER NOT NULL DEFAULT 0,
        page        INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT    NOT NULL
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_bookmarks_book_id ON bookmarks(book_id)');

    // ── chapters table ─────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE chapters (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id       INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
        title         TEXT    NOT NULL,
        page_number   INTEGER NOT NULL DEFAULT 1,
        chapter_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_chapters_book_id ON chapters(book_id)');

    // Seed default sample books and chapters
    await _seedDefaultBooks(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS chapters (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          book_id       INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
          title         TEXT    NOT NULL,
          page_number   INTEGER NOT NULL DEFAULT 1,
          chapter_order INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_chapters_book_id ON chapters(book_id)');

      // Seed chapters for existing sample books if any
      final books = await db.query('books');
      for (final row in books) {
        final bookId = row['id'] as int;
        final existingCount = Sqflite.firstIntValue(await db.rawQuery(
              'SELECT COUNT(*) FROM chapters WHERE book_id = ?',
              [bookId],
            )) ??
            0;
        if (existingCount == 0) {
          final batch = db.batch();
          for (int i = 0; i < _sampleChapters.length; i++) {
            final ch = _sampleChapters[i];
            batch.insert('chapters', {
              'book_id': bookId,
              'title': ch['title'],
              'page_number': ch['page'],
              'chapter_order': i,
            });
          }
          await batch.commit(noResult: true);
        }
      }
    }
  }

  /// Populate default books and their chapters
  Future<void> _seedDefaultBooks(DatabaseExecutor db) async {
    for (final book in initialBooks) {
      final bookId = await db.insert('books', book.toMap());
      final batch = db.batch();
      for (int i = 0; i < _sampleChapters.length; i++) {
        final ch = _sampleChapters[i];
        batch.insert('chapters', {
          'book_id': bookId,
          'title': ch['title'],
          'page_number': ch['page'],
          'chapter_order': i,
        });
      }
      await batch.commit(noResult: true);
    }
  }

  /// Ensure initial books and chapters exist if the table was emptied or created previously
  Future<void> seedInitialDataIfEmpty() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM books'),
    ) ?? 0;
    if (count == 0) {
      await _seedDefaultBooks(db);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Book CRUD & Queries
  // ─────────────────────────────────────────────────────────────────────────────

  /// Insert a new book. Returns the new row's [id].
  Future<int> insertBook(Book book) async {
    final db = await database;
    return db.insert('books', book.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Update every column of an existing book (requires [book.id] to be set).
  Future<void> updateBook(Book book) async {
    assert(book.id != null, 'Cannot update a Book with no id');
    final db = await database;
    await db.update(
      'books',
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  /// Convenience: just update the reading position for a book.
  Future<void> updateBookProgress({
    required int bookId,
    required int currentPage,
    int? numberOfPages,
  }) async {
    final db = await database;
    await db.update(
      'books',
      {
        'current_page': currentPage,
        if (numberOfPages != null) 'number_of_pages': numberOfPages,
      },
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  /// Delete a book and all its bookmarks and chapters (CASCADE handled by SQLite).
  Future<void> deleteBook(int id) async {
    final db = await database;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  /// Fetch a single book by [id]. Returns null if not found.
  Future<Book?> getBook(int id) async {
    final db = await database;
    final rows = await db.query('books', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Book.fromMap(rows.first);
  }

  /// Fetch all books, optionally filtered by [category].
  Future<List<Book>> getAllBooks({String? category}) async {
    final db = await database;
    final rows = (category == null || category == 'All')
        ? await db.query('books', orderBy: 'name ASC')
        : await db.query(
            'books',
            where: 'category = ?',
            whereArgs: [category],
            orderBy: 'name ASC',
          );
    return rows.map(Book.fromMap).toList();
  }

  /// Structured search across title/name and author with optional category filter.
  Future<List<Book>> searchBooks({String? query, String? category}) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (category != null && category.isNotEmpty && category != 'All') {
      conditions.add('category = ?');
      args.add(category);
    }

    if (query != null && query.trim().isNotEmpty) {
      conditions.add('(name LIKE ? OR author LIKE ?)');
      final pattern = '%${query.trim()}%';
      args.add(pattern);
      args.add(pattern);
    }

    final whereClause = conditions.isNotEmpty ? conditions.join(' AND ') : null;
    final rows = await db.query(
      'books',
      where: whereClause,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'name ASC',
    );
    return rows.map(Book.fromMap).toList();
  }

  /// Returns all distinct categories from existing books
  Future<List<String>> getCategories() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT category FROM books WHERE category IS NOT NULL AND category != "" ORDER BY category ASC',
    );
    return rows.map((r) => r['category'] as String).toList();
  }

  /// Returns books that have reading progress (current_page > 0), ordered by progress
  Future<List<Book>> getContinueReadingBooks({int limit = 10}) async {
    final db = await database;
    final rows = await db.query(
      'books',
      where: 'current_page > 0',
      orderBy: 'current_page DESC',
      limit: limit,
    );
    return rows.map(Book.fromMap).toList();
  }

  /// Total count of books in library
  Future<int> getBookCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM books'),
    ) ?? 0;
  }

  /// Count of bookmarks for a specific book
  Future<int> getBookmarkCountForBook(int bookId) async {
    final db = await database;
    return Sqflite.firstIntValue(
      await db.rawQuery(
          'SELECT COUNT(*) FROM bookmarks WHERE book_id = ?', [bookId]),
    ) ?? 0;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Chapter CRUD
  // ─────────────────────────────────────────────────────────────────────────────

  /// Insert a single chapter. Returns the new row's [id].
  Future<int> insertChapter(Chapter chapter) async {
    final db = await database;
    return db.insert('chapters', chapter.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Batch insert chapters for a book
  Future<void> insertChapters(List<Chapter> chapters) async {
    if (chapters.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final chapter in chapters) {
      batch.insert('chapters', chapter.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Retrieve all chapters for a book, ordered by chapter_order
  Future<List<Chapter>> getChaptersForBook(int bookId) async {
    final db = await database;
    final rows = await db.query(
      'chapters',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'chapter_order ASC, page_number ASC',
    );
    return rows.map(Chapter.fromMap).toList();
  }

  /// Delete all chapters for a book
  Future<void> deleteChaptersForBook(int bookId) async {
    final db = await database;
    await db.delete('chapters', where: 'book_id = ?', whereArgs: [bookId]);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Bookmark CRUD
  // ─────────────────────────────────────────────────────────────────────────────

  /// Insert a new bookmark. Returns the new row's [id].
  Future<int> insertBookmark(Bookmark bookmark) async {
    final db = await database;
    return db.insert('bookmarks', bookmark.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Update an existing bookmark (requires [bookmark.id]).
  Future<void> updateBookmark(Bookmark bookmark) async {
    assert(bookmark.id != null, 'Cannot update a Bookmark with no id');
    final db = await database;
    await db.update(
      'bookmarks',
      bookmark.toMap(),
      where: 'id = ?',
      whereArgs: [bookmark.id],
    );
  }

  /// Delete a single bookmark by its [id].
  Future<void> deleteBookmark(int id) async {
    final db = await database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  /// Fetch all bookmarks for a given [bookId], ordered by page number.
  Future<List<Bookmark>> getBookmarksForBook(int bookId) async {
    final db = await database;
    final rows = await db.query(
      'bookmarks',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'page ASC',
    );
    return rows.map(Bookmark.fromMap).toList();
  }

  /// Fetch bookmarks for a specific [page] within a book.
  Future<List<Bookmark>> getBookmarksOnPage(
      {required int bookId, required int page}) async {
    final db = await database;
    final rows = await db.query(
      'bookmarks',
      where: 'book_id = ? AND page = ?',
      whereArgs: [bookId, page],
    );
    return rows.map(Bookmark.fromMap).toList();
  }

  /// Delete all bookmarks belonging to a book.
  Future<void> deleteAllBookmarksForBook(int bookId) async {
    final db = await database;
    await db.delete('bookmarks', where: 'book_id = ?', whereArgs: [bookId]);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) {
      await db.close();
      _db = null;
    }
  }
}
