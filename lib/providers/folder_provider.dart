import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/folder_model.dart';
import '../services/firestore_service.dart';

class FolderProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<FolderModel> _folders = [];
  bool _isLoading = false;
  String? _errorMessage;
  FolderModel? _selectedFolder;

  List<FolderModel> get folders => _folders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  FolderModel? get selectedFolder => _selectedFolder;

  // Stream de carpetas del usuario
  StreamSubscription<List<FolderModel>>? _foldersSubscription;
  bool _isStreamActive = false;

  // ✅ CORREGIDO: Inicializar stream con el userId directamente
  void initFoldersStream() {
    // Prevenir múltiples inicializaciones
    if (_isStreamActive) {
      debugPrint('⚠️ Stream ya está activo, ignorando...');
      return;
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      debugPrint('❌ Error: Usuario no autenticado al iniciar stream');
      return;
    }

    debugPrint('🔵 Iniciando stream de carpetas para usuario: $userId');

    // Cancelar subscription anterior si existe
    _foldersSubscription?.cancel();

    // Marcar como activo
    _isStreamActive = true;

    // Crear nuevo subscription que escucha cambios en tiempo real
    _foldersSubscription = _firestoreService
        .getUserFolders(userId)
        .listen(
          (folders) {
            debugPrint('📦 Stream recibió ${folders.length} carpetas');
            _folders = folders;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('❌ Error en stream: $error');
            _errorMessage = error.toString();
            _isStreamActive = false;
            notifyListeners();
          },
          onDone: () {
            debugPrint('✅ Stream completado');
            _isStreamActive = false;
          },
        );
  }

  // Detener el stream (útil al cerrar sesión)
  void stopFoldersStream() {
    debugPrint('🔴 Deteniendo stream de carpetas');
    _foldersSubscription?.cancel();
    _foldersSubscription = null;
    _folders = [];
    _isStreamActive = false;
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint('🗑️ Disposing FolderProvider');
    _foldersSubscription?.cancel();
    super.dispose();
  }

  // Crear carpeta
  Future<bool> createFolder(FolderModel folder) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      debugPrint('📝 Creando carpeta: ${folder.name}');
      final folderId = await _firestoreService.createFolder(folder);
      debugPrint('✅ Carpeta creada con ID: $folderId');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error al crear carpeta: $e');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Actualizar carpeta
  Future<bool> updateFolder(String folderId, FolderModel folder) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firestoreService.updateFolder(folderId, folder);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Eliminar carpeta
  Future<bool> deleteFolder(String folderId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firestoreService.deleteFolder(folderId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Seleccionar carpeta
  void selectFolder(FolderModel folder) {
    _selectedFolder = folder;
    notifyListeners();
  }

  // Limpiar selección
  void clearSelection() {
    _selectedFolder = null;
    notifyListeners();
  }

  // Obtener carpeta por ID
  Future<FolderModel?> getFolderById(String folderId) async {
    try {
      return await _firestoreService.getFolderById(folderId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Limpiar error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Obtener cantidad de carpetas
  int get foldersCount => _folders.length;

  // Obtener total de libros en todas las carpetas
  int get totalBooks {
    return _folders.fold(0, (sum, folder) => sum + folder.bookCount);
  }
}
