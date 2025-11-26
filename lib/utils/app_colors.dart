import 'package:flutter/material.dart';

class AppColors {
  // ========== TEMA CLARO ==========
  // Color primario y acento
  static const Color primaryLight = Color(
    0xFF000000,
  ); // Negro para elementos principales
  static const Color secondaryLight = Color(
    0xFF6C63FF,
  ); // Morado suave para acentos

  // Backgrounds - Tema Claro (3 niveles de elevación)
  static const Color backgroundLight = Color(
    0xFFFFFFFF,
  ); // Blanco puro - Nivel 0
  static const Color surfaceLight = Color(
    0xFFF8F8F8,
  ); // Gris muy claro - Nivel 1 (cards)
  static const Color surfaceVariantLight = Color(
    0xFFF0F0F0,
  ); // Gris claro - Nivel 2 (elementos presionados)

  // ========== TEMA OSCURO ==========
  // Color primario y acento
  static const Color primaryDark = Color(
    0xFFFFFFFF,
  ); // Blanco para elementos principales
  static const Color secondaryDark = Color(
    0xFF8B7FFF,
  ); // Morado más claro para acentos

  // Backgrounds - Tema Oscuro (3 niveles de elevación según Material Design)
  static const Color backgroundDark = Color(0xFF000000); // Negro puro - Nivel 0
  static const Color surfaceDark = Color(
    0xFF1C1C1E,
  ); // Gris muy oscuro - Nivel 1 (cards)
  static const Color surfaceVariantDark = Color(
    0xFF2C2C2E,
  ); // Gris oscuro - Nivel 2 (elementos presionados)

  // ========== COLORES DE CARPETAS/CATEGORÍAS ==========
  // 16 colores vibrantes y únicos
  static const Color folderBlue = Color(0xFF42A5F5);
  static const Color folderPurple = Color(0xFFAB47BC);
  static const Color folderOrange = Color(0xFFFF9800);
  static const Color folderGreen = Color(0xFF66BB6A);
  static const Color folderRed = Color(0xFFEF5350);
  static const Color folderYellow = Color(0xFFFFEB3B);
  static const Color folderPink = Color(0xFFEC407A);
  static const Color folderTeal = Color(0xFF26A69A);
  static const Color folderIndigo = Color(0xFF5C6BC0);
  static const Color folderCyan = Color(0xFF26C6DA);
  static const Color folderLime = Color(0xFFD4E157);
  static const Color folderAmber = Color(0xFFFFCA28);
  static const Color folderDeepOrange = Color(0xFFFF7043);
  static const Color folderBrown = Color(0xFF8D6E63);
  static const Color folderBlueGrey = Color(0xFF78909C);
  static const Color folderLightGreen = Color(0xFF9CCC65);

  // ========== COLORES DE TEXTO ==========
  // Tema Claro
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textSecondaryLight = Color(0xFF666666);
  static const Color textTertiaryLight = Color(0xFF999999);
  static const Color textHintLight = Color(0xFFBDBDBD);

  // Tema Oscuro
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB3B3B3);
  static const Color textTertiaryDark = Color(0xFF8E8E93);
  static const Color textHintDark = Color(0xFF6B6B6B);

  // ========== ESTADOS ==========
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFB300);
  static const Color info = Color(0xFF2196F3);

  // ========== HIGHLIGHTS PARA SUBRAYADO ==========
  static const Color highlightYellow = Color(0xFFFFEB3B);
  static const Color highlightGreen = Color(0xFF8BC34A);
  static const Color highlightBlue = Color(0xFF64B5F6);
  static const Color highlightPink = Color(0xFFF48FB1);
  static const Color highlightOrange = Color(0xFFFFB74D);

  // ========== DIVIDERS ==========
  static const Color dividerLight = Color(0xFFE5E5E5);
  static const Color dividerDark = Color(0xFF38383A);

  // ========== OVERLAYS (para ripples, hovers, etc) ==========
  static const Color overlayLight = Color(0x0A000000); // Negro 4%
  static const Color overlayDark = Color(0x14FFFFFF); // Blanco 8%

  // ========== SHADOWS ==========
  static const Color shadowLight = Color(0x1A000000); // Negro 10%
  static const Color shadowDark = Color(0x33000000); // Negro 20%

  // ========== GRISES AUXILIARES ==========
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey850 = Color(0xFF303030);
  static const Color grey900 = Color(0xFF212121);

  // ========== LISTAS DE COLORES ==========
  static const List<Color> folderColors = [
    folderBlue,
    folderPurple,
    folderOrange,
    folderGreen,
    folderRed,
    folderYellow,
    folderPink,
    folderTeal,
    folderIndigo,
    folderCyan,
    folderLime,
    folderAmber,
    folderDeepOrange,
    folderBrown,
    folderBlueGrey,
    folderLightGreen,
  ];

  static const List<Color> highlightColors = [
    highlightYellow,
    highlightGreen,
    highlightBlue,
    highlightPink,
    highlightOrange,
  ];
}
