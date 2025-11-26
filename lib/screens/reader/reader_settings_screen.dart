import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/book_model.dart';
import '../../providers/reader_provider.dart';
import '../../utils/app_colors.dart';

class ReaderSettingsScreen extends StatefulWidget {
  final BookModel book;

  const ReaderSettingsScreen({super.key, required this.book});

  @override
  State<ReaderSettingsScreen> createState() => _ReaderSettingsScreenState();
}

class _ReaderSettingsScreenState extends State<ReaderSettingsScreen> {
  String _selectedOrientation = 'vertical';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Lectura'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // ========== ORIENTACIÓN ==========
          _buildSection(
            title: 'Orientación de Lectura',
            icon: Icons.screen_rotation,
            child: Column(
              children: [
                _buildOrientationOption(
                  title: 'Vertical',
                  icon: Icons.stay_current_portrait,
                  value: 'vertical',
                  selected: _selectedOrientation == 'vertical',
                  onTap: () {
                    setState(() => _selectedOrientation = 'vertical');
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.portraitUp,
                    ]);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Modo vertical activado'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: colorScheme.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildOrientationOption(
                  title: 'Horizontal',
                  icon: Icons.stay_current_landscape,
                  value: 'horizontal',
                  selected: _selectedOrientation == 'horizontal',
                  onTap: () {
                    setState(() => _selectedOrientation = 'horizontal');
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.landscapeLeft,
                      DeviceOrientation.landscapeRight,
                    ]);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Modo horizontal activado'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: colorScheme.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildOrientationOption(
                  title: 'Automático',
                  icon: Icons.screen_lock_rotation,
                  value: 'auto',
                  selected: _selectedOrientation == 'auto',
                  onTap: () {
                    setState(() => _selectedOrientation = 'auto');
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.portraitUp,
                      DeviceOrientation.landscapeLeft,
                      DeviceOrientation.landscapeRight,
                    ]);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Rotación automática activada'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: colorScheme.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          Divider(
            height: 32,
            color: theme.brightness == Brightness.light
                ? AppColors.dividerLight
                : AppColors.dividerDark,
          ),

          // ========== ESTADÍSTICAS ==========
          _buildSection(
            title: 'Estadísticas de Lectura',
            icon: Icons.analytics_outlined,
            child: Consumer<ReaderProvider>(
              builder: (context, readerProvider, _) {
                final progress = readerProvider.totalPages > 0
                    ? (readerProvider.currentPage / readerProvider.totalPages)
                    : 0.0;

                return Column(
                  children: [
                    _buildStatItem(
                      'Progreso',
                      '${(progress * 100).toInt()}%',
                      Icons.trending_up,
                    ),
                    _buildStatItem(
                      'Página actual',
                      '${readerProvider.currentPage} de ${readerProvider.totalPages}',
                      Icons.auto_stories,
                    ),
                    _buildStatItem(
                      'Páginas restantes',
                      '${readerProvider.totalPages - readerProvider.currentPage}',
                      Icons.book_outlined,
                    ),
                  ],
                );
              },
            ),
          ),

          Divider(
            height: 32,
            color: theme.brightness == Brightness.light
                ? AppColors.dividerLight
                : AppColors.dividerDark,
          ),

          // ========== INFORMACIÓN ==========
          _buildSection(
            title: 'Controles Rápidos',
            icon: Icons.info_outline,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    Icons.brightness_6,
                    'Toca "Brillo" en la barra inferior para ajustar luz',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.nightlight_round,
                    'Activa modo noche desde el popup de brillo',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.search,
                    'Busca texto usando el ícono superior',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.swipe_vertical,
                    'Desliza verticalmente para navegar rápido entre páginas',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.lock,
                    'Bloquea controles para lectura sin distracciones',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ========== ACCIONES ==========
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _showResetDialog();
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reiniciar progreso'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Volver al lector'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(color: colorScheme.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== WIDGETS AUXILIARES ==========

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildOrientationOption({
    required String title,
    required IconData icon,
    required String value,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.1)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.87),
              ),
            ),
            const Spacer(),
            if (selected) Icon(Icons.check_circle, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.info),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.info,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  void _showResetDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reiniciar progreso', style: theme.textTheme.titleLarge),
        content: Text(
          '¿Estás seguro de que deseas reiniciar el progreso de lectura? '
          'Esta acción volverá a la página 1.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final readerProvider = context.read<ReaderProvider>();
              readerProvider.resetProgress(widget.book.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Progreso reiniciado correctamente'),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
  }
}
