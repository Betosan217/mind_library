import 'package:flutter/material.dart';
import 'package:mind_library/models/book_model.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/folder_model.dart';
import '../../providers/book_provider.dart';
import '../../providers/folder_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/library/add_book_widget.dart';
import '../../widgets/library/create_folder_widget.dart';
import '../../widgets/library/folder_item.dart';
import '../../widgets/home/multi_action_fab.dart';
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
  final Set<String> _selectedFolderIds = {};

  // 🆕 NUEVO: Control de inicialización de streams
  bool _streamsInitialized = false;

  // Controlador de animación para FAB
  late AnimationController _fabAnimationController;
  late Animation<Offset> _fabSlideAnimation;

  @override
  void initState() {
    super.initState();

    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fabSlideAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(1.5, 0)).animate(
          CurvedAnimation(
            parent: _fabAnimationController,
            curve: Curves.easeInOut,
          ),
        );

    _fabAnimationController.value = 0.0;

    // 🔥 SOLUCIÓN CLAVE: Inicializar streams en initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_streamsInitialized && mounted) {
        _initializeStreams();
      }
    });
  }

  // 🆕 NUEVO: Método dedicado para inicializar streams
  void _initializeStreams() {
    debugPrint(
      '🚀 Inicializando streams para: ${widget.folder.name} (${widget.folder.id})',
    );

    final bookProvider = context.read<BookProvider>();
    final folderProvider = context.read<FolderProvider>();

    // Inicializar streams
    bookProvider.initFolderBooksStream(widget.folder.id);
    folderProvider.initSubFoldersStream(widget.folder.id);

    setState(() {
      _streamsInitialized = true;
    });

    debugPrint('✅ Streams inicializados correctamente');
  }

  @override
  void dispose() {
    debugPrint('🗑️ Limpiando FolderDetailScreen: ${widget.folder.name}');

    _fabAnimationController.dispose();

    // 🔥 SOLUCIÓN CLAVE: Limpiar streams específicos de esta pantalla
    if (_streamsInitialized) {
      final folderProvider = context.read<FolderProvider>();
      folderProvider.stopSubFoldersStream(widget.folder.id);

      // El BookProvider no necesita limpieza porque su lista se actualiza automáticamente
    }

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
        SnackBar(
          content: const Text('Libro agregado exitosamente'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _showCreateSubFolderDialog() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CreateFolderWidget(parentFolderId: widget.folder.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer2<BookProvider, FolderProvider>(
      builder: (context, bookProvider, folderProvider, child) {
        // 🆕 NUEVO: Obtener subcarpetas Y libros específicos de esta carpeta
        final subFolders = folderProvider.getSubFolders(widget.folder.id);
        final books = bookProvider.getBooksForFolder(widget.folder.id);

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
            backgroundColor: isDark
                ? theme.scaffoldBackgroundColor
                : Colors.white,
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(context, bookProvider, isDark),
                  const SizedBox(height: 16),
                  _buildActionsBar(context, isDark, subFolders, books),
                  const SizedBox(height: 16),
                  _buildFolderVisual(isDark),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      _isSelectionMode
                          ? '${_selectedBookIds.length + _selectedFolderIds.length} seleccionado(s)'
                          : widget.folder.name,
                      style: theme.textTheme.displayMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!_isSelectionMode) _buildBreadcrumb(context),
                  const SizedBox(height: 8),
                  Text(
                    '${subFolders.length} ${subFolders.length == 1 ? 'carpeta' : 'carpetas'}, ${books.length} ${books.length == 1 ? 'libro' : 'libros'}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(child: _buildContent(subFolders, books, isDark)),
                ],
              ),
            ),
            floatingActionButton: SlideTransition(
              position: _fabSlideAnimation,
              child: MultiActionFab(
                onCreateFolder: _showCreateSubFolderDialog,
                onAddBook: _showAddBookPanel,
              ),
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
                  ? _buildSelectionBottomBar(isDark)
                  : const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    List<FolderModel> subFolders,
    List<BookModel> books,
    bool isDark,
  ) {
    final hasSubFolders = subFolders.isNotEmpty;
    final hasBooks = books.isNotEmpty;

    if (!hasSubFolders && !hasBooks) {
      return _buildEmptyState(context);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasSubFolders) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/folder_icon.svg',
                    width: 16,
                    height: 16,
                    colorFilter: ColorFilter.mode(
                      isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Carpetas',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: widget.folder.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${subFolders.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.folder.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.44,
              ),
              itemCount: subFolders.length,
              itemBuilder: (context, index) {
                final folder = subFolders[index];
                final isSelected = _selectedFolderIds.contains(folder.id);

                return GestureDetector(
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleFolderSelection(folder.id);
                    } else {
                      _navigateToSubFolder(folder);
                    }
                  },
                  onLongPress: () {
                    if (!_isSelectionMode) {
                      setState(() {
                        _isSelectionMode = true;
                        _selectedFolderIds.add(folder.id);
                      });
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: _isSelectionMode && isSelected
                          ? Border.all(
                              color: AppColors.error.withValues(alpha: 0.3),
                              width: 2,
                            )
                          : null,
                    ),
                    child: Stack(
                      children: [
                        FolderItem(folder: folder, enableNavigation: false),
                        if (_isSelectionMode)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.error.withValues(alpha: 0.05)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: _buildSelectionCircle(
                                    isSelected: isSelected,
                                    isDark: isDark,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (hasBooks) ...[
              const SizedBox(height: 32),
              Divider(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                thickness: 1,
                height: 1,
              ),
              const SizedBox(height: 24),
            ] else ...[
              const SizedBox(height: 24),
            ],
          ],
          if (hasBooks) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/book.svg',
                    width: 16,
                    height: 16,
                    colorFilter: ColorFilter.mode(
                      isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Libros',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: widget.folder.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${books.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.folder.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
                childAspectRatio: 0.70,
              ),
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                final isSelected = _selectedBookIds.contains(book.id);
                return _buildModernBookCard(book, isSelected, isDark);
              },
            ),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _navigateToSubFolder(FolderModel folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FolderDetailScreen(folder: folder),
      ),
    );
  }

  void _toggleFolderSelection(String folderId) {
    setState(() {
      if (_selectedFolderIds.contains(folderId)) {
        _selectedFolderIds.remove(folderId);
        if (_selectedFolderIds.isEmpty && _selectedBookIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedFolderIds.add(folderId);
      }
    });
  }

  Widget _buildHeader(
    BuildContext context,
    BookProvider bookProvider,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: SvgPicture.asset(
              'assets/icons/arrow_back.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                Theme.of(context).colorScheme.onSurface,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsBar(
    BuildContext context,
    bool isDark,
    List<FolderModel> subFolders,
    List<BookModel> books,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).scaffoldBackgroundColor
            : Colors.white,
      ),
      child: Row(
        children: [
          if (_isSelectionMode) ...[
            SizedBox(
              width: 50,
              child: GestureDetector(
                onTap: _toggleSelectAll,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSelectionCircle(
                      isSelected: _isAllSelected(subFolders, books),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Todas',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFolderVisual(bool isDark) {
    return Center(
      child: _StackedFolderCard(folder: widget.folder, isDark: isDark),
    );
  }

  Widget _buildBreadcrumb(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: SvgPicture.asset(
              'assets/icons/folder_icon.svg',
              width: 12,
              height: 12,
              colorFilter: ColorFilter.mode(
                isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                BlendMode.srcIn,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SvgPicture.asset(
              'assets/icons/arrow_forward.svg',
              width: 12,
              height: 12,
              colorFilter: ColorFilter.mode(
                isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                BlendMode.srcIn,
              ),
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

  Widget _buildModernBookCard(book, bool isSelected, bool isDark) {
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
            _StackedBookCard(folder: widget.folder, book: book, isDark: isDark),
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
                      child: _buildSelectionCircle(
                        isSelected: isSelected,
                        isDark: isDark,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCircle({
    required bool isSelected,
    required bool isDark,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.error
            : (isDark ? Theme.of(context).colorScheme.surface : Colors.white),
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected
              ? AppColors.error
              : (Theme.of(context).dividerTheme.color ?? Colors.grey),
          width: 2,
        ),
      ),
      child: isSelected
          ? Icon(Icons.check_rounded, color: Colors.white, size: 24 * 0.6)
          : null,
    );
  }

  Widget _buildSelectionBottomBar(bool isDark) {
    final canRenameBook =
        _selectedBookIds.length == 1 && _selectedFolderIds.isEmpty;
    final canRenameFolder =
        _selectedFolderIds.length == 1 && _selectedBookIds.isEmpty;

    return Container(
      key: const ValueKey('selection_bottom_bar'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).scaffoldBackgroundColor
            : Colors.white,
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomBarButton(
              icon: SvgPicture.asset(
                'assets/icons/close.svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
              label: 'Cancelar',
              onTap: _exitSelectionMode,
              isDark: isDark,
            ),
            _buildBottomBarButton(
              icon: SvgPicture.asset(
                'assets/icons/rename_name.svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
              label: 'Renombrar',
              onTap: (canRenameBook || canRenameFolder)
                  ? _showRenameDialog
                  : null,
              isEnabled: canRenameBook || canRenameFolder,
              isDark: isDark,
            ),
            _buildBottomBarButton(
              icon: SvgPicture.asset(
                'assets/icons/delete.svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
              label: 'Eliminar',
              onTap: _showDeleteDialog,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBarButton({
    required Widget icon,
    required String label,
    required VoidCallback? onTap,
    required bool isDark,
    bool isEnabled = true,
  }) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w500,
      color: isEnabled
          ? null
          : (isDark ? AppColors.textHintDark : AppColors.textHintLight),
    );

    return _HoverButton(
      onTap: isEnabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 4),
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }

  void _toggleBookSelection(String bookId) {
    setState(() {
      if (_selectedBookIds.contains(bookId)) {
        _selectedBookIds.remove(bookId);
        if (_selectedBookIds.isEmpty && _selectedFolderIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedBookIds.add(bookId);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      final folderProvider = context.read<FolderProvider>();
      final bookProvider = context.read<BookProvider>();
      final subFolders = folderProvider.getSubFolders(widget.folder.id);

      if (_isAllSelected(subFolders, bookProvider.books)) {
        _selectedBookIds.clear();
        _selectedFolderIds.clear();
      } else {
        _selectedBookIds.clear();
        _selectedFolderIds.clear();
        _selectedBookIds.addAll(bookProvider.books.map((b) => b.id));
        _selectedFolderIds.addAll(subFolders.map((f) => f.id));
      }
    });
  }

  bool _isAllSelected(List<FolderModel> subFolders, List<BookModel> books) {
    final totalItems = subFolders.length + books.length;
    final selectedItems = _selectedFolderIds.length + _selectedBookIds.length;
    return selectedItems == totalItems && totalItems > 0;
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedBookIds.clear();
      _selectedFolderIds.clear();
    });
  }

  void _showRenameDialog() {
    if (_selectedBookIds.length == 1 && _selectedFolderIds.isEmpty) {
      _showRenameBookDialog();
    } else if (_selectedFolderIds.length == 1 && _selectedBookIds.isEmpty) {
      _showRenameFolderDialog();
    }
  }

  void _showRenameBookDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
            color: isDark ? theme.colorScheme.surface : Colors.white,
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
                      color: theme.dividerTheme.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Renombrar Libro',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.scaffoldBackgroundColor
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(14),
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
                  child: TextFormField(
                    controller: titleController,
                    autofocus: true,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Título del libro',
                      hintStyle: theme.inputDecorationTheme.hintStyle?.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SvgPicture.asset(
                          'assets/icons/book.svg',
                          width: 20,
                          height: 20,
                          colorFilter: ColorFilter.mode(
                            theme.textTheme.bodyMedium?.color ?? Colors.grey,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? theme.scaffoldBackgroundColor
                          : const Color(0xFFF5F5F5),
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
                          color: isDark
                              ? theme.colorScheme.surfaceContainerHighest
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: theme.dividerTheme.color ?? Colors.grey,
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
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
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
                                final updatedBook = book.copyWith(
                                  title: titleController.text.trim(),
                                );
                                final success = await bookProvider.updateBook(
                                  bookId,
                                  updatedBook,
                                );

                                if (!bottomSheetContext.mounted) return;
                                Navigator.pop(bottomSheetContext);

                                if (!mounted) return;
                                if (success) {
                                  _exitSelectionMode();
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

  void _showRenameFolderDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final folderId = _selectedFolderIds.first;
    final folderProvider = context.read<FolderProvider>();
    final folder = folderProvider
        .getSubFolders(widget.folder.id)
        .firstWhere((f) => f.id == folderId);

    final TextEditingController nameController = TextEditingController(
      text: folder.name,
    );
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : Colors.white,
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
                      color: theme.dividerTheme.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Renombrar Carpeta',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.scaffoldBackgroundColor
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(14),
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
                  child: TextFormField(
                    controller: nameController,
                    autofocus: true,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Nombre de la carpeta',
                      hintStyle: theme.inputDecorationTheme.hintStyle?.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SvgPicture.asset(
                          'assets/icons/folder_icon.svg',
                          width: 20,
                          height: 20,
                          colorFilter: ColorFilter.mode(
                            theme.textTheme.bodyMedium?.color ?? Colors.grey,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? theme.scaffoldBackgroundColor
                          : const Color(0xFFF5F5F5),
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
                        return 'Por favor ingresa un nombre';
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
                          color: isDark
                              ? theme.colorScheme.surfaceContainerHighest
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: theme.dividerTheme.color ?? Colors.grey,
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
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
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
                              folder.color,
                              folder.color.withValues(alpha: 0.85),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: folder.color.withValues(alpha: 0.3),
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
                                final updatedFolder = folder.copyWith(
                                  name: nameController.text.trim(),
                                );
                                final success = await folderProvider
                                    .updateFolder(folderId, updatedFolder);

                                if (!bottomSheetContext.mounted) return;
                                Navigator.pop(bottomSheetContext);

                                if (!mounted) return;
                                if (success) {
                                  _exitSelectionMode();
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
      nameController.dispose();
    });
  }

  void _showDeleteDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bookCount = _selectedBookIds.length;
    final folderCount = _selectedFolderIds.length;

    String message;
    if (bookCount > 0 && folderCount > 0) {
      message =
          '¿Estás seguro de que deseas eliminar $folderCount ${folderCount == 1 ? 'carpeta' : 'carpetas'} y $bookCount ${bookCount == 1 ? 'libro' : 'libros'}?';
    } else if (folderCount > 0) {
      message =
          '¿Estás seguro de que deseas eliminar ${folderCount == 1 ? 'esta carpeta' : 'estas $folderCount carpetas'}?\n\nSe eliminarán todos los libros y subcarpetas dentro de ${folderCount == 1 ? 'ella' : 'ellas'}.';
    } else {
      message =
          '¿Estás seguro de que deseas eliminar ${bookCount == 1 ? 'este libro' : 'estos $bookCount libros'}?';
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Eliminar Elementos',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          content: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Container(
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerTheme.color ?? Colors.grey,
                  width: 1.5,
                ),
              ),
              child: TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Cancelar',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
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
                  await _deleteSelectedItems();
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

  Future<void> _deleteSelectedItems() async {
    if (!mounted) return;

    final bookProvider = context.read<BookProvider>();
    final folderProvider = context.read<FolderProvider>();

    for (final folderId in _selectedFolderIds) {
      await folderProvider.deleteFolder(folderId);
    }

    for (final bookId in _selectedBookIds) {
      await bookProvider.deleteBook(bookId, widget.folder.id);
    }

    _exitSelectionMode();
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

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
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/folder_icon.svg',
                width: 50,
                height: 50,
                colorFilter: ColorFilter.mode(
                  widget.folder.color.withValues(alpha: 0.5),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Carpeta vacía', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Agrega subcarpetas o libros\na esta carpeta',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ========== WIDGETS AUXILIARES ==========

class _HoverButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _HoverButton({required this.child, this.onTap});

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton>
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
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) {
              setState(() => _isPressed = true);
              _controller.forward();
            }
          : null,
      onTapUp: widget.onTap != null
          ? (_) {
              setState(() => _isPressed = false);
              _controller.reverse();
            }
          : null,
      onTapCancel: widget.onTap != null
          ? () {
              setState(() => _isPressed = false);
              _controller.reverse();
            }
          : null,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _isPressed
              ? (isDark
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : const Color(0xFFF5F5F5))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
      ),
    );
  }
}

// ============= DISEÑO APILADO DE CARPETA =============
class _StackedFolderCard extends StatelessWidget {
  final FolderModel folder;
  final bool isDark;

  const _StackedFolderCard({required this.folder, required this.isDark});

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
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.shadowDark
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  Container(
                    width: 24,
                    height: 2,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.grey700 : AppColors.grey300,
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
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
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
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
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

// ============= DISEÑO APILADO DE LIBRO (LATERAL) - MEJORADO =============
class _StackedBookCard extends StatelessWidget {
  final FolderModel folder;
  final BookModel book;
  final bool isDark;

  const _StackedBookCard({
    required this.folder,
    required this.book,
    required this.isDark,
  });

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
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.shadowDark
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Lomo del libro (derecha)
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

          // Portada del libro (izquierda)
          Positioned(
            top: cardPadding + 3,
            bottom: cardPadding + 3,
            right: cardPadding + 8,
            left: cardPadding + 3,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Espacio superior flexible
                    const Spacer(),

                    // Indicador de progreso (si existe)
                    if (book.progress > 0) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: book.progress,
                              backgroundColor: isDark
                                  ? AppColors.grey800
                                  : AppColors.grey100,
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
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Título del libro en la parte inferior
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        book.title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
