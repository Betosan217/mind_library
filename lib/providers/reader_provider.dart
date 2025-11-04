import 'package:flutter/material.dart';
import '../services/reader_service.dart';

class ReaderProvider with ChangeNotifier {
  final ReaderService _readerService = ReaderService();

  // Estado
  int _currentPage = 1;
  int _totalPages = 0;
  String? _errorMessage;

  // Configuración de lectura
  bool _nightMode = false;
  double _brightness = 0.5;
  bool _controlsLocked = false;

  // Getters básicos
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  String? get errorMessage => _errorMessage;
  double get progress => _totalPages > 0 ? _currentPage / _totalPages : 0.0;

  // Getters de configuración
  bool get nightMode => _nightMode;
  double get brightness => _brightness;
  bool get controlsLocked => _controlsLocked;

  // Setters de configuración
  void setNightMode(bool value) {
    _nightMode = value;
    notifyListeners();
  }

  void setBrightness(double value) {
    _brightness = value;
    notifyListeners();
  }

  void toggleControlsLock() {
    _controlsLocked = !_controlsLocked;
    notifyListeners();
  }

  // Inicializar streams (vacío por ahora)
  void initStreams(String bookId) {
    // Sin streams de bookmarks/highlights
  }

  // Cargar última página leída
  Future<void> loadLastPage(String bookId) async {
    try {
      int? lastPage = await _readerService.getLastPage(bookId);
      if (lastPage != null) {
        _currentPage = lastPage;
        notifyListeners();
      }
    } catch (e) {
      // Ignorar error, empezar desde página 1
    }
  }

  // Actualizar página actual
  void updateCurrentPage(int page) {
    _currentPage = page;
    notifyListeners();
  }

  // Actualizar total de páginas
  void updateTotalPages(int total) {
    _totalPages = total;
    notifyListeners();
  }

  // Guardar progreso
  Future<void> saveProgress(String bookId) async {
    try {
      await _readerService.saveLastPage(bookId, _currentPage);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Reiniciar progreso de lectura
  Future<void> resetProgress(String bookId) async {
    try {
      _currentPage = 1;
      await _readerService.saveLastPage(bookId, 1);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Limpiar error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
