import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/folder_provider.dart';
import '../../models/folder_model.dart';
import '../../utils/app_colors.dart';

class CreateFolderWidget extends StatefulWidget {
  final String?
  parentFolderId; // ✅ NUEVO: null = carpeta raíz, con valor = subcarpeta

  const CreateFolderWidget({super.key, this.parentFolderId});

  @override
  State<CreateFolderWidget> createState() => _CreateFolderWidgetState();
}

class _CreateFolderWidgetState extends State<CreateFolderWidget>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  Color _selectedColor = AppColors.folderBlue;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      if (!mounted) return;

      final folderProvider = Provider.of<FolderProvider>(
        context,
        listen: false,
      );
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) return;

      final folder = FolderModel(
        id: '',
        userId: userId,
        name: _nameController.text.trim(),
        color: _selectedColor,
        createdAt: DateTime.now(),
        bookCount: 0,
        parentFolderId: widget.parentFolderId, // ✅ NUEVO: Asignar parentId
      );

      bool success = await folderProvider.createFolder(folder);

      if (!mounted) return;

      if (success) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // ✅ NUEVO: Detectar si estamos creando una subcarpeta
    final isSubfolder = widget.parentFolderId != null;

    return Consumer<FolderProvider>(
      builder: (context, folderProvider, child) {
        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? Theme.of(context).colorScheme.surface
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle indicator
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.grey700 : AppColors.grey300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ✅ MODIFICADO: Título dinámico
                    Text(
                      isSubfolder ? 'Nueva Subcarpeta' : 'Nueva Carpeta',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Preview
                    Center(
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: _PreviewStackedFolder(
                          name: _nameController.text.isEmpty
                              ? 'Mi Carpeta'
                              : _nameController.text,
                          color: _selectedColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Campo de nombre
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Theme.of(context).colorScheme.surface
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
                        controller: _nameController,
                        onChanged: (value) {
                          setState(() {});
                        },
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Nombre de la carpeta',
                          hintStyle: TextStyle(
                            color: isDark
                                ? AppColors.textHintDark
                                : AppColors.textHintLight,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: Icon(
                            Icons.folder_rounded,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                            size: 20,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Theme.of(context).colorScheme.surface
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
                    const SizedBox(height: 20),

                    // Color selector
                    Row(
                      children: [
                        Icon(
                          Icons.palette_rounded,
                          size: 18,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Color',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Grid de colores más compacto
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: AppColors.folderColors.map((color) {
                        final isSelected = _selectedColor == color;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColor = color;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: color, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: isDark
                                            ? Colors.black.withValues(
                                                alpha: 0.3,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.06,
                                              ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Botones: Cancelar y Guardar/Añadir
                    Row(
                      children: [
                        // Botón Cancelar
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
                                color: isDark
                                    ? AppColors.dividerDark
                                    : AppColors.dividerLight,
                                width: 1.5,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => Navigator.pop(context),
                                child: Center(
                                  child: Text(
                                    'Cancelar',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.3,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Botón Añadir/Guardar
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                colors: folderProvider.isLoading
                                    ? [
                                        isDark
                                            ? AppColors.grey700
                                            : AppColors.grey300,
                                        isDark
                                            ? AppColors.grey800
                                            : AppColors.grey400,
                                      ]
                                    : [
                                        _selectedColor,
                                        _selectedColor.withValues(alpha: 0.85),
                                      ],
                              ),
                              boxShadow: folderProvider.isLoading
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: _selectedColor.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: folderProvider.isLoading
                                    ? null
                                    : _handleSave,
                                child: Center(
                                  child: folderProvider.isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : const Text(
                                          'Añadir',
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

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============= PREVIEW (ADAPTADO A TEMAS) =============
class _PreviewStackedFolder extends StatelessWidget {
  final String name;
  final Color color;

  const _PreviewStackedFolder({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const double containerWidth = 130;
    const double containerHeight = 90;
    const double cardHeight = 50;
    const double cardPadding = 5.0;

    final lightColors = [
      color.withValues(alpha: 0.3),
      color.withValues(alpha: 0.4),
    ];
    final mediumColors = [
      color.withValues(alpha: 0.6),
      color.withValues(alpha: 0.7),
    ];
    final darkColors = [
      color.withValues(alpha: 0.85),
      color.withValues(alpha: 0.95),
    ];

    return Container(
      width: containerWidth,
      height: containerHeight,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.08),
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
                color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  Container(
                    width: 24,
                    height: 2,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight,
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
                            name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '0 libros',
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
