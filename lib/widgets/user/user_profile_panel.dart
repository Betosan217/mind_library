// lib/widgets/user/user_profile_panel.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../providers/auth_provider.dart';
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
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.user?.displayName ?? 'Usuario';
    final userEmail = authProvider.user?.email ?? '';
    final userPhotoUrl =
        authProvider.customProfilePhotoUrl ?? authProvider.user?.photoURL;
    final coverPhotoUrl = authProvider.customCoverPhotoUrl;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
              color: AppColors.grey300,
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
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      color: AppColors.grey700,
                      size: 22,
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
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userEmail,
                  style: TextStyle(fontSize: 14, color: AppColors.grey600),
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
                          const SnackBar(
                            content: Text('Cambios guardados'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 1),
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
                        backgroundColor: const Color(
                          0xFFEF5350,
                        ), // Rojo más suave
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

    const double menuWidth = 160;

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      color: Colors.white,
      items: [
        PopupMenuItem<String>(
          value: 'edit',
          height: 48,
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Editar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
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
      }
    });
  }

  // ========== COVER PHOTO ==========
  Widget _buildCoverPhoto(String? coverUrl, bool isUpdating) {
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
              color: AppColors.grey200,
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
                          color: AppColors.grey400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Agregar portada',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.grey500,
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
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.black87,
                      size: 24,
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
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
              color: AppColors.grey300,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
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
                ? Icon(Icons.person_outline, size: 40, color: AppColors.grey500)
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
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.black87,
                    size: 20,
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
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ========== STATISTICS - MINIMALISTA ==========
  Widget _buildStatistics() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.book_outlined,
                    size: 24,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '0',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Libros leídos',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.grey600,
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
            color: AppColors.grey300,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.access_time_outlined,
                    size: 24,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '0',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Minutos',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.grey600,
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
                  color: Colors.black87,
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
                        color: AppColors.primary,
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

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isProfile ? 'Foto de perfil actualizada' : 'Portada actualizada',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        final errorMsg =
            authProvider.errorMessage ?? 'Error al subir la imagen';
        _showErrorSnackBar(errorMsg);
      }
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Permiso Requerido'),
        content: const Text(
          'La app necesita acceso a tus fotos para cambiar tu imagen de perfil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
      ),
    );
  }

  // ========== LOGOUT DIALOG ==========
  void _showLogoutDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppColors.grey700),
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
                backgroundColor: const Color(0xFFEF5350), // Rojo más suave
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
