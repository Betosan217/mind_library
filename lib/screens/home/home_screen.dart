import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../providers/auth_provider.dart';
import '../../providers/folder_provider.dart';
import '../../models/folder_model.dart';
import '../../widgets/home/compact_clock_widget.dart';
import '../../widgets/library/folder_item.dart';
import '../../widgets/library/create_folder_widget.dart';
import '../../widgets/library/select_folder_widget.dart';
import '../../widgets/library/add_book_widget.dart';
import '../../widgets/common/animated_lottie_avatar.dart';
import '../../widgets/user/user_profile_panel.dart';
import '../../utils/app_colors.dart';
import '../../screens/notes/notes_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Variables para modo selección
  bool _isSelectionMode = false;
  final Set<String> _selectedFolderIds = {};

  // GlobalKey para el botón de 3 puntos
  final GlobalKey _moreButtonKey = GlobalKey();

  // Controlador de animación para FAB
  late AnimationController _fabAnimationController;
  late Animation<Offset> _fabSlideAnimation;

  // Enum para ordenamiento
  FolderSortOption _currentSortOption = FolderSortOption.dateDesc;

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheCoverPhoto();
  }

  // Método para precargar la foto de portada
  void _precacheCoverPhoto() {
    final authProvider = context.read<AuthProvider>();
    final coverPhotoUrl = authProvider.customCoverPhotoUrl;

    if (coverPhotoUrl != null) {
      precacheImage(NetworkImage(coverPhotoUrl), context).catchError((error) {
        debugPrint('Error precargando portada: $error');
      });
    }
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final folderProvider = context.watch<FolderProvider>();
    final totalBooks = _calculateTotalBooks(folderProvider.folders);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isSelectionMode && _fabAnimationController.value == 0.0) {
        _fabAnimationController.forward();
      } else if (!_isSelectionMode && _fabAnimationController.value == 1.0) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMainHeader(context, folderProvider, totalBooks),
              const SizedBox(height: 16),
              _buildActionsBar(context),
              const SizedBox(height: 24),
              Expanded(
                child: folderProvider.folders.isEmpty
                    ? _buildEmptyState(context)
                    : _buildFoldersGrid(
                        _getSortedFolders(folderProvider.folders),
                      ),
              ),
            ],
          ),
        ),
        floatingActionButton: SlideTransition(
          position: _fabSlideAnimation,
          child: _buildModernFAB(),
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
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
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
  }

  Widget _buildModernFAB() {
    return Transform.translate(
      offset: const Offset(28, 0),
      child: Container(
        width: 84,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            bottomLeft: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(-2, 0),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              bottomLeft: Radius.circular(32),
            ),
            onTap: () => _navigateToCreateFolder(),
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/folder_add.svg',
                width: 30,
                height: 30,
                colorFilter: const ColorFilter.mode(
                  Colors.black87,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainHeader(
    BuildContext context,
    FolderProvider provider,
    int totalBooks,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [const CompactClockWidget()],
          ),
          const SizedBox(height: 16),
          Text(
            _isSelectionMode
                ? '${_selectedFolderIds.length} seleccionado(s)'
                : 'Carpetas',
            style: Theme.of(context).textTheme.displayLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${provider.foldersCount} ${provider.foldersCount == 1 ? 'carpeta' : 'carpetas'}, $totalBooks ${totalBooks == 1 ? 'libro' : 'libros'}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Colors.white),
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
                      isSelected: _isAllSelected(),
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Todas',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            GestureDetector(
              onTap: () {
                _showUserPanel();
              },
              child: _buildLargerAvatar(),
            ),
            const Spacer(),
            _buildActionButton(
              svgPath: 'assets/icons/add_file.svg',
              onTap: _showUploadDocumentFlow,
            ),
            const SizedBox(width: 4),
            _buildActionButton(
              svgPath: 'assets/icons/note_icon.svg',
              onTap: _navigateToNotes,
            ),
            const SizedBox(width: 4),
            _buildActionButton(icon: Icons.search_rounded, onTap: () {}),
            const SizedBox(width: 4),
            _buildActionButton(
              key: _moreButtonKey,
              icon: Icons.more_vert_rounded,
              onTap: _showMoreOptionsPopup,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLargerAvatar() {
    final authProvider = context.watch<AuthProvider>();
    final userPhotoUrl =
        authProvider.customProfilePhotoUrl ?? authProvider.user?.photoURL;
    final isUpdating = authProvider.isUpdatingProfile;

    return _PulseButton(
      onTap: isUpdating ? null : _showUserPanel,
      child: Stack(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.grey300, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17.5),
              child: userPhotoUrl != null
                  ? Image.network(
                      userPhotoUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return _buildLottieAvatar();
                      },
                    )
                  : _buildLottieAvatar(),
            ),
          ),
          if (isUpdating)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToNotes() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotesListScreen()),
    );
  }

  Widget _buildLottieAvatar() {
    return AnimatedLottieAvatar(
      assetPath: 'assets/icons/user_ai.json',
      size: 40,
      onTap: _showUserPanel,
      errorWidget: Icon(
        Icons.person_rounded,
        size: 24,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildActionButton({
    Key? key,
    IconData? icon,
    String? svgPath,
    required VoidCallback onTap,
  }) {
    return _HoverButton(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: svgPath != null
            ? SvgPicture.asset(
                svgPath,
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  Colors.black87,
                  BlendMode.srcIn,
                ),
              )
            : Icon(icon, size: 24, color: Colors.black87),
      ),
    );
  }

  Widget _buildFoldersGrid(List<FolderModel> folders) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.44,
      ),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        final isSelected = _selectedFolderIds.contains(folder.id);

        return GestureDetector(
          onTap: () {
            if (_isSelectionMode) {
              _toggleFolderSelection(folder.id);
            } else {
              _navigateToFolderDetail(folder);
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
                FolderItem(folder: folder),
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
                            size: 24,
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
    );
  }

  Widget _buildSelectionCircle({
    required bool isSelected,
    required double size,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.error : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.error : AppColors.grey300,
          width: 2,
        ),
      ),
      child: isSelected
          ? Icon(Icons.check_rounded, color: Colors.white, size: size * 0.6)
          : null,
    );
  }

  Widget _buildSelectionBottomBar() {
    final canRename = _selectedFolderIds.length == 1;

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
              icon: Icons.palette_outlined,
              label: 'Color',
              onTap: _showColorPicker,
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

    return _HoverButton(
      onTap: isEnabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
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
              color: AppColors.grey200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_outlined,
              size: 50,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No tienes carpetas aún',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Toca el botón en el borde para crear\ntu primera carpeta',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ========== POPUP DE 3 PUNTOS (EDITAR Y ORDENAR) - MEJORADO ==========
  void _showMoreOptionsPopup() {
    // Obtener el RenderBox del botón
    final RenderBox? button =
        _moreButtonKey.currentContext?.findRenderObject() as RenderBox?;

    if (button == null) {
      debugPrint(
        '❌ Error: No se pudo obtener el RenderBox del botón de 3 puntos',
      );
      return;
    }

    // Obtener el overlay
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    // Calcular posición del botón en coordenadas globales
    final Offset buttonPosition = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );

    const double menuWidth = 180;

    // Calcular posición del popup
    final RelativeRect position = RelativeRect.fromLTRB(
      buttonPosition.dx + button.size.width - menuWidth,
      buttonPosition.dy + button.size.height + 8,
      MediaQuery.of(context).size.width -
          (buttonPosition.dx + button.size.width),
      MediaQuery.of(context).size.height -
          (buttonPosition.dy + button.size.height + 8),
    );

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      color: Colors.white,
      items: [
        PopupMenuItem<String>(
          value: 'edit',
          height: 56,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Editar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'sort',
          height: 56,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.sort_rounded,
                  color: AppColors.secondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Ordenar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit') {
        setState(() {
          _isSelectionMode = true;
        });
      } else if (value == 'sort') {
        // IMPORTANTE: Dar tiempo para que el primer popup se cierre
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) {
            _showSortOptionsPopup();
          }
        });
      }
    });
  }

  // ========== POPUP DE ORDENAR - MEJORADO ==========
  void _showSortOptionsPopup() {
    // Obtener el RenderBox del MISMO botón de 3 puntos
    final RenderBox? button =
        _moreButtonKey.currentContext?.findRenderObject() as RenderBox?;

    if (button == null) {
      debugPrint(
        '❌ Error: No se pudo obtener el RenderBox para el popup de ordenar',
      );
      return;
    }

    // Obtener el overlay
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    // Calcular posición del botón
    final Offset buttonPosition = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );

    const double menuWidth = 220;

    // Calcular posición del popup
    final RelativeRect position = RelativeRect.fromLTRB(
      buttonPosition.dx + button.size.width - menuWidth,
      buttonPosition.dy + button.size.height + 8,
      MediaQuery.of(context).size.width -
          (buttonPosition.dx + button.size.width),
      MediaQuery.of(context).size.height -
          (buttonPosition.dy + button.size.height + 8),
    );

    showMenu<FolderSortOption>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      color: Colors.white,
      items: [
        _buildSortPopupItem(
          'Fecha (Más reciente)',
          Icons.calendar_today_rounded,
          FolderSortOption.dateDesc,
        ),
        _buildSortPopupItem(
          'Fecha (Más antigua)',
          Icons.history_rounded,
          FolderSortOption.dateAsc,
        ),
        _buildSortPopupItem(
          'Nombre (A-Z)',
          Icons.sort_by_alpha_rounded,
          FolderSortOption.nameAsc,
        ),
        _buildSortPopupItem(
          'Nombre (Z-A)',
          Icons.sort_by_alpha_rounded,
          FolderSortOption.nameDesc,
        ),
        _buildSortPopupItem(
          'Cantidad de libros',
          Icons.menu_book_rounded,
          FolderSortOption.bookCount,
        ),
      ],
    ).then((value) {
      if (value != null) {
        setState(() {
          _currentSortOption = value;
        });
      }
    });
  }

  // ========== HELPER PARA ITEMS DEL POPUP DE ORDENAR ==========
  PopupMenuItem<FolderSortOption> _buildSortPopupItem(
    String title,
    IconData icon,
    FolderSortOption option,
  ) {
    final isSelected = _currentSortOption == option;

    return PopupMenuItem<FolderSortOption>(
      value: option,
      height: 56,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.grey200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : Colors.black87,
              ),
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_rounded, color: AppColors.primary, size: 20),
        ],
      ),
    );
  }

  List<FolderModel> _getSortedFolders(List<FolderModel> folders) {
    final sortedFolders = List<FolderModel>.from(folders);

    switch (_currentSortOption) {
      case FolderSortOption.dateDesc:
        sortedFolders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case FolderSortOption.dateAsc:
        sortedFolders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case FolderSortOption.nameAsc:
        sortedFolders.sort((a, b) => a.name.compareTo(b.name));
        break;
      case FolderSortOption.nameDesc:
        sortedFolders.sort((a, b) => b.name.compareTo(a.name));
        break;
      case FolderSortOption.bookCount:
        sortedFolders.sort((a, b) => b.bookCount.compareTo(a.bookCount));
        break;
    }

    return sortedFolders;
  }

  Future<void> _showUploadDocumentFlow() async {
    if (!mounted) return;

    final selectedFolder = await showModalBottomSheet<FolderModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SelectFolderWidget(),
    );

    if (selectedFolder == null || !mounted) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddBookWidget(folder: selectedFolder),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Documento subido exitosamente'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _navigateToCreateFolder() async {
    if (!mounted) return;

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateFolderWidget(),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Carpeta creada exitosamente'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _navigateToFolderDetail(FolderModel folder) {
    Navigator.pushNamed(context, '/folder-detail', arguments: folder);
  }

  void _toggleFolderSelection(String folderId) {
    setState(() {
      if (_selectedFolderIds.contains(folderId)) {
        _selectedFolderIds.remove(folderId);
        if (_selectedFolderIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedFolderIds.add(folderId);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_isAllSelected()) {
        _selectedFolderIds.clear();
      } else {
        final folderProvider = context.read<FolderProvider>();
        _selectedFolderIds.clear();
        _selectedFolderIds.addAll(folderProvider.folders.map((f) => f.id));
      }
    });
  }

  bool _isAllSelected() {
    final folderProvider = context.read<FolderProvider>();
    return _selectedFolderIds.length == folderProvider.folders.length &&
        folderProvider.folders.isNotEmpty;
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedFolderIds.clear();
    });
  }

  void _showColorPicker() {
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
          padding: const EdgeInsets.all(24),
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
                'Cambiar Color',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: AppColors.folderColors.map((color) {
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(bottomSheetContext);
                      await _changeSelectedFoldersColor(color);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _changeSelectedFoldersColor(Color newColor) async {
    if (!mounted) return;

    final folderProvider = context.read<FolderProvider>();

    for (final folderId in _selectedFolderIds) {
      final folder = folderProvider.folders.firstWhere((f) => f.id == folderId);
      final updatedFolder = FolderModel(
        id: folder.id,
        userId: folder.userId,
        name: folder.name,
        color: newColor,
        createdAt: folder.createdAt,
        bookCount: folder.bookCount,
      );
      await folderProvider.updateFolder(folderId, updatedFolder);
    }

    _exitSelectionMode();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Color actualizado'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _showRenameDialog() {
    if (_selectedFolderIds.length != 1) return;

    final folderId = _selectedFolderIds.first;
    final folderProvider = context.read<FolderProvider>();
    final folder = folderProvider.folders.firstWhere((f) => f.id == folderId);

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
                  'Renombrar Carpeta',
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
                        color: const Color.fromARGB(
                          255,
                          100,
                          100,
                          100,
                        ).withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: nameController,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Nombre de la carpeta',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Icon(
                        Icons.folder_rounded,
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
                              AppColors.primary,
                              AppColors.primary.withValues(alpha: 0.85),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
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
                                final updatedFolder = FolderModel(
                                  id: folder.id,
                                  userId: folder.userId,
                                  name: nameController.text.trim(),
                                  color: folder.color,
                                  createdAt: folder.createdAt,
                                  bookCount: folder.bookCount,
                                );

                                final success = await folderProvider
                                    .updateFolder(folderId, updatedFolder);

                                if (!bottomSheetContext.mounted) return;

                                Navigator.pop(bottomSheetContext);

                                if (!mounted) return;

                                if (success) {
                                  _exitSelectionMode();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Carpeta renombrada'),
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
      nameController.dispose();
    });
  }

  void _showDeleteDialog() {
    final count = _selectedFolderIds.length;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Eliminar Carpetas',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              letterSpacing: -0.5,
            ),
          ),
          content: Text(
            '¿Estás seguro de que deseas eliminar ${count == 1 ? 'esta carpeta' : 'estas $count carpetas'}?\n\nSe eliminarán todos los libros dentro de ${count == 1 ? 'ella' : 'ellas'}.',
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
                  await _deleteSelectedFolders();
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

  Future<void> _deleteSelectedFolders() async {
    if (!mounted) return;

    final folderProvider = context.read<FolderProvider>();
    final count = _selectedFolderIds.length;

    for (final folderId in _selectedFolderIds) {
      await folderProvider.deleteFolder(folderId);
    }

    _exitSelectionMode();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 1 ? 'Carpeta eliminada' : 'Carpetas eliminadas',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _showUserPanel() {
    final authProvider = context.read<AuthProvider>();
    final coverPhotoUrl = authProvider.customCoverPhotoUrl;

    if (coverPhotoUrl != null) {
      precacheImage(NetworkImage(coverPhotoUrl), context).catchError((error) {
        debugPrint('Error precargando portada antes de abrir panel: $error');
      });
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const UserProfilePanel(),
    );
  }

  int _calculateTotalBooks(List<FolderModel> folders) {
    return folders.fold(0, (sum, folder) => sum + folder.bookCount);
  }
}

// ========== ENUM PARA OPCIONES DE ORDENAMIENTO ==========
enum FolderSortOption { dateDesc, dateAsc, nameAsc, nameDesc, bookCount }

// ========== WIDGET PULSE BUTTON ==========
class _PulseButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PulseButton({required this.child, this.onTap});

  @override
  State<_PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<_PulseButton>
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
      onTapDown: widget.onTap != null ? (_) => _controller.forward() : null,
      onTapUp: widget.onTap != null ? (_) => _controller.reverse() : null,
      onTapCancel: widget.onTap != null ? () => _controller.reverse() : null,
      onTap: widget.onTap,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

// ========== WIDGET HOVER BUTTON ==========
class _HoverButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _HoverButton({super.key, required this.child, this.onTap});

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
          color: _isPressed ? AppColors.grey200 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
      ),
    );
  }
}
