// lib/widgets/folder/folder_item.dart

import 'package:flutter/material.dart';
import '../../models/folder_model.dart';
import '../../screens/library/folder_detail_screen.dart';
import '../../utils/app_colors.dart';

/// Widget reutilizable para mostrar una carpeta con diseño apilado
/// Tamaño fijo: 130x90
///
/// 🆕 NUEVO: enableNavigation permite controlar si se navega automáticamente
class FolderItem extends StatelessWidget {
  final FolderModel folder;
  final bool enableNavigation; // 🆕 NUEVO parámetro

  const FolderItem({
    super.key,
    required this.folder,
    this.enableNavigation = true, // 🆕 Por defecto habilitado (para HomeScreen)
  });

  @override
  Widget build(BuildContext context) {
    // 🔥 SOLUCIÓN: Solo navegar si está habilitado
    return GestureDetector(
      onTap: enableNavigation ? () => _navigateToDetail(context) : null,
      child: _StackedFolderCard(folder: folder),
    );
  }

  void _navigateToDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FolderDetailScreen(folder: folder),
      ),
    );
  }
}

// ============= DISEÑO APILADO (Tamaño fijo con card contenedor) =============
class _StackedFolderCard extends StatelessWidget {
  final FolderModel folder;

  const _StackedFolderCard({required this.folder});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tamaño del contenedor principal
    const double containerWidth = 130;
    const double containerHeight = 90;

    // Tamaño de las cards internas (más pequeñas para dejar espacio)
    const double cardHeight = 50;
    const double cardPadding = 5.0; // Espacio desde el borde del contenedor

    // Generar gradientes de color (claro, medio, oscuro)
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
        // En tema oscuro: gris oscuro para contrastar con fondo negro
        // En tema claro: fondo blanco
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppColors.shadowDark : AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Capa 4 - Más clara (atrás) - SIN SOMBRAS NI BORDES
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

          // Capa 3 - Color medio - SIN SOMBRAS NI BORDES
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

          // Capa 2 - Color intenso - SIN SOMBRAS NI BORDES
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

          // Capa 1 - Frontal con contenido - SIN SOMBRAS NI BORDES
          Positioned(
            top: cardPadding + 12,
            left: cardPadding + 3,
            right: cardPadding + 3,
            child: Container(
              height: cardHeight,
              decoration: BoxDecoration(
                // En tema oscuro: gris oscuro para contrastar
                // En tema claro: fondo blanco
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Handle decorativo
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

                  // Contenido
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
                              color: Theme.of(context).colorScheme.onSurface,
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
