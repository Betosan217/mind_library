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

  List<BookModel> _books = [];
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;
  BookModel? _selectedBook;

  // 🆕 Variable para saber qué stream está activo
  String? _currentStreamType; // 'all' o 'folder'
  String? _currentFolderId;

  List<BookModel> get books => _books;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String? get errorMessage => _errorMessage;
  BookModel? get selectedBook => _selectedBook;

  // Stream de libros
  StreamSubscription<List<BookModel>>? _booksSubscription;

  // Inicializar stream de TODOS los libros del usuario (para HomeScreen)
  void initBooksStream(String userId) {
    // Si ya estamos escuchando todos los libros, no hacer nada
    if (_currentStreamType == 'all') {
      return;
    }

    // 🔥 LIMPIAR LA LISTA INMEDIATAMENTE
    _books = [];
    _currentStreamType = 'all';
    _currentFolderId = null;
    notifyListeners();

    // Cancelar subscription anterior si existe
    _booksSubscription?.cancel();

    // Crear nuevo subscription que escucha cambios en tiempo real
    _booksSubscription = _firestoreService
        .getUserBooks(userId)
        .listen(
          (books) {
            _books = books;
            notifyListeners();
          },
          onError: (error) {
            _errorMessage = error.toString();
            notifyListeners();
          },
        );
  }

  // Inicializar stream de libros de una carpeta específica (para FolderDetailScreen)
  void initFolderBooksStream(String folderId) {
    // Si ya estamos escuchando esta carpeta, no hacer nada
    if (_currentStreamType == 'folder' && _currentFolderId == folderId) {
      return;
    }

    // 🔥 LIMPIAR LA LISTA INMEDIATAMENTE
    _books = [];
    _currentStreamType = 'folder';
    _currentFolderId = folderId;
    notifyListeners();

    // Cancelar el subscription anterior si existe
    _booksSubscription?.cancel();

    // Crear nuevo subscription
    _booksSubscription = _firestoreService
        .getFolderBooks(folderId)
        .listen(
          (books) {
            _books = books;
            notifyListeners();
          },
          onError: (error) {
            _errorMessage = error.toString();
            notifyListeners();
          },
        );
  }

  // Detener el stream (útil al cerrar sesión)
  void stopBooksStream() {
    _booksSubscription?.cancel();
    _booksSubscription = null;
    _books = [];
    _currentStreamType = null;
    _currentFolderId = null;
    notifyListeners();
  }

  // Crear libro (con subida de PDF)
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

  // Actualizar libro
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

  // Actualizar progreso de lectura
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

  // Eliminar libro
  Future<bool> deleteBook(String bookId, String folderId, String pdfUrl) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Eliminar PDF de Storage
      await _storageService.deleteFile(pdfUrl);

      // Eliminar de Firestore
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

  // Seleccionar libro
  void selectBook(BookModel book) {
    _selectedBook = book;
    notifyListeners();
  }

  // Limpiar selección
  void clearSelection() {
    _selectedBook = null;
    notifyListeners();
  }

  // Buscar libros
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

  // Obtener estadísticas
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

  // Filtrar libros por estado
  List<BookModel> getBooksByStatus(ReadingStatus status) {
    return _books.where((book) => book.status == status).toList();
  }

  // Obtener libros recientes
  List<BookModel> get recentBooks {
    List<BookModel> sortedBooks = List.from(_books);
    sortedBooks.sort((a, b) {
      if (b.lastReadAt == null) return -1;
      if (a.lastReadAt == null) return 1;
      return b.lastReadAt!.compareTo(a.lastReadAt!);
    });
    return sortedBooks.take(5).toList();
  }

  // Limpiar error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _booksSubscription?.cancel();
    super.dispose();
  }
}
