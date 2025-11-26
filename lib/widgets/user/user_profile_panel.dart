// lib/widgets/user/user_profile_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_colors.dart';

class UserProfilePanel extends StatefulWidget {
  const UserProfilePanel({super.key});

  @override
  State<UserProfilePanel> createState() => _UserProfilePanelState();
}

class _UserProfilePanelState extends State<UserProfilePanel> {
  final ImagePicker _picker = ImagePicker();
  final GlobalKey _settingsButtonKey = GlobalKey();
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _precacheImages();
  }

  // ========== PRECARGA DE IMÁGENES ==========
  Future<void> _precacheImages() async {
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final userPhotoUrl =
        authProvider.customProfilePhotoUrl ?? authProvider.user?.photoURL;
    final coverPhotoUrl = authProvider.customCoverPhotoUrl;

    if (userPhotoUrl != null && mounted) {
      try {
        await precacheImage(NetworkImage(userPhotoUrl), context);
      } catch (e) {
        debugPrint('Error precargando foto de perfil: $e');
      }
    }

    if (coverPhotoUrl != null && mounted) {
      try {
        await precacheImage(NetworkImage(coverPhotoUrl), context);
      } catch (e) {
        debugPrint('Error precargando foto de portada: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.user?.displayName ?? 'Usuario';
    final userEmail = authProvider.user?.email ?? '';
    final userPhotoUrl =
        authProvider.customProfilePhotoUrl ?? authProvider.user?.photoURL;
    final coverPhotoUrl = authProvider.customCoverPhotoUrl;

    return Container(
      decoration: BoxDecoration(
        // ✅ Blanco puro en claro, gris oscuro en dark
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle indicator
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.grey700 : AppColors.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 16),

          // Cover + Avatar Section
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Cover photo
              _buildCoverPhoto(coverPhotoUrl, authProvider.isUpdatingCover),

              // Avatar
              Positioned(
                left: 24,
                bottom: -40,
                child: _buildAvatar(
                  userPhotoUrl,
                  authProvider.isUpdatingProfile,
                ),
              ),

              // Settings button con GlobalKey
              Positioned(
                right: 24,
                top: 16,
                child: GestureDetector(
                  key: _settingsButtonKey,
                  onTap: _showSettingsPopup,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      // ✅ Blanco puro en claro, gris oscuro en dark
                      color: (isDark ? AppColors.surfaceDark : Colors.white)
                          .withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? AppColors.shadowDark
                              : AppColors.shadowLight,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: SvgPicture.asset(
                          'assets/icons/setting.svg',
                          colorFilter: ColorFilter.mode(
                            colorScheme.onSurface.withValues(alpha: 0.9),
                            BlendMode.srcIn,
                          ),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 52),

          // User info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userEmail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Statistics container - MINIMALISTA
          _buildStatistics(),

          const SizedBox(height: 24),

          // Botón dinámico: Guardar (modo edición) o Cerrar Sesión (modo normal)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: _isEditMode
                  ? ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isEditMode = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Cambios guardados'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Guardar Cambios',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: authProvider.isLoading
                          ? null
                          : () => _showLogoutDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: authProvider.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Cerrar Sesión',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ========== SETTINGS POPUP ==========
  void _showSettingsPopup() {
    final RenderBox? button =
        _settingsButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (button == null) return;

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = context.read<ThemeProvider>();

    const double menuWidth = 200;

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
      // ✅ Blanco puro en claro, gris oscuro en dark
      color: isDark ? AppColors.surfaceDark : Colors.white,
      items: [
        // Opción Editar
        PopupMenuItem<String>(
          value: 'edit',
          height: 56,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.edit_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Editar Perfil',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Divisor
        PopupMenuItem<String>(
          enabled: false,
          height: 1,
          padding: EdgeInsets.zero,
          child: Divider(
            height: 1,
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
        ),

        // Opción Cambiar Tema
        PopupMenuItem<String>(
          value: 'theme',
          height: 56,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode
                      ? AppColors.warning.withValues(alpha: 0.1)
                      : AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  themeProvider.isDarkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: themeProvider.isDarkMode
                      ? AppColors.warning
                      : AppColors.info,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  themeProvider.isDarkMode ? 'Modo Claro' : 'Modo Oscuro',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Indicador visual del tema actual
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode
                      ? AppColors.warning
                      : AppColors.info,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit') {
        setState(() {
          _isEditMode = true;
        });
      } else if (value == 'theme') {
        themeProvider.toggleTheme();
      }
    });
  }

  // ========== COVER PHOTO ==========
  Widget _buildCoverPhoto(String? coverUrl, bool isUpdating) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: _isEditMode && !isUpdating
          ? () => _pickImage(isProfile: false)
          : null,
      child: Stack(
        children: [
          Container(
            height: 140,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              image: coverUrl != null
                  ? DecorationImage(
                      image: NetworkImage(coverUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: coverUrl == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 40,
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Agregar portada',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
          // Indicador de edición
          if (_isEditMode && !isUpdating)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      // ✅ Blanco puro en claro, gris oscuro en dark
                      color: (isDark ? AppColors.surfaceDark : Colors.white)
                          .withValues(alpha: 0.95),
                      shape: BoxShape.circle,
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/image_edit.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onSurface.withValues(alpha: 0.9),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Loading overlay
          if (isUpdating)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ========== AVATAR ==========
  Widget _buildAvatar(String? userPhotoUrl, bool isUpdating) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: _isEditMode && !isUpdating
          ? () => _pickImage(isProfile: true)
          : null,
      child: Stack(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: Border.all(
                // ✅ Blanco puro en claro, gris oscuro en dark
                color: isDark ? AppColors.surfaceDark : Colors.white,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? AppColors.shadowDark : AppColors.shadowLight,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              image: userPhotoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(userPhotoUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: userPhotoUrl == null
                ? Icon(
                    Icons.person_outline,
                    size: 40,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  )
                : null,
          ),
          // Indicador de edición
          if (_isEditMode && !isUpdating)
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  // ✅ Blanco puro en claro, gris oscuro en dark
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  width: 4,
                ),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    // ✅ Blanco puro en claro, gris oscuro en dark
                    color: (isDark ? AppColors.surfaceDark : Colors.white)
                        .withValues(alpha: 0.95),
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/image_edit.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      colorScheme.onSurface.withValues(alpha: 0.9),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
          // Loading overlay
          if (isUpdating)
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(
                  // ✅ Blanco puro en claro, gris oscuro en dark
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  width: 4,
                ),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ========== STATISTICS - MINIMALISTA ==========
  Widget _buildStatistics() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        // ✅ Blanco puro en claro, gris oscuro en dark
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/book_open.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      colorScheme.onSurface.withValues(alpha: 0.9),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '0',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Libros leídos',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 44,
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/clock.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      colorScheme.onSurface.withValues(alpha: 0.9),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '0',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Minutos',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== PICK IMAGE ==========
  Future<void> _pickImage({required bool isProfile}) async {
    try {
      // 1. Verificar permisos
      final hasPermission = await _requestPermission();
      if (!hasPermission) {
        _showPermissionDialog();
        return;
      }

      // 2. Seleccionar imagen
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (pickedFile == null) return;

      // 3. Leer bytes de la imagen
      final imageBytes = await File(pickedFile.path).readAsBytes();

      if (!mounted) return;

      // 4. Mostrar crop editor
      await _showCropDialog(imageBytes: imageBytes, isProfile: isProfile);
    } catch (e) {
      debugPrint('❌ Error al seleccionar imagen: $e');
      if (mounted) {
        _showErrorSnackBar('Error al seleccionar la imagen');
      }
    }
  }

  // ========== CROP DIALOG ==========
  Future<void> _showCropDialog({
    required Uint8List imageBytes,
    required bool isProfile,
  }) async {
    final cropController = CropController();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  color: isDark ? AppColors.grey850 : AppColors.grey900,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                      const Spacer(),
                      Text(
                        isProfile ? 'Recortar Perfil' : 'Recortar Portada',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => cropController.crop(),
                        child: const Text(
                          'Guardar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Crop area
                Expanded(
                  child: Crop(
                    controller: cropController,
                    image: imageBytes,
                    aspectRatio: isProfile ? 1.0 : 16 / 9,
                    initialSize: 0.8,
                    baseColor: Colors.black,
                    maskColor: Colors.black.withValues(alpha: 0.6),
                    radius: 0,
                    withCircleUi: isProfile,
                    onCropped: (croppedData) async {
                      Navigator.pop(dialogContext);
                      await _saveCroppedImage(
                        croppedData,
                        isProfile: isProfile,
                      );
                    },
                    cornerDotBuilder: (size, edgeAlignment) => Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
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

  // ========== SAVE CROPPED IMAGE ==========
  Future<void> _saveCroppedImage(
    Uint8List croppedData, {
    required bool isProfile,
  }) async {
    try {
      final authProvider = context.read<AuthProvider>();

      // Guardar temporalmente
      final tempDir = Directory.systemTemp;
      final fileName = 'cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(croppedData);

      if (!mounted) return;

      // Subir a Firebase
      bool success;
      if (isProfile) {
        success = await authProvider.updateProfilePhoto(tempFile);
      } else {
        success = await authProvider.updateCoverPhoto(tempFile);
      }

      if (!mounted) return;

      if (success) {}
    } catch (e) {
      debugPrint('❌ Error en _saveCroppedImage: $e');
      if (mounted) {
        _showErrorSnackBar('Error al procesar la imagen: $e');
      }
    }
  }

  // ========== PERMISOS ==========
  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        final status = await Permission.photos.status;
        if (status.isGranted) return true;
        if (status.isDenied) {
          final result = await Permission.photos.request();
          return result.isGranted;
        }
        if (status.isPermanentlyDenied) {
          _showPermissionDialog();
          return false;
        }
        return false;
      } else {
        final status = await Permission.storage.status;
        if (status.isGranted) return true;
        if (status.isDenied) {
          final result = await Permission.storage.request();
          return result.isGranted;
        }
        if (status.isPermanentlyDenied) {
          _showPermissionDialog();
          return false;
        }
        return false;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.status;
      if (status.isGranted) return true;
      if (status.isDenied) {
        final result = await Permission.photos.request();
        return result.isGranted;
      }
      if (status.isPermanentlyDenied) {
        _showPermissionDialog();
        return false;
      }
      return false;
    }
    return true;
  }

  void _showPermissionDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // ✅ Blanco puro en claro, gris oscuro en dark
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Permiso Requerido', style: theme.textTheme.titleLarge),
        content: Text(
          'La app necesita acceso a tus fotos para cambiar tu imagen de perfil.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Configuración'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ========== LOGOUT DIALOG ==========
  void _showLogoutDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = context.read<AuthProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          // ✅ Blanco puro en claro, gris oscuro en dark
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('Cerrar Sesión', style: theme.textTheme.titleLarge),
          content: Text(
            '¿Estás seguro de que deseas cerrar sesión?',
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                if (!mounted) return;
                Navigator.pop(context);
                await authProvider.logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
