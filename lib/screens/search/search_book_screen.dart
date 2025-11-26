import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../providers/book_provider.dart';
import '../../models/book_model.dart';
import '../../utils/app_colors.dart';
import '../reader/pdf_reader_screen.dart';

class SearchBooksScreen extends StatefulWidget {
  const SearchBooksScreen({super.key});

  @override
  State<SearchBooksScreen> createState() => _SearchBooksScreenState();
}

class _SearchBooksScreenState extends State<SearchBooksScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<BookModel> _searchResults = [];
  bool _isSearching = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    // Auto-focus en el campo de búsqueda
    Future.delayed(const Duration(milliseconds: 100), () {
      _searchFocusNode.requestFocus();
    });

    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    final bookProvider = context.read<BookProvider>();
    final results = await bookProvider.searchBooks(query);

    if (mounted && _searchController.text.trim() == query) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildSearchHeader(isDark),
              Expanded(child: _buildSearchBody(isDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).scaffoldBackgroundColor
            : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Botón de volver
          _BackButton(onTap: () => Navigator.pop(context), isDark: isDark),
          const SizedBox(width: 12),
          // Campo de búsqueda
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? Theme.of(context).colorScheme.surface
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar libros...',
                  hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SvgPicture.asset(
                      'assets/icons/search_status.svg',
                      width: 22,
                      height: 22,
                      colorFilter: ColorFilter.mode(
                        Theme.of(context).textTheme.bodyMedium?.color ??
                            Colors.grey,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            _searchFocusNode.requestFocus();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: SvgPicture.asset(
                              'assets/icons/close.svg',
                              width: 20,
                              height: 20,
                              colorFilter: ColorFilter.mode(
                                Theme.of(context).textTheme.bodyMedium?.color ??
                                    Colors.grey,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
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
        ],
      ),
    );
  }

  Widget _buildSearchBody(bool isDark) {
    if (_searchController.text.isEmpty) {
      return _buildEmptyState(isDark);
    }

    if (_isSearching) {
      return _buildLoadingState();
    }

    if (_searchResults.isEmpty) {
      return _buildNoResultsState(isDark);
    }

    return _buildSearchResults(isDark);
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/icons/search_status.svg',
            width: 64,
            height: 64,
            colorFilter: ColorFilter.mode(
              isDark
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.2),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Busca tus libros',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Escribe el nombre de un libro\npara comenzar la búsqueda',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textHintDark
                    : AppColors.textHintLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text('Buscando...', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/icons/search_status.svg',
            width: 64,
            height: 64,
            colorFilter: ColorFilter.mode(
              isDark
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.2),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Sin resultados',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'No encontramos libros con\n"${_searchController.text}"',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textHintDark
                    : AppColors.textHintLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        indent: 76,
        color: Theme.of(context).dividerTheme.color?.withValues(alpha: 0.3),
      ),
      itemBuilder: (context, index) {
        final book = _searchResults[index];
        return _BookSearchItem(
          book: book,
          isDark: isDark,
          onTap: () => _openBook(book),
        );
      },
    );
  }

  void _openBook(BookModel book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PdfReaderScreen(book: book)),
    );
  }
}

// ========== WIDGET BOTÓN DE VOLVER ==========
class _BackButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isDark;

  const _BackButton({required this.onTap, required this.isDark});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SvgPicture.asset(
          'assets/icons/arrow_left.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(
            Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

// ========== WIDGET ITEM DE BÚSQUEDA ==========
class _BookSearchItem extends StatefulWidget {
  final BookModel book;
  final bool isDark;
  final VoidCallback onTap;

  const _BookSearchItem({
    required this.book,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_BookSearchItem> createState() => _BookSearchItemState();
}

class _BookSearchItemState extends State<_BookSearchItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _isPressed
            ? (widget.isDark
                  ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.5)
                  : const Color(0xFFF5F5F5).withValues(alpha: 0.5))
            : Colors.transparent,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                // Portada del libro
                _buildBookCover(),
                const SizedBox(width: 14),
                // Información del libro
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.book.title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      if (widget.book.progress > 0) ...[_buildProgressBar()],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Icono de navegación
                SvgPicture.asset(
                  'assets/icons/arrow_right.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    widget.isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.4),
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookCover() {
    return Hero(
      tag: 'book-${widget.book.id}',
      child: Container(
        width: 48,
        height: 68,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: widget.isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: widget.book.coverUrl != null
              ? Image.network(
                  widget.book.coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildDefaultCover(),
                )
              : _buildDefaultCover(),
        ),
      ),
    );
  }

  Widget _buildDefaultCover() {
    return Container(
      color: widget.isDark
          ? Theme.of(context).colorScheme.surface
          : const Color(0xFFF5F5F5),
      child: Center(
        child: SvgPicture.asset(
          'assets/icons/book.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(
            widget.isDark
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.3),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: widget.book.progress,
              minHeight: 3,
              backgroundColor: widget.isDark
                  ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.3)
                  : const Color(0xFFE0E0E0),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(widget.book.progress * 100).toInt()}%',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: widget.isDark
                ? AppColors.textHintDark
                : AppColors.textHintLight,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
