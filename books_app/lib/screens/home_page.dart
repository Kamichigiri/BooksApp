import 'package:flutter/material.dart';

/// A premium, beautiful Book representation.
class Book {
  final String title;
  final String author;
  final String coverUrl;
  final double rating;
  final String category;

  const Book({
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.rating,
    required this.category,
  });
}

/// A curated list of beautiful sample books with high-quality cover images.
const List<Book> sampleBooks = [
  Book(
    title: 'The Great Odyssey',
    author: 'Homer & Scholars',
    coverUrl:
        'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?auto=format&fit=crop&q=80&w=400',
    rating: 4.8,
    category: 'Classics',
  ),
  Book(
    title: 'Design Systems',
    author: 'Alla Kholmatova',
    coverUrl:
        'https://images.unsplash.com/photo-1544947950-fa07a98d237f?auto=format&fit=crop&q=80&w=400',
    rating: 4.9,
    category: 'Design',
  ),
  Book(
    title: 'Echoes of the Past',
    author: 'Marcus Aurelius',
    coverUrl:
        'https://images.unsplash.com/photo-1512820790803-83ca734da794?auto=format&fit=crop&q=80&w=400',
    rating: 4.7,
    category: 'Philosophy',
  ),
  Book(
    title: 'Chronicles of Space',
    author: 'Dr. Evelyn Carter',
    coverUrl:
        'https://images.unsplash.com/photo-1610116306796-6fea9f4fae38?auto=format&fit=crop&q=80&w=400',
    rating: 4.5,
    category: 'Sci-Fi',
  ),
  Book(
    title: 'Silent Whispers',
    author: 'Sarah J. Penner',
    coverUrl:
        'https://images.unsplash.com/photo-1618666012174-83b441c0bc76?auto=format&fit=crop&q=80&w=400',
    rating: 4.6,
    category: 'Mystery',
  ),
  Book(
    title: 'The Path of Wisdom',
    author: 'Alan Watts',
    coverUrl:
        'https://images.unsplash.com/photo-1532012197267-da84d127e765?auto=format&fit=crop&q=80&w=400',
    rating: 4.9,
    category: 'Philosophy',
  ),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    // Simulate initial loading to showcase the gorgeous skeleton placeholders
    _simulateLoading();
  }

  void _simulateLoading() {
    setState(() {
      _isLoading = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crimsonSeed = theme.colorScheme.primary;

    // Filter books based on category
    final filteredBooks = _selectedCategory == 'All'
        ? sampleBooks
        : sampleBooks.where((b) => b.category == _selectedCategory).toList();

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
              'Good afternoon,',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w400,
              ),
            ),
            const Text(
              'Elegant Reader',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          // Loading State Toggle Button
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton.filledTonal(
              onPressed: _simulateLoading,
              style: IconButton.styleFrom(
                backgroundColor: crimsonSeed.withOpacity(0.08),
                foregroundColor: crimsonSeed,
              ),
              icon: Icon(
                _isLoading
                    ? Icons.hourglass_top_rounded
                    : Icons.refresh_rounded,
              ),
              tooltip: 'Toggle Skeleton Skeletons',
            ),
          ),
          // Profile Avatar
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: crimsonSeed.withOpacity(0.15),
              child: Text(
                'R',
                style: TextStyle(
                  color: crimsonSeed,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Gorgeous Welcome Banner
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    crimsonSeed,
                    crimsonSeed.withRed((crimsonSeed.red + 40).clamp(0, 255)),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: crimsonSeed.withOpacity(0.3),
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
                        Icons.local_library_rounded,
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
                        child: const Text(
                          'Library Card Active',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Explore your virtual library',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Uncover secrets, learn theories, and expand your consciousness with premium books.',
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

          // Categories Selector
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    'All',
                    'Philosophy',
                    'Design',
                    'Classics',
                    'Sci-Fi',
                    'Mystery'
                  ].map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedCategory = cat;
                            });
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
                        shadowColor: crimsonSeed.withOpacity(0.4),
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isLoading ? 'Discovering Gems...' : 'Recommended for You',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = !_isLoading;
                      });
                    },
                    child: Text(
                      _isLoading ? 'Skip Loading' : 'Show Skeleton',
                      style: TextStyle(color: crimsonSeed),
                    ),
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
                : BookGrid(books: filteredBooks),
          ),

          // Space bottom
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

/// 2 x N Grid for displaying loaded books
class BookGrid extends StatelessWidget {
  final List<Book> books;

  const BookGrid({super.key, required this.books});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            children: [
              Icon(Icons.library_books_rounded,
                  size: 64, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                'No books in this category',
                style: TextStyle(color: Colors.grey[600], fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16.0,
        crossAxisSpacing: 16.0,
        childAspectRatio: 0.62, // Elegant proportion for book covers + texts
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final book = books[index];
          return BookCard(book: book);
        },
        childCount: books.length,
      ),
    );
  }
}

/// Premium Card showcasing individual book cover, category tag, rating, and info
class BookCard extends StatefulWidget {
  final Book book;

  const BookCard({super.key, required this.book});

  @override
  State<BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<BookCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crimsonSeed = theme.colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => _hoverController.forward(),
      onExit: (_) => _hoverController.reverse(),
      child: GestureDetector(
        onTapDown: (_) => _hoverController.forward(),
        onTapUp: (_) => _hoverController.reverse(),
        onTapCancel: () => _hoverController.reverse(),
        onTap: () {
          // Provide interactive feedback
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening details for "${widget.book.title}"...'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              backgroundColor: crimsonSeed,
            ),
          );
        },
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Art with Shadow & Clip
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // High-quality image with fade transition
                        Image.network(
                          widget.book.coverUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const ShimmerPlaceholder();
                          },
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback elegant gradient if image fails to load
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    crimsonSeed.withOpacity(0.4),
                                    crimsonSeed.withOpacity(0.7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.book_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            );
                          },
                        ),
                        // Dark overlay gradient at the bottom for readability if needed
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.1),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        // Category Tag
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.book.category.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        // Rating Chip
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: 14,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  widget.book.rating.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Book Title
              Text(
                widget.book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 3),
              // Author
              Text(
                widget.book.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 2 x N Skeleton Grid representation
class BookGridSkeleton extends StatelessWidget {
  const BookGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16.0,
        crossAxisSpacing: 16.0,
        childAspectRatio: 0.62,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return const BookCardSkeleton();
        },
        childCount: 6, // Show 6 skeleton cards by default
      ),
    );
  }
}

/// A premium look shimmer card placeholder for book cover, title, and author
class BookCardSkeleton extends StatelessWidget {
  const BookCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover Art Skeleton
        Expanded(
          child: ShimmerPlaceholder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        SizedBox(height: 10),
        // Title Skeleton
        ShimmerPlaceholder(
          height: 14,
          width: 110,
        ),
        SizedBox(height: 6),
        // Author Skeleton
        ShimmerPlaceholder(
          height: 11,
          width: 70,
        ),
      ],
    );
  }
}

/// Custom Zero-Dependency Shimmer effect that works flawlessly across themes
class ShimmerPlaceholder extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const ShimmerPlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Premium soft colors for the shimmer sweep
    final baseColor = isDark ? Colors.grey[800]! : const Color(0xFFEBEBF0);
    final highlightColor = isDark ? Colors.grey[700]! : const Color(0xFFF5F5FA);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.5 + 3.0 * _controller.value, -0.2),
              end: Alignment(-0.5 + 3.0 * _controller.value, 0.2),
            ),
          ),
        );
      },
    );
  }
}
