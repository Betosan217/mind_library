import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/folder_model.dart';
import '../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FolderProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Carpetas raíz (para HomeScreen)
  List<FolderModel> _folders = [];

  // 🆕 NUEVO: Múltiples listas de subcarpetas por parentId
  final Map<String, List<FolderModel>> _subFoldersMap = {};

  bool _isLoading = false;
  String? _errorMessage;
  FolderModel? _selectedFolder;

  // Getters
  List<FolderModel> get folders => _folders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  FolderModel? get selectedFolder => _selectedFolder;

  // 🆕 Getter para subcarpetas de un padre específico
  List<FolderModel> getSubFolders(String parentId) {
    return _subFoldersMap[parentId] ?? [];
  }

  // Streams
  StreamSubscription<List<FolderModel>>? _rootFoldersSubscription;
  final Map<String, StreamSubscription<List<FolderModel>>>
  _subFolderSubscriptions = {};

  // =====================================================
  // STREAM DE CARPETAS RAÍZ (Solo para HomeScreen)
  // =====================================================
  void initFoldersStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      debugPrint('❌ Error: Usuario no autenticado');
      return;
    }

    // Si ya existe, no crear otro
    if (_rootFoldersSubscription != null) {
      debugPrint('⚠️ Stream de carpetas raíz ya activo');
      return;
    }

    debugPrint('🔵 Iniciando stream de carpetas RAÍZ');

    _rootFoldersSubscription = _firestoreService
        .getUserFolders(userId)
        .listen(
          (folders) {
            debugPrint('📦 Recibidas ${folders.length} carpetas raíz');
            _folders = folders;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('❌ Error en stream raíz: $error');
            _errorMessage = error.toString();
            notifyListeners();
          },
        );
  }

  // =====================================================
  // STREAM DE SUBCARPETAS (Para FolderDetailScreen)
  // =====================================================
  void initSubFoldersStream(String parentFolderId) {
    debugPrint('🔵 Iniciando stream de subcarpetas para: $parentFolderId');

    // Si ya existe un stream para este padre, no crear otro
    if (_subFolderSubscriptions.containsKey(parentFolderId)) {
      debugPrint('⚠️ Stream ya existe para $parentFolderId');
      return;
    }

    // Crear nuevo stream para este padre específico
    _subFolderSubscriptions[parentFolderId] = _firestoreService
        .getSubFolders(parentFolderId)
        .listen(
          (subFolders) {
            debugPrint(
              '📦 Recibidas ${subFolders.length} subcarpetas para $parentFolderId',
            );
            _subFoldersMap[parentFolderId] = subFolders;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('❌ Error en stream de subcarpetas: $error');
            _errorMessage = error.toString();
            notifyListeners();
          },
        );
  }

  // =====================================================
  // DETENER STREAM DE SUBCARPETAS (Al salir de FolderDetail)
  // =====================================================
  void stopSubFoldersStream(String parentFolderId) {
    debugPrint('🔴 Deteniendo stream de subcarpetas: $parentFolderId');

    _subFolderSubscriptions[parentFolderId]?.cancel();
    _subFolderSubscriptions.remove(parentFolderId);
    _subFoldersMap.remove(parentFolderId);

    notifyListeners();
  }

  // =====================================================
  // DETENER STREAM RAÍZ (Al cerrar sesión)
  // =====================================================
  void stopFoldersStream() {
    debugPrint('🔴 Deteniendo stream de carpetas raíz');
    _rootFoldersSubscription?.cancel();
    _rootFoldersSubscription = null;
    _folders = [];
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint('🗑️ Disposing FolderProvider');
    _rootFoldersSubscription?.cancel();
    _subFolderSubscriptions.forEach((_, sub) => sub.cancel());
    _subFolderSubscriptions.clear();
    _subFoldersMap.clear();
    super.dispose();
  }

  Future<List<FolderModel>> getAllFoldersHierarchy() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      debugPrint('❌ Usuario no autenticado');
      return [];
    }

    try {
      debugPrint('📂 Cargando jerarquía completa de carpetas...');

      // Obtener TODAS las carpetas del usuario en un solo snapshot
      final snapshot = await FirebaseFirestore.instance
          .collection('folders')
          .where('userId', isEqualTo: userId)
          .get();

      final allFolders = snapshot.docs
          .map((doc) => FolderModel.fromFirestore(doc))
          .toList();

      // ✅ QUITAR ESTAS LÍNEAS (no actualizar _folders ni notificar)
      // _folders = allFolders;
      // notifyListeners();

      debugPrint(
        '✅ Cargadas ${allFolders.length} carpetas en total (raíz + todas las subcarpetas)',
      );

      // ✅ SOLO retornar, sin afectar el estado del provider
      return allFolders;
    } catch (e) {
      debugPrint('❌ Error cargando jerarquía: $e');
      _errorMessage = e.toString();
      return [];
    }
  }
  // =====================================================
  // CRUD OPERATIONS
  // =====================================================

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

  void selectFolder(FolderModel folder) {
    _selectedFolder = folder;
    notifyListeners();
  }

  void clearSelection() {
    _selectedFolder = null;
    notifyListeners();
  }

  Future<FolderModel?> getFolderById(String folderId) async {
    try {
      return await _firestoreService.getFolderById(folderId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  int get foldersCount => _folders.length;

  int get totalBooks {
    return _folders.fold(0, (int sum, folder) => sum + folder.bookCount);
  }
}
