import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/folder_provider.dart';
import '../../providers/task_provider.dart';
import '../../models/folder_model.dart';
import '../../widgets/library/folder_item.dart';
import '../../widgets/library/create_folder_widget.dart';
import '../../widgets/library/select_folder_widget.dart';
import '../../widgets/library/add_book_widget.dart';
import '../../widgets/common/animated_lottie_avatar.dart';
import '../../widgets/user/user_profile_panel.dart';
import '../../utils/app_colors.dart';
import '../../screens/notes/notes_list_screen.dart';
import '../../widgets/home/multi_action_fab.dart';
import '../../widgets/notes/note_bottom_sheet.dart';
import '../task/task_groups_screen.dart';
import '../search/search_book_screen.dart';

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

    // 🆕 Inicializar streams de tareas para el Home
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final taskProvider = context.read<TaskProvider>();
      final userId = authProvider.user?.uid ?? '';

      if (userId.isNotEmpty) {
        taskProvider.initHomeStreams(userId);
      }
    });
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
    final taskProvider = context.watch<TaskProvider>();
    final totalBooks = _calculateTotalBooks(folderProvider.folders);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final upcomingTasks = taskProvider.getUpcomingTasks();

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
        backgroundColor: isDark
            ? Theme.of(context).scaffoldBackgroundColor
            : Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMainHeader(context, folderProvider, totalBooks),
              const SizedBox(height: 16),
              _buildActionsBar(context, isDark),
              const SizedBox(height: 16),
              // 🆕 Sección de tareas pendientes
              if (upcomingTasks.isNotEmpty) ...[
                _buildUpcomingTasksSection(upcomingTasks, taskProvider, isDark),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: folderProvider.folders.isEmpty
                    ? _buildEmptyState(context)
                    : _buildFoldersGrid(folderProvider.folders),
              ),
            ],
          ),
        ),
        floatingActionButton: SlideTransition(
          position: _fabSlideAnimation,
          child: MultiActionFab(
            onCreateFolder: _navigateToCreateFolder,
            onCreateNote: _navigateToCreateNote,
            onCreateChecklist: _navigateToTaskGroups,
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
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
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
  }

  // 🆕 Widget de sección de tareas pendientes
  Widget _buildUpcomingTasksSection(
    List<dynamic> tasks,
    TaskProvider taskProvider,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tareas pendientes',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...tasks.map((task) {
            final dueDate = task.dueDate as DateTime?;
            final isOverdue =
                dueDate != null && dueDate.isBefore(DateTime.now());

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    '›',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textHintDark
                          : AppColors.textHintLight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (dueDate != null)
                    Text(
                      DateFormat('dd MMM').format(dueDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isOverdue
                            ? AppColors.error
                            : (isDark
                                  ? AppColors.textHintDark
                                  : AppColors.textHintLight),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          // Divisor sutil
          Center(
            child: Container(
              width: 120,
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    (isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1)),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: _navigateToTaskGroups,
              child: Text(
                'Ver todas',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
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
          Center(
            child: Text(
              _isSelectionMode
                  ? '${_selectedFolderIds.length} seleccionado(s)'
                  : 'Carpetas',
              style: Theme.of(context).textTheme.displayLarge,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${provider.foldersCount} ${provider.foldersCount == 1 ? 'carpeta' : 'carpetas'}, $totalBooks ${totalBooks == 1 ? 'libro' : 'libros'}',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsBar(BuildContext context, bool isDark) {
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
                      isSelected: _isAllSelected(),
                      size: 24,
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
          ] else ...[
            GestureDetector(
              onTap: () {
                _showUserPanel();
              },
              child: _buildLargerAvatar(),
            ),
            const Spacer(),
            _buildActionButton(
              svgPath: 'assets/icons/add_pdf.svg',
              onTap: _showUploadDocumentFlow,
              isDark: isDark,
            ),
            const SizedBox(width: 4),
            _buildActionButton(
              svgPath: 'assets/icons/notification_status.svg',
              onTap: _navigateToNotes,
              isDark: isDark,
            ),
            const SizedBox(width: 4),
            _buildActionButton(
              icon: Icons.search_rounded,
              onTap: _navigateToSearch,
              isDark: isDark,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _PulseButton(
      onTap: isUpdating ? null : _showUserPanel,
      child: Stack(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              // 🆕 Solo mostrar borde si hay foto de perfil
              border: userPhotoUrl != null
                  ? Border.all(
                      color:
                          Theme.of(context).dividerTheme.color ?? Colors.grey,
                      width: 2.5,
                    )
                  : null,
              boxShadow: userPhotoUrl != null
                  ? [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                userPhotoUrl != null ? 17.5 : 20,
              ),
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
                              color: Theme.of(context).colorScheme.primary,
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
        color: Theme.of(context).textTheme.bodyMedium?.color,
      ),
    );
  }

  Widget _buildActionButton({
    Key? key,
    IconData? icon,
    String? svgPath,
    required VoidCallback onTap,
    required bool isDark,
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
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.onSurface,
                  BlendMode.srcIn,
                ),
              )
            : Icon(icon, size: 24, color: Theme.of(context).iconTheme.color),
      ),
    );
  }

  Widget _buildFoldersGrid(List<FolderModel> folders) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
    );
  }

  Widget _buildSelectionCircle({
    required bool isSelected,
    required double size,
    required bool isDark,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
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
          ? Icon(Icons.check_rounded, color: Colors.white, size: size * 0.6)
          : null,
    );
  }

  Widget _buildSelectionBottomBar(bool isDark) {
    final canRename = _selectedFolderIds.length == 1;

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
                'assets/icons/paintbucket.svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
              label: 'Color',
              onTap: _showColorPicker,
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
              onTap: canRename ? _showRenameDialog : null,
              isEnabled: canRename,
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

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isDark
                  ? Theme.of(context).colorScheme.surface
                  : const Color(0xFFF5F5F5),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/folder_empty.svg',
                width: 50,
                height: 50,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
                  BlendMode.srcIn,
                ),
              ),
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
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Future<void> _showUploadDocumentFlow() async {
    if (!mounted) return;
    final folderProvider = context.read<FolderProvider>();
    final allFolders = await folderProvider.getAllFoldersHierarchy();

    if (!mounted) return;

    final selectedFolder = await showModalBottomSheet<FolderModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SelectFolderWidget(preloadedFolders: allFolders),
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

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateFolderWidget(),
    );
  }

  void _navigateToSearch() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SearchBooksScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _navigateToCreateNote() async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const NoteBottomSheet(),
      ),
    );
  }

  void _navigateToTaskGroups() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TaskGroupsScreen()),
    );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? Theme.of(context).colorScheme.surface
                : Colors.white,
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
                    color: Theme.of(context).dividerTheme.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Cambiar Color',
                style: Theme.of(context).textTheme.titleLarge,
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
        parentFolderId: null,
      );
      await folderProvider.updateFolder(folderId, updatedFolder);
    }

    _exitSelectionMode();
  }

  void _showRenameDialog() {
    if (_selectedFolderIds.length != 1) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            color: isDark
                ? Theme.of(context).colorScheme.surface
                : Colors.white,
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
                      color: Theme.of(context).dividerTheme.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Renombrar Carpeta',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Theme.of(context).scaffoldBackgroundColor
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
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Nombre de la carpeta',
                      hintStyle: Theme.of(context)
                          .inputDecorationTheme
                          .hintStyle
                          ?.copyWith(fontWeight: FontWeight.w400),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SvgPicture.asset(
                          'assets/icons/folder_icon.svg',
                          width: 20,
                          height: 20,
                          colorFilter: ColorFilter.mode(
                            Theme.of(context).textTheme.bodyMedium?.color ??
                                Colors.grey,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Theme.of(context).scaffoldBackgroundColor
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
                              ? Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                Theme.of(context).dividerTheme.color ??
                                Colors.grey,
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
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
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
                              Theme.of(context).colorScheme.primary,
                              Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.85),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.3),
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
                                  parentFolderId: folder.parentFolderId,
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
                            child: Center(
                              child: Text(
                                'Guardar',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark
              ? Theme.of(context).colorScheme.surface
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Eliminar Carpetas',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          content: Text(
            '¿Estás seguro de que deseas eliminar ${count == 1 ? 'esta carpeta' : 'estas $count carpetas'}?\n\nSe eliminarán todos los libros y subcarpetas dentro de ${count == 1 ? 'ella' : 'ellas'}.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Container(
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerTheme.color ?? Colors.grey,
                  width: 1.5,
                ),
              ),
              child: TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Cancelar',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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

    for (final folderId in _selectedFolderIds) {
      await folderProvider.deleteFolder(folderId);
    }

    _exitSelectionMode();
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
