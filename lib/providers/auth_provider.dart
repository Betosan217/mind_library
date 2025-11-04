import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  User? _user;
  bool _isLoading = true; // ← MANTENER EL ORIGINAL (login, registro, etc)
  String? _errorMessage;

  // ✅ AGREGAR loadings específicos para fotos
  bool _isUpdatingProfile = false;
  bool _isUpdatingCover = false;

  // URLs personalizadas (locales en la sesión)
  String? _customProfilePhotoUrl;
  String? _customCoverPhotoUrl;

  User? get user => _user;
  bool get isLoading => _isLoading; // ← ORIGINAL para login/registro
  bool get isAuthenticated => _user != null;
  String? get errorMessage => _errorMessage;
  String? get customProfilePhotoUrl => _customProfilePhotoUrl;
  String? get customCoverPhotoUrl => _customCoverPhotoUrl;

  // ✅ Getters para loadings específicos
  bool get isUpdatingProfile => _isUpdatingProfile;
  bool get isUpdatingCover => _isUpdatingCover;

  AuthProvider() {
    _initAuth();
  }

  // ========== INICIALIZAR AUTH ==========
  void _initAuth() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      _user = user;
      _isLoading = false; // ← USAR EL ORIGINAL

      // Cargar portada cuando hay usuario
      if (user != null) {
        await _loadUserCoverPhoto();
      } else {
        // Limpiar datos al cerrar sesión
        _customProfilePhotoUrl = null;
        _customCoverPhotoUrl = null;
      }

      notifyListeners();
    });
  }

  // ========== CARGAR PORTADA DESDE FIRESTORE ==========
  Future<void> _loadUserCoverPhoto() async {
    if (_user == null) return;

    try {
      _customCoverPhotoUrl = await _authService.getCoverPhoto();
      notifyListeners();
    } catch (e) {
      debugPrint('Error al cargar portada: $e');
    }
  }

  // ========== REGISTRO ==========
  Future<bool> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      _isLoading = true; // ← USAR EL ORIGINAL
      _errorMessage = null;
      notifyListeners();

      _user = await _authService.registerWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
      );

      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _errorMessage = _getErrorMessage(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ========== LOGIN ==========
  Future<bool> login({required String email, required String password}) async {
    try {
      _isLoading = true; // ← USAR EL ORIGINAL
      _errorMessage = null;
      notifyListeners();

      _user = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _getErrorMessage(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ========== LOGOUT ==========
  Future<void> logout() async {
    try {
      await _authService.signOut();
      _user = null;
      _customProfilePhotoUrl = null;
      _customCoverPhotoUrl = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = _getErrorMessage(e.toString());
      notifyListeners();
    }
  }

  // ========== RESET PASSWORD ==========
  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true; // ← USAR EL ORIGINAL
      _errorMessage = null;
      notifyListeners();

      await _authService.resetPassword(email);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _getErrorMessage(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ========== ACTUALIZAR FOTO DE PERFIL (LOADING INDEPENDIENTE) ==========
  Future<bool> updateProfilePhoto(File imageFile) async {
    if (_user == null) return false;

    try {
      _isUpdatingProfile = true; // ← NUEVO loading específico
      notifyListeners();

      // Eliminar foto antigua si existe
      final oldPhotoUrl = _customProfilePhotoUrl ?? _user!.photoURL;
      if (oldPhotoUrl != null && oldPhotoUrl.contains('firebasestorage')) {
        await _storageService.deleteUserPhoto(oldPhotoUrl);
      }

      // Subir nueva foto
      final newPhotoUrl = await _storageService.uploadUserProfilePhoto(
        file: imageFile,
        userId: _user!.uid,
      );

      // Actualizar en Firebase Auth y Firestore
      await _authService.updateUserProfile(photoURL: newPhotoUrl);

      // Recargar usuario
      await _user!.reload();
      _user = FirebaseAuth.instance.currentUser;

      // Actualizar localmente
      _customProfilePhotoUrl = newPhotoUrl;

      _isUpdatingProfile = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error al actualizar foto de perfil: $e');
      _errorMessage = 'Error al actualizar foto de perfil';
      _isUpdatingProfile = false;
      notifyListeners();
      return false;
    }
  }

  // ========== ACTUALIZAR FOTO DE PORTADA (LOADING INDEPENDIENTE) ==========
  Future<bool> updateCoverPhoto(File imageFile) async {
    if (_user == null) return false;

    try {
      _isUpdatingCover = true; // ← NUEVO loading específico
      notifyListeners();

      // Eliminar portada antigua si existe
      if (_customCoverPhotoUrl != null &&
          _customCoverPhotoUrl!.contains('firebasestorage')) {
        await _storageService.deleteUserPhoto(_customCoverPhotoUrl!);
      }

      // Subir nueva portada
      final newCoverUrl = await _storageService.uploadUserCoverPhoto(
        file: imageFile,
        userId: _user!.uid,
      );

      // Guardar en Firestore usando el servicio
      await _authService.updateCoverPhoto(newCoverUrl);

      // Actualizar localmente
      _customCoverPhotoUrl = newCoverUrl;

      _isUpdatingCover = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error al actualizar portada: $e');
      _errorMessage = 'Error al actualizar foto de portada';
      _isUpdatingCover = false;
      notifyListeners();
      return false;
    }
  }

  // ========== LIMPIAR ERROR ==========
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ========== MENSAJES DE ERROR AMIGABLES ==========
  String _getErrorMessage(String error) {
    if (error.contains('user-not-found')) {
      return 'No existe una cuenta con este correo';
    } else if (error.contains('wrong-password')) {
      return 'Contraseña incorrecta';
    } else if (error.contains('email-already-in-use')) {
      return 'Este correo ya está registrado';
    } else if (error.contains('weak-password')) {
      return 'La contraseña debe tener al menos 6 caracteres';
    } else if (error.contains('invalid-email')) {
      return 'Correo electrónico inválido';
    } else if (error.contains('network-request-failed')) {
      return 'Error de conexión. Verifica tu internet';
    } else {
      return 'Ha ocurrido un error. Intenta nuevamente';
    }
  }
}
