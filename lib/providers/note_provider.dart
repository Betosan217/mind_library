import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/note_model.dart';
import '../services/firestore_service.dart';

class NoteProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<NoteModel> _notes = [];
  bool _isLoading = false;
  String? _errorMessage;
  NoteModel? _selectedNote;

  // Variables para controlar el stream activo
  String? _currentStreamType; // 'all', 'book', 'page'
  String? _currentBookId;
  int? _currentPageNumber;

  // Getters
  List<NoteModel> get notes => _notes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  NoteModel? get selectedNote => _selectedNote;

  // Stream de notas
  StreamSubscription<List<NoteModel>>? _notesSubscription;

  // Inicializar stream de TODAS las notas del usuario
  void initUserNotesStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      debugPrint('❌ Error: Usuario no autenticado al iniciar stream de notas');
      return;
    }

    // Si ya estamos escuchando todas las notas, no hacer nada
    if (_currentStreamType == 'all') {
      return;
    }

    // Limpiar la lista inmediatamente
    _notes = [];
    _currentStreamType = 'all';
    _currentBookId = null;
    _currentPageNumber = null;
    notifyListeners();

    // Cancelar subscription anterior si existe
    _notesSubscription?.cancel();

    debugPrint('🔵 Iniciando stream de todas las notas del usuario');

    // Crear nuevo subscription
    _notesSubscription = _firestoreService
        .getUserNotes(userId)
        .listen(
          (notes) {
            debugPrint('📦 Stream recibió ${notes.length} notas');
            _notes = notes;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('❌ Error en stream de notas: $error');
            _errorMessage = error.toString();
            notifyListeners();
          },
        );
  }

  // Inicializar stream de notas de un libro específico
  void initBookNotesStream(String bookId) {
    // Si ya estamos escuchando este libro, no hacer nada
    if (_currentStreamType == 'book' && _currentBookId == bookId) {
      return;
    }

    // Limpiar la lista inmediatamente
    _notes = [];
    _currentStreamType = 'book';
    _currentBookId = bookId;
    _currentPageNumber = null;
    notifyListeners();

    // Cancelar subscription anterior si existe
    _notesSubscription?.cancel();

    debugPrint('🔵 Iniciando stream de notas del libro: $bookId');

    // Crear nuevo subscription
    _notesSubscription = _firestoreService
        .getBookNotes(bookId)
        .listen(
          (notes) {
            debugPrint('📦 Stream recibió ${notes.length} notas del libro');
            _notes = notes;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('❌ Error en stream de notas del libro: $error');
            _errorMessage = error.toString();
            notifyListeners();
          },
        );
  }

  // Inicializar stream de notas de una página específica
  void initPageNotesStream(String bookId, int pageNumber) {
    // Si ya estamos escuchando esta página, no hacer nada
    if (_currentStreamType == 'page' &&
        _currentBookId == bookId &&
        _currentPageNumber == pageNumber) {
      return;
    }

    // Limpiar la lista inmediatamente
    _notes = [];
    _currentStreamType = 'page';
    _currentBookId = bookId;
    _currentPageNumber = pageNumber;
    notifyListeners();

    // Cancelar subscription anterior si existe
    _notesSubscription?.cancel();

    debugPrint('🔵 Iniciando stream de notas de página $pageNumber');

    // Crear nuevo subscription
    _notesSubscription = _firestoreService
        .getPageNotes(bookId, pageNumber)
        .listen(
          (notes) {
            debugPrint('📦 Stream recibió ${notes.length} notas de la página');
            _notes = notes;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('❌ Error en stream de notas de página: $error');
            _errorMessage = error.toString();
            notifyListeners();
          },
        );
  }

  // Detener el stream
  void stopNotesStream() {
    debugPrint('🔴 Deteniendo stream de notas');
    _notesSubscription?.cancel();
    _notesSubscription = null;
    _notes = [];
    _currentStreamType = null;
    _currentBookId = null;
    _currentPageNumber = null;
    notifyListeners();
  }

  // Crear nota
  Future<bool> createNote(NoteModel note) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      debugPrint('📝 Creando nota: ${note.title}');
      final noteId = await _firestoreService.createNote(note);
      debugPrint('✅ Nota creada con ID: $noteId');

      _isLoading = false;
      notifyListeners();

      // El stream automáticamente detectará el cambio y actualizará la lista
      return true;
    } catch (e) {
      debugPrint('❌ Error al crear nota: $e');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Actualizar nota
  Future<bool> updateNote(String noteId, NoteModel note) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      debugPrint('📝 Actualizando nota: $noteId');
      await _firestoreService.updateNote(noteId, note);
      debugPrint('✅ Nota actualizada');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error al actualizar nota: $e');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Eliminar nota
  Future<bool> deleteNote(String noteId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      debugPrint('🗑️ Eliminando nota: $noteId');
      await _firestoreService.deleteNote(noteId);
      debugPrint('✅ Nota eliminada');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error al eliminar nota: $e');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Seleccionar nota
  void selectNote(NoteModel note) {
    _selectedNote = note;
    notifyListeners();
  }

  // Limpiar selección
  void clearSelection() {
    _selectedNote = null;
    notifyListeners();
  }

  // Buscar notas
  Future<List<NoteModel>> searchNotes(String query) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      return await _firestoreService.searchNotes(userId, query);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return [];
    }
  }

  // Verificar si una página tiene notas
  Future<bool> hasNotesOnPage(String bookId, int pageNumber) async {
    try {
      return await _firestoreService.hasNotesOnPage(bookId, pageNumber);
    } catch (e) {
      return false;
    }
  }

  // Obtener estadísticas
  Future<Map<String, dynamic>> getNotesStats() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return {};

      return await _firestoreService.getNotesStats(userId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return {};
    }
  }

  // Obtener notas por categoría
  List<NoteModel> getNotesByCategory(String? category) {
    if (category == null) return _notes;
    return _notes.where((note) => note.category == category).toList();
  }

  // Obtener notas con página vinculada
  List<NoteModel> get notesWithPage {
    return _notes.where((note) => note.pageNumber != null).toList();
  }

  // Obtener notas sin página vinculada
  List<NoteModel> get notesWithoutPage {
    return _notes.where((note) => note.pageNumber == null).toList();
  }

  // Limpiar error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint('🗑️ Disposing NoteProvider');
    _notesSubscription?.cancel();
    super.dispose();
  }
}
