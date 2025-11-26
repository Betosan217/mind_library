import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:io';
import '../models/book_model.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class BookProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🆕 NUEVO: Libros globales (para HomeScreen - todos los libros del usuario)
  List<BookModel> _allBooks = [];

  // 🆕 NUEVO: Múltiples listas de libros por carpeta (para FolderDetailScreen)
  final Map<String, List<BookModel>> _booksByFolderMap = {};

  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;
  BookModel? _selectedBook;

  // Getters
  List<BookModel> get books => _allBooks; // Para HomeScreen
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String? get errorMessage => _errorMessage;
  BookModel? get selectedBook => _selectedBook;

  // 🆕 Getter para libros de una carpeta específica
  List<BookModel> getBooksForFolder(String folderId) {
    return _booksByFolderMap[folderId] ?? [];
  }

  // Streams
  StreamSubscription<List<BookModel>>? _allBooksSubscription;
  final Map<String, StreamSubscription<List<BookModel>>>
  _folderBooksSubscriptions = {};

  // =====================================================
  // STREAM DE TODOS LOS LIBROS (Solo para HomeScreen)
  // =====================================================
  void initBooksStream(String userId) {
    // Si ya existe, no crear otro
    if (_allBooksSubscription != null) {
      debugPrint('⚠️ Stream de todos los libros ya activo');
      return;
    }

    debugPrint('🔵 Iniciando stream de TODOS los libros');

    _allBooksSubscription = _firestoreService
        .getUserBooks(userId)
        .listen(
          (books) {
            debugPrint('📦 Recibidos ${books.length} libros totales');
            _allBooks = books;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('❌ Error en stream de libros: $error');
            _errorMessage = error.toString();
            notifyListeners();
          },
        );
  }

  // =====================================================
  // STREAM DE LIBROS DE CARPETA (Para FolderDetailScreen)
  // =====================================================
  void initFolderBooksStream(String folderId) {
    debugPrint('🔵 Iniciando stream de libros para carpeta: $folderId');

    // Si ya existe un stream para esta carpeta, no crear otro
    if (_folderBooksSubscriptions.containsKey(folderId)) {
      debugPrint('⚠️ Stream ya existe para carpeta $folderId');
      return;
    }

    // Crear nuevo stream para esta carpeta específica
    _folderBooksSubscriptions[folderId] = _firestoreService
        .getFolderBooks(folderId)
        .listen(
          (books) {
            debugPrint(
              '📦 Recibidos ${books.length} libros para carpeta $folderId',
            );
            _booksByFolderMap[folderId] = books;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('❌ Error en stream de libros de carpeta: $error');
            _errorMessage = error.toString();
            notifyListeners();
          },
        );
  }

  // =====================================================
  // DETENER STREAM DE LIBROS DE CARPETA (Al salir de FolderDetail)
  // =====================================================
  void stopFolderBooksStream(String folderId) {
    debugPrint('🔴 Deteniendo stream de libros para carpeta: $folderId');

    _folderBooksSubscriptions[folderId]?.cancel();
    _folderBooksSubscriptions.remove(folderId);
    _booksByFolderMap.remove(folderId);

    notifyListeners();
  }

  // =====================================================
  // DETENER STREAM DE TODOS LOS LIBROS (Al cerrar sesión)
  // =====================================================
  void stopBooksStream() {
    debugPrint('🔴 Deteniendo stream de todos los libros');
    _allBooksSubscription?.cancel();
    _allBooksSubscription = null;
    _allBooks = [];
    notifyListeners();
  }

  // =====================================================
  // CRUD OPERATIONS
  // =====================================================

  Future<bool> createBook({
    required String folderId,
    required String title,
    required File pdfFile,
    File? coverFile,
    List<String>? tags,
  }) async {
    try {
      _isUploading = true;
      _uploadProgress = 0.0;
      _errorMessage = null;
      notifyListeners();

      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Subir PDF a Storage
      String pdfUrl = await _storageService.uploadPDF(
        file: pdfFile,
        userId: userId,
        folderId: folderId,
        onProgress: (progress) {
          _uploadProgress = progress;
          notifyListeners();
        },
      );

      // Subir portada si existe
      String? coverUrl;
      if (coverFile != null) {
        coverUrl = await _storageService.uploadCover(
          file: coverFile,
          userId: userId,
          folderId: folderId,
        );
      }

      // Obtener tamaño del archivo
      int fileSize = await pdfFile.length();

      // Crear modelo de libro
      BookModel book = BookModel(
        id: '',
        userId: userId,
        folderId: folderId,
        title: title,
        pdfUrl: pdfUrl,
        coverUrl: coverUrl,
        createdAt: DateTime.now(),
        fileSize: fileSize,
        tags: tags ?? [],
      );

      await _firestoreService.createBook(book);

      _isUploading = false;
      _uploadProgress = 0.0;
      notifyListeners();

      // 🔥 El stream automáticamente detectará el cambio y actualizará la lista
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isUploading = false;
      _uploadProgress = 0.0;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBook(String bookId, BookModel book) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firestoreService.updateBook(bookId, book);

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

  Future<bool> updateReadingProgress({
    required String bookId,
    required int currentPage,
    required int totalPages,
  }) async {
    try {
      await _firestoreService.updateReadingProgress(
        bookId,
        currentPage,
        totalPages,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBook(String bookId, String folderId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firestoreService.deleteBook(bookId, folderId);

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

  void selectBook(BookModel book) {
    _selectedBook = book;
    notifyListeners();
  }

  void clearSelection() {
    _selectedBook = null;
    notifyListeners();
  }

  Future<List<BookModel>> searchBooks(String query) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      return await _firestoreService.searchBooks(userId, query);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<Map<String, dynamic>> getUserStats() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return {};

      return await _firestoreService.getUserStats(userId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return {};
    }
  }

  List<BookModel> getBooksByStatus(ReadingStatus status) {
    return _allBooks.where((book) => book.status == status).toList();
  }

  List<BookModel> get recentBooks {
    List<BookModel> sortedBooks = List.from(_allBooks);
    sortedBooks.sort((a, b) {
      if (b.lastReadAt == null) return -1;
      if (a.lastReadAt == null) return 1;
      return b.lastReadAt!.compareTo(a.lastReadAt!);
    });
    return sortedBooks.take(5).toList();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _allBooksSubscription?.cancel();
    _folderBooksSubscriptions.forEach((_, sub) => sub.cancel());
    _folderBooksSubscriptions.clear();
    _booksByFolderMap.clear();
    super.dispose();
  }
}
