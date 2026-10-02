import 'package:books_app/domain/database/app_database.dart';
import 'package:books_app/domain/models/books.dart';
import 'package:books_app/screens/book_reader_screen.dart';
import 'package:books_app/widgets/book_grid.dart';
import 'package:books_app/widgets/shimmer_placholder.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<Book> _books = [];
  List<Book> _continueReadingBooks = [];
  List<String> _categories = [
    'All',
    'Philosophy',
    'Design',
    'Classics',
    'Sci-Fi',
    'Mystery'
  ];
  int _totalBooksCount = 0;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Fetch all books and metadata from SQLite
  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);

    // Ensure database contains initial default books if empty
    await AppDatabase.instance.seedInitialDataIfEmpty();

    // Query books matching category and search filter
    final books = await AppDatabase.instance.searchBooks(
      query: _searchQuery,
      category: _selectedCategory == 'All' ? null : _selectedCategory,
    );

    // Query distinct categories and in-progress books
    final dbCategories = await AppDatabase.instance.getCategories();
    final continueReading =
        await AppDatabase.instance.getContinueReadingBooks();
    final totalCount = await AppDatabase.instance.getBookCount();

    if (!mounted) return;

    // Merge standard categories with whatever exists in DB
    final mergedCategories = {'All', ...dbCategories}.toList();

    setState(() {
      _books = books;
      _continueReadingBooks = continueReading;
      _categories = mergedCategories;
      _totalBooksCount = totalCount;
      _isLoading = false;
    });
  }

  /// Open book reader and reload database progress upon returning
  Future<void> _openReader(Book book) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            BookReaderScreen(book: book),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );

    // Refresh from SQLite to update current_page and bookmarks
    if (mounted) {
      _loadBooks();
    }
  }

  /// Show dialog to add a new book (via local file or manual input)
  void _showAddBookSheet() {
    final theme = Theme.of(context);
    final crimsonSeed = theme.colorScheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add Book to Library',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Import documents directly into SQLite storage',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            // Option 1: Pick local PDF/EPUB file
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              tileColor: crimsonSeed.withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              leading: CircleAvatar(
                backgroundColor: crimsonSeed.withValues(alpha: 0.15),
                child: Icon(Icons.file_upload_outlined, color: crimsonSeed),
              ),
              title: const Text(
                'Import PDF or EPUB File',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: const Text(
                'Select a document stored on your device',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickAndImportFile();
              },
            ),
            const SizedBox(height: 12),
            // Option 2: Add manually
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              tileColor: Colors.grey[100],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              leading: CircleAvatar(
                backgroundColor: Colors.grey[200],
                child:
                    const Icon(Icons.edit_note_rounded, color: Colors.black87),
              ),
              title: const Text(
                'Add Book Details Manually',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: const Text(
                'Enter title, author, category, and cover image',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(ctx).pop();
                _showManualBookDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Pick a file from storage and insert into SQLite
  Future<void> _pickAndImportFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final path = file.path;
        final rawName = file.name
            .replaceAll(RegExp(r'\.(pdf|epub)$', caseSensitive: false), '')
            .replaceAll('_', ' ');

        final ext = (file.extension ?? 'pdf').toLowerCase();
        final fileType = ext == 'epub' ? BookFileType.epub : BookFileType.pdf;

        final newBook = Book(
          name: rawName,
          filePath: path,
          fileType: fileType,
          category: 'Imported',
          author: 'Local File',
          numberOfPages: 20,
        );

        // final newId =
        await AppDatabase.instance.insertBook(newBook);
        await _loadBooks();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$rawName" added to successfully'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1E1E2E),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import file: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Dialog for manual book creation
  void _showManualBookDialog() {
    final titleCtrl = TextEditingController();
    final authorCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'General');
    final coverCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Book Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Book Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.book_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: authorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Author',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: coverCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cover Image URL (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.image_rounded),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();

              final book = Book(
                name: titleCtrl.text.trim(),
                author: authorCtrl.text.trim().isEmpty
                    ? 'Unknown Author'
                    : authorCtrl.text.trim(),
                category: categoryCtrl.text.trim().isEmpty
                    ? 'General'
                    : categoryCtrl.text.trim(),
                coverUrl: coverCtrl.text.trim().isNotEmpty
                    ? coverCtrl.text.trim()
                    : null,
                numberOfPages: 20,
              );

              final newId = await AppDatabase.instance.insertBook(book);
              await _loadBooks();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('"${book.name}" stored successfully (#$newId)'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Delete book from SQLite
  Future<void> _deleteBook(Book book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Book'),
        content: Text(
          'Are you sure you want to remove "${book.name}" and its bookmarks from your records?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && book.id != null) {
      await AppDatabase.instance.deleteBook(book.id!);
      await _loadBooks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${book.title}" removed successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crimsonSeed = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SQLite Powered Library',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const Text(
              'Bookshelf',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          // Refresh / Reload from SQLite
          IconButton.filledTonal(
            onPressed: _loadBooks,
            style: IconButton.styleFrom(
              backgroundColor: crimsonSeed.withValues(alpha: 0.08),
              foregroundColor: crimsonSeed,
            ),
            icon: Icon(
              _isLoading ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
            ),
            tooltip: 'Reload SQLite Data',
          ),
          const SizedBox(width: 8),
          // User avatar
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: crimsonSeed.withValues(alpha: 0.15),
              child: Text(
                '$_totalBooksCount',
                style: TextStyle(
                  color: crimsonSeed,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBookSheet,
        backgroundColor: crimsonSeed,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Book',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Welcome Banner
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    crimsonSeed,
                    crimsonSeed.withValues(
                      red:
                          ((crimsonSeed.r * 255.0).round() + 40).clamp(0, 255) /
                              255.0,
                    ),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: crimsonSeed.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(
                        Icons.storage_rounded,
                        color: Colors.white70,
                        size: 28,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_totalBooksCount Books Stored',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Explore your SQLite Library',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Structured data keeping with real-time reading progress and bookmarks persistence.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Bar for structured retrieval
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    _loadBooks();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by title, author, or genre...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    prefixIcon:
                        Icon(Icons.search_rounded, color: Colors.grey[500]),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _loadBooks();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Continue Reading Shelf (if user has books in progress)
          if (_continueReadingBooks.isNotEmpty && _searchQuery.isEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  children: [
                    Icon(Icons.auto_stories_rounded,
                        color: crimsonSeed, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Continue Reading',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 136,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _continueReadingBooks.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final book = _continueReadingBooks[index];
                    return _ContinueReadingCard(
                      book: book,
                      onTap: () => _openReader(book),
                    );
                  },
                ),
              ),
            ),
          ],

          // Categories Horizontal Selector
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCategory = cat);
                            _loadBooks();
                          }
                        },
                        selectedColor: crimsonSeed,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isSelected
                              ? Colors.transparent
                              : Colors.grey[200]!,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: isSelected ? 4 : 0,
                        shadowColor: crimsonSeed.withValues(alpha: 0.4),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Grid Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isLoading
                        ? 'Loading Library...'
                        : _searchQuery.isNotEmpty
                            ? 'Search Results (${_books.length})'
                            : _selectedCategory == 'All'
                                ? 'All Books (${_books.length})'
                                : '$_selectedCategory (${_books.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _loadBooks();
                      },
                      child: const Text('Clear Search'),
                    ),
                ],
              ),
            ),
          ),

          // 2 x N Grid of Books / Skeletons
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: _isLoading
                ? const BookGridSkeleton()
                : BookGrid(
                    books: _books,
                    onOpen: _openReader,
                    onDelete: _deleteBook,
                  ),
          ),

          // Space bottom for FAB
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

/// Continue Reading Horizontal Card
class _ContinueReadingCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const _ContinueReadingCard({
    required this.book,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crimsonSeed = theme.colorScheme.primary;
    final progress = book.progressPercentage;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Mini Cover
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 60,
                height: 90,
                child: _buildCoverImage(book, crimsonSeed),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress > 0 ? progress : 0.05,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(crimsonSeed),
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    book.numberOfPages > 0
                        ? 'Page ${book.currentPage + 1} of ${book.numberOfPages}'
                        : 'Page ${book.currentPage + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Safe cover image renderer that supports network URLs and gradient fallbacks
Widget _buildCoverImage(Book book, Color primaryColor) {
  final url = book.coverUrl;
  if (url != null && url.trim().isNotEmpty && url.startsWith('http')) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const ShimmerPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) =>
          _buildCoverFallback(book, primaryColor),
    );
  }
  return _buildCoverFallback(book, primaryColor);
}

Widget _buildCoverFallback(Book book, Color primaryColor) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          primaryColor.withValues(alpha: 0.7),
          primaryColor.withValues(alpha: 0.95),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.book_rounded, color: Colors.white, size: 36),
        const SizedBox(height: 8),
        Text(
          book.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}
