import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/folder_model.dart';
import '../models/book_model.dart';
import '../models/note_model.dart';
import 'storage_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService = StorageService();

  // ==================== FOLDERS ====================

  // ✅ SOLUCIÓN DEFINITIVA - Solo campos de FolderModel
  Future<String> createFolder(FolderModel folder) async {
    try {
      // 1. Generar ID primero
      DocumentReference docRef = _firestore.collection('folders').doc();

      // 2. Crear el map exactamente con los campos de tu modelo
      final now = DateTime.now();
      final folderData = {
        'userId': folder.userId,
        'name': folder.name,
        // ignore: deprecated_member_use
        'colorValue': folder.color.value,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'bookCount': 0, // Siempre inicia en 0
      };

      // 3. Guardar en Firestore
      await docRef.set(folderData);

      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear carpeta: $e');
    }
  }

  // Obtener carpetas del usuario
  Stream<List<FolderModel>> getUserFolders(String userId) {
    return _firestore
        .collection('folders')
        .where('userId', isEqualTo: userId)
        // ⚠️ Quitamos orderBy temporalmente hasta crear el índice
        .snapshots()
        .map((snapshot) {
          // Ordenamos en el código en lugar de en la consulta
          var folders = snapshot.docs
              .map((doc) => FolderModel.fromFirestore(doc))
              .toList();

          folders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return folders;
        });
  }

  // Obtener una carpeta por ID
  Future<FolderModel?> getFolderById(String folderId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('folders')
          .doc(folderId)
          .get();
      if (doc.exists) {
        return FolderModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener carpeta: $e');
    }
  }

  // Actualizar carpeta
  Future<void> updateFolder(String folderId, FolderModel folder) async {
    try {
      await _firestore
          .collection('folders')
          .doc(folderId)
          .update(folder.toUpdateMap());
    } catch (e) {
      throw Exception('Error al actualizar carpeta: $e');
    }
  }

  // Eliminar carpeta
  Future<void> deleteFolder(String folderId) async {
    try {
      QuerySnapshot books = await _firestore
          .collection('books')
          .where('folderId', isEqualTo: folderId)
          .get();

      for (var doc in books.docs) {
        BookModel book = BookModel.fromFirestore(doc);

        if (book.pdfUrl.isNotEmpty) {
          try {
            await _storageService.deleteFile(book.pdfUrl);
          } catch (e) {
            // Continuar aunque falle
          }
        }

        if (book.coverUrl != null && book.coverUrl!.isNotEmpty) {
          try {
            await _storageService.deleteFile(book.coverUrl!);
          } catch (e) {
            // Continuar aunque falle
          }
        }
      }

      WriteBatch batch = _firestore.batch();

      for (var doc in books.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(_firestore.collection('folders').doc(folderId));

      await batch.commit();
    } catch (e) {
      throw Exception('Error al eliminar carpeta: $e');
    }
  }

  // Incrementar contador de libros
  Future<void> incrementFolderBookCount(String folderId, int increment) async {
    try {
      await _firestore.collection('folders').doc(folderId).update({
        'bookCount': FieldValue.increment(increment),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al actualizar contador de libros: $e');
    }
  }

  // Actualizar contador de libros
  Future<void> updateFolderBookCount(String folderId) async {
    try {
      QuerySnapshot books = await _firestore
          .collection('books')
          .where('folderId', isEqualTo: folderId)
          .get();

      int bookCount = books.docs.length;

      await _firestore.collection('folders').doc(folderId).update({
        'bookCount': bookCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al actualizar contador de libros: $e');
    }
  }

  // ==================== BOOKS ====================

  // ✅ CORREGIDO para libros también
  Future<String> createBook(BookModel book) async {
    try {
      WriteBatch batch = _firestore.batch();

      // 1. Generar ID del libro
      DocumentReference bookRef = _firestore.collection('books').doc();

      // 2. Crear map del libro con timestamp real
      final now = DateTime.now();
      final bookData = {
        'userId': book.userId,
        'folderId': book.folderId,
        'title': book.title,
        'coverUrl': book.coverUrl,
        'pdfUrl': book.pdfUrl,
        'totalPages': book.totalPages,
        'currentPage': book.currentPage,
        'progress': book.progress,
        'status': book.status.toString().split('.').last,
        'createdAt': Timestamp.fromDate(now),
        'lastReadAt': Timestamp.fromDate(book.lastReadAt ?? now),
        'updatedAt': Timestamp.fromDate(now),
      };

      batch.set(bookRef, bookData);

      // 3. Incrementar contador de la carpeta
      DocumentReference folderRef = _firestore
          .collection('folders')
          .doc(book.folderId);
      batch.update(folderRef, {
        'bookCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      return bookRef.id;
    } catch (e) {
      throw Exception('Error al crear libro: $e');
    }
  }

  // Obtener libros de una carpeta
  Stream<List<BookModel>> getFolderBooks(String folderId) {
    return _firestore
        .collection('books')
        .where('folderId', isEqualTo: folderId)
        .snapshots()
        .map((snapshot) {
          var books = snapshot.docs
              .map((doc) => BookModel.fromFirestore(doc))
              .toList();

          books.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return books;
        });
  }

  // Obtener todos los libros del usuario
  Stream<List<BookModel>> getUserBooks(String userId) {
    return _firestore
        .collection('books')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          var books = snapshot.docs
              .map((doc) => BookModel.fromFirestore(doc))
              .toList();

          books.sort((a, b) {
            if (b.lastReadAt == null) return -1;
            if (a.lastReadAt == null) return 1;
            return b.lastReadAt!.compareTo(a.lastReadAt!);
          });
          return books;
        });
  }

  // Obtener libro por ID
  Future<BookModel?> getBookById(String bookId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('books')
          .doc(bookId)
          .get();
      if (doc.exists) {
        return BookModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener libro: $e');
    }
  }

  // Actualizar libro
  Future<void> updateBook(String bookId, BookModel book) async {
    try {
      await _firestore
          .collection('books')
          .doc(bookId)
          .update(book.toUpdateMap());
    } catch (e) {
      throw Exception('Error al actualizar libro: $e');
    }
  }

  // Actualizar progreso de lectura
  Future<void> updateReadingProgress(
    String bookId,
    int currentPage,
    int totalPages,
  ) async {
    try {
      double progress = totalPages > 0 ? currentPage / totalPages : 0.0;
      ReadingStatus status = ReadingStatus.unread;

      if (progress >= 1.0) {
        status = ReadingStatus.finished;
      } else if (progress > 0) {
        status = ReadingStatus.reading;
      }

      await _firestore.collection('books').doc(bookId).update({
        'currentPage': currentPage,
        'progress': progress,
        'status': status.toString().split('.').last,
        'lastReadAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al actualizar progreso: $e');
    }
  }

  // Eliminar libro
  Future<void> deleteBook(String bookId, String folderId) async {
    try {
      DocumentSnapshot bookDoc = await _firestore
          .collection('books')
          .doc(bookId)
          .get();

      if (bookDoc.exists) {
        BookModel book = BookModel.fromFirestore(bookDoc);

        if (book.pdfUrl.isNotEmpty) {
          try {
            await _storageService.deleteFile(book.pdfUrl);
          } catch (e) {
            // Continuar aunque falle
          }
        }

        if (book.coverUrl != null && book.coverUrl!.isNotEmpty) {
          try {
            await _storageService.deleteFile(book.coverUrl!);
          } catch (e) {
            // Continuar aunque falle
          }
        }
      }

      WriteBatch batch = _firestore.batch();

      batch.delete(_firestore.collection('books').doc(bookId));

      DocumentReference folderRef = _firestore
          .collection('folders')
          .doc(folderId);
      batch.update(folderRef, {
        'bookCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Error al eliminar libro: $e');
    }
  }

  // Buscar libros por título
  Future<List<BookModel>> searchBooks(String userId, String query) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('books')
          .where('userId', isEqualTo: userId)
          .get();

      List<BookModel> books = snapshot.docs
          .map((doc) => BookModel.fromFirestore(doc))
          .where(
            (book) => book.title.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();

      return books;
    } catch (e) {
      throw Exception('Error al buscar libros: $e');
    }
  }

  // Obtener estadísticas del usuario
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      QuerySnapshot books = await _firestore
          .collection('books')
          .where('userId', isEqualTo: userId)
          .get();

      int totalBooks = books.docs.length;
      int booksReading = books.docs.where((doc) {
        BookModel book = BookModel.fromFirestore(doc);
        return book.status == ReadingStatus.reading;
      }).length;
      int booksFinished = books.docs.where((doc) {
        BookModel book = BookModel.fromFirestore(doc);
        return book.status == ReadingStatus.finished;
      }).length;

      return {
        'totalBooks': totalBooks,
        'booksReading': booksReading,
        'booksFinished': booksFinished,
        'booksUnread': totalBooks - booksReading - booksFinished,
      };
    } catch (e) {
      throw Exception('Error al obtener estadísticas: $e');
    }
  }

  Future<String> createNote(NoteModel note) async {
    try {
      DocumentReference docRef = _firestore.collection('notes').doc();

      final now = DateTime.now();
      final noteData = {
        'userId': note.userId,
        'bookId': note.bookId,
        'folderId': note.folderId,
        'pageNumber': note.pageNumber,
        'title': note.title,
        'content': note.content,
        'category': note.category,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      await docRef.set(noteData);
      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear nota: $e');
    }
  }

  // Obtener todas las notas del usuario
  Stream<List<NoteModel>> getUserNotes(String userId) {
    return _firestore
        .collection('notes')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          var notes = snapshot.docs
              .map((doc) => NoteModel.fromFirestore(doc))
              .toList();

          // Ordenar por fecha de creación (más reciente primero)
          notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notes;
        });
  }

  // Obtener notas de un libro específico
  Stream<List<NoteModel>> getBookNotes(String bookId) {
    return _firestore
        .collection('notes')
        .where('bookId', isEqualTo: bookId)
        .snapshots()
        .map((snapshot) {
          var notes = snapshot.docs
              .map((doc) => NoteModel.fromFirestore(doc))
              .toList();

          // Ordenar por número de página (si existe), luego por fecha
          notes.sort((a, b) {
            if (a.pageNumber != null && b.pageNumber != null) {
              return a.pageNumber!.compareTo(b.pageNumber!);
            }
            return b.createdAt.compareTo(a.createdAt);
          });
          return notes;
        });
  }

  // Obtener notas de una página específica de un libro
  Stream<List<NoteModel>> getPageNotes(String bookId, int pageNumber) {
    return _firestore
        .collection('notes')
        .where('bookId', isEqualTo: bookId)
        .where('pageNumber', isEqualTo: pageNumber)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NoteModel.fromFirestore(doc))
              .toList();
        });
  }

  // Verificar si una página tiene notas
  Future<bool> hasNotesOnPage(String bookId, int pageNumber) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('notes')
          .where('bookId', isEqualTo: bookId)
          .where('pageNumber', isEqualTo: pageNumber)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Obtener nota por ID
  Future<NoteModel?> getNoteById(String noteId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('notes')
          .doc(noteId)
          .get();

      if (doc.exists) {
        return NoteModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener nota: $e');
    }
  }

  // Actualizar nota
  Future<void> updateNote(String noteId, NoteModel note) async {
    try {
      await _firestore
          .collection('notes')
          .doc(noteId)
          .update(note.toUpdateMap());
    } catch (e) {
      throw Exception('Error al actualizar nota: $e');
    }
  }

  // Eliminar nota
  Future<void> deleteNote(String noteId) async {
    try {
      await _firestore.collection('notes').doc(noteId).delete();
    } catch (e) {
      throw Exception('Error al eliminar nota: $e');
    }
  }

  // Eliminar todas las notas de un libro
  Future<void> deleteBookNotes(String bookId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('notes')
          .where('bookId', isEqualTo: bookId)
          .get();

      WriteBatch batch = _firestore.batch();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Error al eliminar notas del libro: $e');
    }
  }

  // Buscar notas por texto (título o contenido)
  Future<List<NoteModel>> searchNotes(String userId, String query) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('notes')
          .where('userId', isEqualTo: userId)
          .get();

      List<NoteModel> notes = snapshot.docs
          .map((doc) => NoteModel.fromFirestore(doc))
          .where(
            (note) =>
                note.title.toLowerCase().contains(query.toLowerCase()) ||
                note.content.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();

      return notes;
    } catch (e) {
      throw Exception('Error al buscar notas: $e');
    }
  }

  // Obtener estadísticas de notas
  Future<Map<String, dynamic>> getNotesStats(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('notes')
          .where('userId', isEqualTo: userId)
          .get();

      int totalNotes = snapshot.docs.length;
      int notesWithPage = snapshot.docs.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['pageNumber'] != null;
      }).length;

      return {
        'totalNotes': totalNotes,
        'notesWithPage': notesWithPage,
        'notesWithoutPage': totalNotes - notesWithPage,
      };
    } catch (e) {
      throw Exception('Error al obtener estadísticas de notas: $e');
    }
  }
}
