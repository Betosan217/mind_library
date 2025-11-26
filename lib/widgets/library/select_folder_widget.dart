import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import '../../providers/folder_provider.dart';
import '../../models/folder_model.dart';

class SelectFolderWidget extends StatefulWidget {
  final List<FolderModel>? preloadedFolders;
  const SelectFolderWidget({
    super.key,
    this.preloadedFolders, // ✅ NUEVO
  });

  @override
  State<SelectFolderWidget> createState() => _SelectFolderWidgetState();
}

class _SelectFolderWidgetState extends State<SelectFolderWidget> {
  FolderModel? _selectedFolder;
  final Set<String> _expandedFolderIds = {};
  List<FolderModel> _allFolders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllFolders();
  }

  Future<void> _loadAllFolders() async {
    if (widget.preloadedFolders != null) {
      setState(() {
        _allFolders = widget.preloadedFolders!;
        _isLoading = false;
      });
      return;
    }
    final folderProvider = context.read<FolderProvider>();
    final folders = await folderProvider.getAllFoldersHierarchy();

    setState(() {
      _allFolders = folders;
      _isLoading = false;
    });
  }

  // Obtener carpetas raíz
  List<FolderModel> get _rootFolders {
    return _allFolders.where((f) => f.parentFolderId == null).toList();
  }

  // Obtener subcarpetas de un padre específico
  List<FolderModel> _getSubFolders(String parentId) {
    return _allFolders.where((f) => f.parentFolderId == parentId).toList();
  }

  void _toggleExpanded(String folderId) {
    setState(() {
      if (_expandedFolderIds.contains(folderId)) {
        _expandedFolderIds.remove(folderId);
      } else {
        _expandedFolderIds.add(folderId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 20),
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerTheme.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Theme.of(context).iconTheme.color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Título
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  'Seleccionar Carpeta',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Elige dónde guardar el documento',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).dividerTheme.color,
          ),

          const SizedBox(height: 8),

          // Contenido
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_rootFolders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(
                    Icons.folder_off_rounded,
                    size: 56,
                    color: Theme.of(
                      context,
                    ).iconTheme.color?.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes carpetas',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Crea una carpeta primero',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _rootFolders.length,
                itemBuilder: (context, index) {
                  return _buildFolderTree(
                    context,
                    _rootFolders[index],
                    0,
                    isDark,
                  );
                },
              ),
            ),

          // Divider
          if (!_isLoading && _rootFolders.isNotEmpty)
            Divider(
              height: 1,
              thickness: 1,
              color: Theme.of(context).dividerTheme.color,
            ),

          // Botón continuar
          if (!_isLoading && _rootFolders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: SafeArea(
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: _selectedFolder != null
                        ? LinearGradient(
                            colors: [
                              _selectedFolder!.color,
                              _selectedFolder!.color.withValues(alpha: 0.85),
                            ],
                          )
                        : LinearGradient(
                            colors: isDark
                                ? [
                                    Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.8),
                                  ]
                                : [
                                    Theme.of(context).dividerTheme.color!
                                        .withValues(alpha: 0.3),
                                    Theme.of(context).dividerTheme.color!
                                        .withValues(alpha: 0.4),
                                  ],
                          ),
                    boxShadow: _selectedFolder != null
                        ? [
                            BoxShadow(
                              color: _selectedFolder!.color.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _selectedFolder != null
                          ? () => Navigator.pop(context, _selectedFolder)
                          : null,
                      child: Center(
                        child: Text(
                          'Continuar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _selectedFolder != null
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.5),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Construir árbol de carpetas recursivamente
  Widget _buildFolderTree(
    BuildContext context,
    FolderModel folder,
    int level,
    bool isDark,
  ) {
    final isSelected = _selectedFolder?.id == folder.id;
    final isExpanded = _expandedFolderIds.contains(folder.id);
    final subFolders = _getSubFolders(folder.id);
    final hasSubfolders = subFolders.isNotEmpty;

    // Calcular indentación
    final indentation = level * 24.0;

    return Column(
      children: [
        // Item de carpeta
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.only(
            left: 24 + indentation,
            right: 24,
            top: 12,
            bottom: 12,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? folder.color.withValues(alpha: 0.06)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              // ✅ Botón de expansión MÁS GRANDE (toda el área es clickeable)
              if (hasSubfolders)
                GestureDetector(
                  onTap: () => _toggleExpanded(folder.id),
                  behavior:
                      HitTestBehavior.opaque, // Hace toda el área clickeable
                  child: Container(
                    width: 32, // Área más grande
                    height: 32,
                    alignment: Alignment.center,
                    child: AnimatedRotation(
                      duration: const Duration(milliseconds: 200),
                      turns: isExpanded ? 0.25 : 0,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 24, // Ícono más grande
                        color: Theme.of(
                          context,
                        ).iconTheme.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 32),

              const SizedBox(width: 4),

              // ✅ Área expandible (toca para expandir/colapsar)
              Expanded(
                child: GestureDetector(
                  onTap: hasSubfolders
                      ? () => _toggleExpanded(folder.id)
                      : null,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      // Icono de carpeta
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: folder.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: SvgPicture.asset(
                              'assets/icons/folder_icon.svg',
                              colorFilter: ColorFilter.mode(
                                folder.color.withValues(alpha: 0.9),
                                BlendMode.srcIn,
                              ),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Info de la carpeta
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              folder.name,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    letterSpacing: -0.2,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${folder.bookCount} ${folder.bookCount == 1 ? 'libro' : 'libros'}${hasSubfolders ? ' • ${subFolders.length} ${subFolders.length == 1 ? 'carpeta' : 'carpetas'}' : ''}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // ✅ Checkbox SEPARADO (solo este selecciona)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFolder = folder;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 40, // Área de toque más grande
                  height: 40,
                  alignment: Alignment.center,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? folder.color
                            : (Theme.of(context).dividerTheme.color ??
                                  Colors.grey),
                        width: 2,
                      ),
                      color: isSelected ? folder.color : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 14,
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Subcarpetas (si está expandido)
        if (isExpanded && hasSubfolders)
          ...subFolders.map(
            (subFolder) =>
                _buildFolderTree(context, subFolder, level + 1, isDark),
          ),

        // Divider entre carpetas raíz
        if (level == 0)
          Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).dividerTheme.color?.withValues(alpha: 0.3),
            indent: 24,
          ),
      ],
    );
  }
}
