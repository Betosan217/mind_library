import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Widget de FAB con menú de múltiples acciones
/// Diseñado para crear carpetas, notas y checklists
class MultiActionFab extends StatefulWidget {
  /// Callback cuando se selecciona crear carpeta
  final VoidCallback onCreateFolder;

  /// Callback cuando se selecciona crear nota (opcional)
  final VoidCallback? onCreateNote;

  /// Callback cuando se selecciona crear checklist (opcional)
  final VoidCallback? onCreateChecklist;

  /// Callback cuando se selecciona subir un libro (opcional)
  final VoidCallback? onAddBook;

  /// Si es verdadero, muestra el menú abierto al inicio
  final bool initiallyOpen;

  const MultiActionFab({
    super.key,
    required this.onCreateFolder,
    this.onCreateNote,
    this.onCreateChecklist,
    this.onAddBook,
    this.initiallyOpen = false,
  });

  @override
  State<MultiActionFab> createState() => _MultiActionFabState();
}

class _MultiActionFabState extends State<MultiActionFab>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isMenuOpen = false;
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  late List<Animation<double>> _itemAnimations;

  @override
  void initState() {
    super.initState();
    _isMenuOpen = widget.initiallyOpen;

    // ✅ Agregar observer para detectar cambios en el ciclo de vida
    WidgetsBinding.instance.addObserver(this);

    // Controller principal
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Animación de rotación del botón principal (0° a 45°)
    _rotationAnimation =
        Tween<double>(
          begin: 0.0,
          end: 0.125, // 45 grados = 1/8 de vuelta completa
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

    // Calcular itemCount dinámicamente según callbacks presentes
    final itemCount = [
      true, // onCreateFolder siempre presente
      widget.onCreateNote != null,
      widget.onCreateChecklist != null,
      widget.onAddBook != null,
    ].where((exists) => exists).length;

    // Animaciones escalonadas para cada item del menú
    _itemAnimations = List.generate(itemCount, (index) {
      final delay = index * 0.05;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(delay, 0.5 + delay, curve: Curves.easeOut),
        ),
      );
    });

    if (_isMenuOpen) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    // ✅ Remover observer
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    super.dispose();
  }

  // ✅ Detectar cuando la app cambia de estado (background/foreground)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Cerrar el menú cuando la app va al background
      _closeMenu();
    }
  }

  // ✅ Detectar cuando se navega fuera de esta pantalla
  @override
  void deactivate() {
    _closeMenu();
    super.deactivate();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _closeMenu() {
    if (_isMenuOpen) {
      setState(() {
        _isMenuOpen = false;
        _animationController.reverse();
      });
    }
  }

  void _handleAction(VoidCallback action) {
    _closeMenu();
    // Esperar a que termine la animación antes de ejecutar la acción
    Future.delayed(const Duration(milliseconds: 150), action);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Overlay transparente cuando el menú está abierto (sin blur)
        if (_isMenuOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeMenu,
              child: Container(color: Colors.transparent),
            ),
          ),

        // Opciones del menú (aparecen hacia arriba)
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 76),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Siempre mostrar: Crear Carpeta
              _FabMenuItem(
                icon: 'assets/icons/folder_icon.svg',
                label: 'Crear Carpeta',
                gradientColors: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
                animation: _itemAnimations[0],
                onTap: () => _handleAction(widget.onCreateFolder),
                isDark: isDark,
              ),

              // Condicional: Crear Nota
              if (widget.onCreateNote != null) ...[
                const SizedBox(height: 12),
                _FabMenuItem(
                  icon: 'assets/icons/note_icon.svg',
                  label: 'Crear Nota',
                  gradientColors: const [Color(0xFFA855F7), Color(0xFF9333EA)],
                  animation: _itemAnimations[1],
                  onTap: () => _handleAction(widget.onCreateNote!),
                  isDark: isDark,
                ),
              ],

              // Condicional: Crear Checklist
              if (widget.onCreateChecklist != null) ...[
                const SizedBox(height: 12),
                _FabMenuItem(
                  icon: 'assets/icons/list_icon.svg',
                  label: 'Crear Checklist',
                  gradientColors: const [Color(0xFF22C55E), Color(0xFF16A34A)],
                  animation:
                      _itemAnimations[widget.onCreateNote != null ? 2 : 1],
                  onTap: () => _handleAction(widget.onCreateChecklist!),
                  isDark: isDark,
                ),
              ],

              // Condicional: Agregar Libro
              if (widget.onAddBook != null) ...[
                const SizedBox(height: 12),
                _FabMenuItem(
                  icon: 'assets/icons/add_pdf.svg',
                  label: 'Agregar Libro',
                  gradientColors: const [Color(0xFFEF4444), Color(0xFFDC2626)],
                  animation:
                      _itemAnimations[[
                        true,
                        widget.onCreateNote != null,
                        widget.onCreateChecklist != null,
                      ].where((e) => e).length],
                  onTap: () => _handleAction(widget.onAddBook!),
                  isDark: isDark,
                ),
              ],
            ],
          ),
        ),

        // Botón principal del FAB (ahora circular y flotante)
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: _toggleMenu,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 150),
              scale: _isMenuOpen ? 1.0 : 1.0,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
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
                child: Center(
                  child: RotationTransition(
                    turns: _rotationAnimation,
                    child: SvgPicture.asset(
                      'assets/icons/ai_add.svg',
                      width: 28,
                      height: 28,
                      colorFilter: ColorFilter.mode(
                        Theme.of(context).colorScheme.onPrimary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Widget individual para cada opción del menú FAB
class _FabMenuItem extends StatefulWidget {
  final String icon;
  final String label;
  final List<Color> gradientColors;
  final Animation<double> animation;
  final VoidCallback? onTap;
  final bool isDark;

  const _FabMenuItem({
    required this.icon,
    required this.label,
    required this.gradientColors,
    required this.animation,
    required this.isDark,
    this.onTap,
  });

  @override
  State<_FabMenuItem> createState() => _FabMenuItemState();
}

class _FabMenuItemState extends State<_FabMenuItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onTap != null;

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 32 * (1 - widget.animation.value)),
          child: Opacity(
            opacity: widget.animation.value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Label flotante (aparece al mantener presionado)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isHovering && isEnabled ? 1.0 : 0.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF1C1C1E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Botón circular con gradiente
                GestureDetector(
                  onTapDown: isEnabled
                      ? (_) => setState(() => _isHovering = true)
                      : null,
                  onTapUp: isEnabled
                      ? (_) => setState(() => _isHovering = false)
                      : null,
                  onTapCancel: () => setState(() => _isHovering = false),
                  onTap: widget.onTap,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 150),
                    scale: _isHovering && isEnabled ? 1.1 : 1.0,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isEnabled
                              ? widget.gradientColors
                              : [Colors.grey, Colors.grey.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (isEnabled
                                        ? widget.gradientColors[0]
                                        : Colors.grey)
                                    .withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          widget.icon,
                          width: 24,
                          height: 24,
                          colorFilter: ColorFilter.mode(
                            isEnabled ? Colors.white : Colors.white70,
                            BlendMode.srcIn,
                          ),
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
}
