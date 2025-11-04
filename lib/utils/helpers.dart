import 'package:flutter/material.dart';

class IconHelper {
  // Mapa de códigos de iconos a IconData constantes
  static const Map<int, IconData> _iconMap = {
    0xe1ba: Icons.folder_rounded,
    0xe2c7: Icons.folder_open,
    0xe1bb: Icons.folder_special,
    0xe2c8: Icons.book,
    0xe865: Icons.library_books,
    0xe873: Icons.menu_book,
    0xe0b7: Icons.auto_stories,
    0xe867: Icons.local_library, // 👈 Mantuve este
    0xe1bd: Icons.collections_bookmark,
    0xe866: Icons.bookmark,
    0xe3f4: Icons.bookmarks, // 👈 Cambié el código (era 0xe867)
    0xe030: Icons.chrome_reader_mode, // 👈 Cambié el código (era 0xe873)
    // Agrega más iconos que uses en tu app
  };

  /// Obtiene un IconData desde un código, con fallback a folder_rounded
  static IconData fromCode(int? codePoint) {
    if (codePoint == null) return Icons.folder_rounded;
    return _iconMap[codePoint] ?? Icons.folder_rounded;
  }

  /// Obtiene el código desde un IconData
  static int toCode(IconData icon) {
    return icon.codePoint;
  }
}
