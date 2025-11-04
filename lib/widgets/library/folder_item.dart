// lib/widgets/folder/folder_item.dart

import 'package:flutter/material.dart';
import '../../models/folder_model.dart';
import '../../utils/app_colors.dart';
import '../../screens/library/folder_detail_screen.dart';

/// Widget reutilizable para mostrar una carpeta con diseño apilado
/// Tamaño fijo: 130x90
class FolderItem extends StatelessWidget {
  final FolderModel folder;

  const FolderItem({super.key, required this.folder});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigateToDetail(context),
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

          // Capa 1 - Frontal blanca con contenido - SIN SOMBRAS NI BORDES
          Positioned(
            top: cardPadding + 12,
            left: cardPadding + 3,
            right: cardPadding + 3,
            child: Container(
              height: cardHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                // ❌ SIN boxShadow
                // ❌ SIN border
              ),
              child: Column(
                children: [
                  // Handle decorativo
                  const SizedBox(height: 4),
                  Container(
                    width: 24,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
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

// ============= LIST ITEM (Vista de lista horizontal - OPCIONAL) =============
class FolderListItem extends StatelessWidget {
  final FolderModel folder;

  const FolderListItem({super.key, required this.folder});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [folder.color.withValues(alpha: 0.8), folder.color],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.folder_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        title: Text(
          folder.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          '${folder.bookCount} ${folder.bookCount == 1 ? 'libro' : 'libros'}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.grey[400],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FolderDetailScreen(folder: folder),
            ),
          );
        },
      ),
    );
  }
}
