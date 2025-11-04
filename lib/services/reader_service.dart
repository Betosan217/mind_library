import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/highlight_model.dart';
import '../models/bookmark_model.dart';

class ReaderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== HIGHLIGHTS ====================

  // Crear subrayado
  Future<String> createHighlight(HighlightModel highlight) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('highlights')
          .add(highlight.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear subrayado: $e');
    }
  }

  // Obtener subrayados de un libro
  Stream<List<HighlightModel>> getBookHighlights(String bookId) {
    return _firestore
        .collection('highlights')
        .where('bookId', isEqualTo: bookId)
        .orderBy('pageNumber')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => HighlightModel.fromFirestore(doc))
              .toList();
        });
  }

  // Obtener subrayados de una página específica
  Stream<List<HighlightModel>> getPageHighlights(
    String bookId,
    int pageNumber,
  ) {
    return _firestore
        .collection('highlights')
        .where('bookId', isEqualTo: bookId)
        .where('pageNumber', isEqualTo: pageNumber)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => HighlightModel.fromFirestore(doc))
              .toList();
        });
  }

  // Eliminar subrayado
  Future<void> deleteHighlight(String highlightId) async {
    try {
      await _firestore.collection('highlights').doc(highlightId).delete();
    } catch (e) {
      throw Exception('Error al eliminar subrayado: $e');
    }
  }

  // Eliminar todos los subrayados de un libro
  Future<void> deleteBookHighlights(String bookId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('highlights')
          .where('bookId', isEqualTo: bookId)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      throw Exception('Error al eliminar subrayados: $e');
    }
  }

  // ==================== BOOKMARKS ====================

  // Crear marcador
  Future<String> createBookmark(BookmarkModel bookmark) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('bookmarks')
          .add(bookmark.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear marcador: $e');
    }
  }

  // Obtener marcadores de un libro
  Stream<List<BookmarkModel>> getBookBookmarks(String bookId) {
    return _firestore
        .collection('bookmarks')
        .where('bookId', isEqualTo: bookId)
        .orderBy('pageNumber')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BookmarkModel.fromFirestore(doc))
              .toList();
        });
  }

  // Verificar si una página tiene marcador
  Future<BookmarkModel?> getBookmarkByPage(
    String bookId,
    int pageNumber,
  ) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('bookmarks')
          .where('bookId', isEqualTo: bookId)
          .where('pageNumber', isEqualTo: pageNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return BookmarkModel.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Eliminar marcador
  Future<void> deleteBookmark(String bookmarkId) async {
    try {
      await _firestore.collection('bookmarks').doc(bookmarkId).delete();
    } catch (e) {
      throw Exception('Error al eliminar marcador: $e');
    }
  }

  // Eliminar marcador por página
  Future<void> deleteBookmarkByPage(String bookId, int pageNumber) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('bookmarks')
          .where('bookId', isEqualTo: bookId)
          .where('pageNumber', isEqualTo: pageNumber)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      throw Exception('Error al eliminar marcador: $e');
    }
  }

  // ==================== READING PROGRESS ====================

  // Guardar última página leída
  Future<void> saveLastPage(String bookId, int pageNumber) async {
    try {
      await _firestore.collection('books').doc(bookId).update({
        'lastPageRead': pageNumber,
        'lastReadAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Si falla, no detener la lectura
      throw Exception('Error al guardar página: $e');
    }
  }

  // Obtener última página leída
  Future<int?> getLastPage(String bookId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('books')
          .doc(bookId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['lastPageRead'] as int?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
