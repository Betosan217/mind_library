import 'package:flutter/material.dart';
import 'package:mind_library/models/book_model.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/folder_model.dart';
import '../../providers/book_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/library/add_book_widget.dart';
import '../reader/pdf_reader_screen.dart';

class FolderDetailScreen extends StatefulWidget {
  final FolderModel folder;

  const FolderDetailScreen({super.key, required this.folder});

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen>
    with SingleTickerProviderStateMixin {
  // Variables para modo selección
  bool _isSelectionMode = false;
  final Set<String> _selectedBookIds = {};

  // Controlador de animación para FAB
  late AnimationController _fabAnimationController;

  @override
  void initState() {
    super.initState();

    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BookProvider>().initFolderBooksStream(widget.folder.id);
      }
    });
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    final bookProvider = context.read<BookProvider>();
    final userId = FirebaseAuth.instance.currentUser?.uid;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (userId != null) {
        bookProvider.initBooksStream(userId);
      }
    });
    super.dispose();
  }

  Future<void> _showAddBookPanel() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddBookWidget(folder: widget.folder),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Libro agregado exitosamente'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookProvider>(
      builder: (context, bookProvider, child) {
        // Animar FAB según modo selección
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isSelectionMode && _fabAnimationController.value == 0.0) {
            _fabAnimationController.forward();
          } else if (!_isSelectionMode &&
              _fabAnimationController.value == 1.0) {
            _fabAnimationController.reverse();
          }
        });

        return PopScope(
          canPop: !_isSelectionMode,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && _isSelectionMode) {
              setState(() {
                _exitSelectionMode();
              });
            }
          },
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(context, bookProvider),
                  const SizedBox(height: 16),
                  _buildFolderVisual(),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      _isSelectionMode
                          ? '${_selectedBookIds.length} seleccionado(s)'
                          : widget.folder.name,
                      style: Theme.of(context).textTheme.displayMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!_isSelectionMode) _buildBreadcrumb(context),
                  const SizedBox(height: 8),
                  Text(
                    '${bookProvider.books.length} ${bookProvider.books.length == 1 ? 'libro' : 'libros'}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: bookProvider.books.isEmpty
                        ? _buildEmptyState(context)
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.65,
                                ),
                            itemCount: bookProvider.books.length,
                            itemBuilder: (context, index) {
                              final book = bookProvider.books[index];
                              final isSelected = _selectedBookIds.contains(
                                book.id,
                              );
                              return _buildModernBookCard(
                                book,
                                isSelected,
                                bookProvider,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            // FAB se oculta completamente en modo selección
            floatingActionButton: _isSelectionMode
                ? null
                : FloatingActionButton.extended(
                    onPressed: _showAddBookPanel,
                    backgroundColor: widget.folder.color,
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: const Text(
                      'Agregar Libro',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
            bottomNavigationBar: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        ),
                      ),
                  child: child,
                );
              },
              child: _isSelectionMode
                  ? _buildSelectionBottomBar()
                  : const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, BookProvider bookProvider) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          // Botón de regresar
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.black87,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderVisual() {
    return Center(child: _StackedFolderCard(folder: widget.folder));
  }

  Widget _buildBreadcrumb(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text(
              'Home',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              widget.folder.name,
              style: TextStyle(
                fontSize: 14,
                color: widget.folder.color,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ========== MODERN BOOK CARD (PORTADA DE LIBRO) ==========
  Widget _buildModernBookCard(book, bool isSelected, BookProvider provider) {
    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleBookSelection(book.id);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfReaderScreen(book: book),
            ),
          );
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedBookIds.add(book.id);
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: _isSelectionMode && isSelected
              ? Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                  width: 2,
                )
              : null,
        ),
        child: Stack(
          children: [
            // Card principal con efecto apilado lateral
            _StackedBookCard(folder: widget.folder, book: book),
            // Overlay de selección
            if (_isSelectionMode)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.error.withValues(alpha: 0.05)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _buildSelectionCircle(isSelected: isSelected),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCircle({required bool isSelected}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.error : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.error : AppColors.grey300,
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
          : null,
    );
  }

  // ========== BOTTOM BAR DE SELECCIÓN ==========
  Widget _buildSelectionBottomBar() {
    final canRename = _selectedBookIds.length == 1;

    return Container(
      key: const ValueKey('selection_bottom_bar'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(color: Colors.white),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomBarButton(
              icon: Icons.close_rounded,
              label: 'Cancelar',
              onTap: _exitSelectionMode,
            ),
            _buildBottomBarButton(
              icon: Icons.edit_outlined,
              label: 'Renombrar',
              onTap: canRename ? _showRenameDialog : null,
              isEnabled: canRename,
            ),
            _buildBottomBarButton(
              icon: Icons.delete_outline_rounded,
              label: 'Eliminar',
              onTap: _showDeleteDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBarButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isEnabled = true,
  }) {
    final color = isEnabled ? AppColors.textSecondary : AppColors.grey300;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isEnabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== FUNCIONES DE SELECCIÓN ==========
  void _toggleBookSelection(String bookId) {
    setState(() {
      if (_selectedBookIds.contains(bookId)) {
        _selectedBookIds.remove(bookId);
        if (_selectedBookIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedBookIds.add(bookId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedBookIds.clear();
    });
  }

  // ========== RENOMBRAR LIBRO ==========
  void _showRenameDialog() {
    if (_selectedBookIds.length != 1) return;

    final bookId = _selectedBookIds.first;
    final bookProvider = context.read<BookProvider>();
    final book = bookProvider.books.firstWhere((b) => b.id == bookId);

    final TextEditingController titleController = TextEditingController(
      text: book.title,
    );
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Renombrar Libro',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: titleController,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Título del libro',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Icon(
                        Icons.book_rounded,
                        color: Colors.grey[500],
                        size: 20,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor ingresa un título';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pop(bottomSheetContext),
                            child: Center(
                              child: Text(
                                'Cancelar',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [
                              widget.folder.color,
                              widget.folder.color.withValues(alpha: 0.85),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.folder.color.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              if (formKey.currentState!.validate()) {
                                final success = await bookProvider.updateBook(
                                  bookId,
                                  {'title': titleController.text.trim()}
                                      as BookModel,
                                );

                                if (!bottomSheetContext.mounted) return;
                                Navigator.pop(bottomSheetContext);

                                if (!mounted) return;

                                if (success) {
                                  _exitSelectionMode();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Libro renombrado'),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Center(
                              child: Text(
                                'Guardar',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      titleController.dispose();
    });
  }

  // ========== ELIMINAR LIBROS ==========
  void _showDeleteDialog() {
    final count = _selectedBookIds.length;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Eliminar Libros',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              letterSpacing: -0.5,
            ),
          ),
          content: Text(
            '¿Estás seguro de que deseas eliminar ${count == 1 ? 'este libro' : 'estos $count libros'}?',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Container(
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
              ),
              child: TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [AppColors.error, Color(0xFFE53935)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _deleteSelectedBooks();
                },
                child: const Text(
                  'Eliminar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSelectedBooks() async {
    if (!mounted) return;

    final bookProvider = context.read<BookProvider>();
    final count = _selectedBookIds.length;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo eliminar el libro: usuario no autenticado',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    for (final bookId in _selectedBookIds) {
      await bookProvider.deleteBook(bookId, widget.folder.id, userId);
    }

    _exitSelectionMode();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count == 1 ? 'Libro eliminado' : 'Libros eliminados'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: widget.folder.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.book_outlined,
              size: 50,
              color: widget.folder.color.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No hay libros aún',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega tu primer libro\na esta carpeta',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ============= DISEÑO APILADO DE CARPETA =============
class _StackedFolderCard extends StatelessWidget {
  final FolderModel folder;

  const _StackedFolderCard({required this.folder});

  @override
  Widget build(BuildContext context) {
    const double containerWidth = 130;
    const double containerHeight = 90;
    const double cardHeight = 50;
    const double cardPadding = 5.0;

    final lightColors = [
      folder.color.withValues(alpha: 0.3),
      folder.color.withValues(alpha: 0.4),
    ];
    final mediumColors = [
      folder.color.withValues(alpha: 0.6),
      folder.color.withValues(alpha: 0.7),
    ];
    final darkColors = [
      folder.color.withValues(alpha: 0.85),
      folder.color.withValues(alpha: 0.95),
    ];

    return Container(
      width: containerWidth,
      height: containerHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: cardPadding + 0,
            left: cardPadding + 3,
            right: cardPadding + 3,
            child: Container(
              height: cardHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: lightColors,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            top: cardPadding + 4,
            left: cardPadding + 3,
            right: cardPadding + 3,
            child: Container(
              height: cardHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: mediumColors,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            top: cardPadding + 8,
            left: cardPadding + 3,
            right: cardPadding + 3,
            child: Container(
              height: cardHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: darkColors,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            top: cardPadding + 12,
            left: cardPadding + 3,
            right: cardPadding + 3,
            child: Container(
              height: cardHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  Container(
                    width: 24,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            folder.name,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${folder.bookCount} ${folder.bookCount == 1 ? 'libro' : 'libros'}',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[500],
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
        ],
      ),
    );
  }
}

// ============= DISEÑO APILADO DE LIBRO (LATERAL) =============
class _StackedBookCard extends StatelessWidget {
  final FolderModel folder;
  // ignore: prefer_typing_uninitialized_variables
  final book;

  const _StackedBookCard({required this.folder, required this.book});

  @override
  Widget build(BuildContext context) {
    const double cardWidth = 50;
    const double cardPadding = 4.0;

    final darkColors = [
      folder.color.withValues(alpha: 0.85),
      folder.color.withValues(alpha: 0.95),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Tarjeta apilada única (de color)
          Positioned(
            top: cardPadding + 3,
            bottom: cardPadding + 3,
            right: cardPadding + 0,
            child: Container(
              width: cardWidth,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: darkColors,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          // Card principal (blanco, al frente) - sin sombras
          Positioned(
            top: cardPadding + 3,
            bottom: cardPadding + 3,
            right: cardPadding + 8,
            left: cardPadding + 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Portada decorativa del libro (sin icono)
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            folder.color.withValues(alpha: 0.25),
                            folder.color.withValues(alpha: 0.15),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Línea decorativa superior
                          Positioned(
                            top: 8,
                            left: 8,
                            right: 8,
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                color: folder.color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                          // Línea decorativa central
                          Positioned(
                            top: 16,
                            left: 12,
                            right: 12,
                            child: Container(
                              height: 1.5,
                              decoration: BoxDecoration(
                                color: folder.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Info del libro
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            book.title,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              letterSpacing: -0.2,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (book.progress > 0) ...[
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: book.progress,
                                backgroundColor: Colors.grey.shade100,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  folder.color,
                                ),
                                minHeight: 3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${(book.progress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
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
