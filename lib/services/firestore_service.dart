import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/folder_model.dart';
import '../models/book_model.dart';
import '../models/note_model.dart';
import 'storage_service.dart';
import '../models/task_model.dart';
import '../models/task_group_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService = StorageService();

  // ==================== FOLDERS ====================

  Future<String> createFolder(FolderModel folder) async {
    try {
      DocumentReference docRef = _firestore.collection('folders').doc();

      final now = DateTime.now();
      final folderData = {
        'userId': folder.userId,
        'name': folder.name,
        // ignore: deprecated_member_use
        'colorValue': folder.color.value,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'bookCount': 0,
        'parentId':
            folder.parentFolderId, // 👈 CORRECCIÓN: Guardar como "parentId"
      };

      await docRef.set(folderData);

      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear carpeta: $e');
    }
  }

  // 👇 MODIFICADO - Obtener SOLO carpetas raíz (sin padre)
  Stream<List<FolderModel>> getUserFolders(String userId) {
    return _firestore
        .collection('folders')
        .where('userId', isEqualTo: userId)
        .where(
          'parentId',
          isNull: true,
        ) // 👈 CORRECCIÓN: Filtrar por "parentId"
        .snapshots()
        .map((snapshot) {
          var folders = snapshot.docs
              .map((doc) => FolderModel.fromFirestore(doc))
              .toList();

          folders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return folders;
        });
  }

  // 👇 NUEVO - Obtener subcarpetas de una carpeta específica
  Stream<List<FolderModel>> getSubFolders(String parentFolderId) {
    return _firestore
        .collection('folders')
        .where(
          'parentId',
          isEqualTo: parentFolderId,
        ) // 👈 CORRECCIÓN: Filtrar por "parentId"
        .snapshots()
        .map((snapshot) {
          var folders = snapshot.docs
              .map((doc) => FolderModel.fromFirestore(doc))
              .toList();

          folders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return folders;
        });
  }

  // 👇 NUEVO - Obtener todas las carpetas (para migraciones o búsquedas)
  Stream<List<FolderModel>> getAllUserFolders(String userId) {
    return _firestore
        .collection('folders')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          var folders = snapshot.docs
              .map((doc) => FolderModel.fromFirestore(doc))
              .toList();

          folders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return folders;
        });
  }

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

  // 👇 MODIFICADO - Eliminar carpeta y todas sus subcarpetas recursivamente
  Future<void> deleteFolder(String folderId) async {
    try {
      // 1. Obtener todas las subcarpetas
      QuerySnapshot subFolders = await _firestore
          .collection('folders')
          .where('parentFolderId', isEqualTo: folderId)
          .get();

      // 2. Eliminar subcarpetas recursivamente
      for (var subFolderDoc in subFolders.docs) {
        await deleteFolder(subFolderDoc.id);
      }

      // 3. Obtener todos los libros de esta carpeta
      QuerySnapshot books = await _firestore
          .collection('books')
          .where('folderId', isEqualTo: folderId)
          .get();

      WriteBatch batch = _firestore.batch();

      // 4. Eliminar todos los libros
      for (var doc in books.docs) {
        batch.delete(doc.reference);
      }

      // 5. Eliminar la carpeta
      batch.delete(_firestore.collection('folders').doc(folderId));

      await batch.commit();

      // 6. Eliminar archivos de Storage
      _deleteFolderFiles(books.docs);
    } catch (e) {
      throw Exception('Error al eliminar carpeta: $e');
    }
  }

  Future<void> _deleteFolderFiles(List<QueryDocumentSnapshot> bookDocs) async {
    for (var doc in bookDocs) {
      try {
        BookModel book = BookModel.fromFirestore(doc);

        if (book.pdfUrl.isNotEmpty) {
          await _storageService.deleteFile(book.pdfUrl);
        }

        if (book.coverUrl != null && book.coverUrl!.isNotEmpty) {
          await _storageService.deleteFile(book.coverUrl!);
        }
      } catch (e) {
        // Continuar con los demás archivos
      }
    }
  }

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

  Future<String> createBook(BookModel book) async {
    try {
      WriteBatch batch = _firestore.batch();

      DocumentReference bookRef = _firestore.collection('books').doc();

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

  Future<void> deleteBook(String bookId, String folderId) async {
    try {
      DocumentSnapshot bookDoc = await _firestore
          .collection('books')
          .doc(bookId)
          .get();

      if (!bookDoc.exists) {
        throw Exception('El libro no existe');
      }

      BookModel book = BookModel.fromFirestore(bookDoc);

      WriteBatch batch = _firestore.batch();

      batch.delete(bookDoc.reference);

      DocumentReference folderRef = _firestore
          .collection('folders')
          .doc(folderId);
      batch.update(folderRef, {
        'bookCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      _deleteBookFiles(book);
    } catch (e) {
      throw Exception('Error al eliminar libro: $e');
    }
  }

  Future<void> _deleteBookFiles(BookModel book) async {
    if (book.pdfUrl.isNotEmpty) {
      try {
        await _storageService.deleteFile(book.pdfUrl);
      } catch (e) {
        // Continuar si falla
      }
    }

    if (book.coverUrl != null && book.coverUrl!.isNotEmpty) {
      try {
        await _storageService.deleteFile(book.coverUrl!);
      } catch (e) {
        // Continuar si falla
      }
    }
  }

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

  // ==================== NOTES ====================

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

  Stream<List<NoteModel>> getUserNotes(String userId) {
    return _firestore
        .collection('notes')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          var notes = snapshot.docs
              .map((doc) => NoteModel.fromFirestore(doc))
              .toList();

          notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notes;
        });
  }

  Stream<List<NoteModel>> getBookNotes(String bookId) {
    return _firestore
        .collection('notes')
        .where('bookId', isEqualTo: bookId)
        .snapshots()
        .map((snapshot) {
          var notes = snapshot.docs
              .map((doc) => NoteModel.fromFirestore(doc))
              .toList();

          notes.sort((a, b) {
            if (a.pageNumber != null && b.pageNumber != null) {
              return a.pageNumber!.compareTo(b.pageNumber!);
            }
            return b.createdAt.compareTo(a.createdAt);
          });
          return notes;
        });
  }

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

  Future<void> deleteNote(String noteId) async {
    try {
      await _firestore.collection('notes').doc(noteId).delete();
    } catch (e) {
      throw Exception('Error al eliminar nota: $e');
    }
  }

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

  // ==================== TASK GROUPS ====================

  Future<String> createTaskGroup(TaskGroupModel taskGroup) async {
    try {
      DocumentReference docRef = _firestore.collection('task_groups').doc();

      final now = DateTime.now();
      final taskGroupData = {
        'userId': taskGroup.userId,
        'name': taskGroup.name,
        // ignore: deprecated_member_use
        'colorValue': taskGroup.color.value,
        'taskCount': 0,
        'completedTaskCount': 0,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      await docRef.set(taskGroupData);
      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear grupo de tareas: $e');
    }
  }

  Stream<List<TaskGroupModel>> getUserTaskGroups(String userId) {
    return _firestore
        .collection('task_groups')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          var taskGroups = snapshot.docs
              .map((doc) => TaskGroupModel.fromFirestore(doc))
              .toList();

          taskGroups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return taskGroups;
        });
  }

  Future<TaskGroupModel?> getTaskGroupById(String taskGroupId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('task_groups')
          .doc(taskGroupId)
          .get();
      if (doc.exists) {
        return TaskGroupModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener grupo de tareas: $e');
    }
  }

  Future<void> updateTaskGroup(
    String taskGroupId,
    TaskGroupModel taskGroup,
  ) async {
    try {
      await _firestore
          .collection('task_groups')
          .doc(taskGroupId)
          .update(taskGroup.toUpdateMap());
    } catch (e) {
      throw Exception('Error al actualizar grupo de tareas: $e');
    }
  }

  Future<void> deleteTaskGroup(String taskGroupId) async {
    try {
      // Obtener todas las tareas del grupo
      QuerySnapshot tasks = await _firestore
          .collection('tasks')
          .where('taskGroupId', isEqualTo: taskGroupId)
          .get();

      WriteBatch batch = _firestore.batch();

      // Eliminar todas las tareas
      for (var doc in tasks.docs) {
        batch.delete(doc.reference);
      }

      // Eliminar el grupo
      batch.delete(_firestore.collection('task_groups').doc(taskGroupId));

      await batch.commit();
    } catch (e) {
      throw Exception('Error al eliminar grupo de tareas: $e');
    }
  }

  Future<void> updateTaskGroupCounts(String taskGroupId) async {
    try {
      QuerySnapshot tasks = await _firestore
          .collection('tasks')
          .where('taskGroupId', isEqualTo: taskGroupId)
          .get();

      int taskCount = tasks.docs.length;
      int completedTaskCount = tasks.docs.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['isCompleted'] == true;
      }).length;

      await _firestore.collection('task_groups').doc(taskGroupId).update({
        'taskCount': taskCount,
        'completedTaskCount': completedTaskCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al actualizar contadores del grupo: $e');
    }
  }

  // ==================== TASKS ====================

  Future<String> createTask(TaskModel task) async {
    try {
      WriteBatch batch = _firestore.batch();

      DocumentReference taskRef = _firestore.collection('tasks').doc();

      final now = DateTime.now();
      final taskData = {
        'userId': task.userId,
        'taskGroupId': task.taskGroupId,
        'title': task.title,
        'isCompleted': false,
        'dueDate': task.dueDate != null
            ? Timestamp.fromDate(task.dueDate!)
            : null,
        'reminderDate': task.reminderDate != null
            ? Timestamp.fromDate(task.reminderDate!)
            : null,
        'repeatType': task.repeatType,
        'customRepeatDays': task.customRepeatDays,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      batch.set(taskRef, taskData);

      // Incrementar contador del grupo
      DocumentReference groupRef = _firestore
          .collection('task_groups')
          .doc(task.taskGroupId);
      batch.update(groupRef, {
        'taskCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      return taskRef.id;
    } catch (e) {
      throw Exception('Error al crear tarea: $e');
    }
  }

  Stream<List<TaskModel>> getTaskGroupTasks(String taskGroupId) {
    return _firestore
        .collection('tasks')
        .where('taskGroupId', isEqualTo: taskGroupId)
        .snapshots()
        .map((snapshot) {
          var tasks = snapshot.docs
              .map((doc) => TaskModel.fromFirestore(doc))
              .toList();

          // Ordenar: no completadas primero, luego por fecha de creación
          tasks.sort((a, b) {
            if (a.isCompleted != b.isCompleted) {
              return a.isCompleted ? 1 : -1;
            }
            return b.createdAt.compareTo(a.createdAt);
          });
          return tasks;
        });
  }

  Future<TaskModel?> getTaskById(String taskId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('tasks')
          .doc(taskId)
          .get();
      if (doc.exists) {
        return TaskModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener tarea: $e');
    }
  }

  Future<void> updateTask(String taskId, TaskModel task) async {
    try {
      await _firestore
          .collection('tasks')
          .doc(taskId)
          .update(task.toUpdateMap());
    } catch (e) {
      throw Exception('Error al actualizar tarea: $e');
    }
  }

  Future<void> toggleTaskCompletion(
    String taskId,
    String taskGroupId,
    bool isCompleted,
  ) async {
    try {
      WriteBatch batch = _firestore.batch();

      // Actualizar la tarea
      DocumentReference taskRef = _firestore.collection('tasks').doc(taskId);
      batch.update(taskRef, {
        'isCompleted': isCompleted,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Actualizar contador del grupo
      DocumentReference groupRef = _firestore
          .collection('task_groups')
          .doc(taskGroupId);
      batch.update(groupRef, {
        'completedTaskCount': FieldValue.increment(isCompleted ? 1 : -1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Error al cambiar estado de tarea: $e');
    }
  }

  Future<void> deleteTask(
    String taskId,
    String taskGroupId,
    bool wasCompleted,
  ) async {
    try {
      WriteBatch batch = _firestore.batch();

      // Eliminar la tarea
      DocumentReference taskRef = _firestore.collection('tasks').doc(taskId);
      batch.delete(taskRef);

      // Actualizar contadores del grupo
      DocumentReference groupRef = _firestore
          .collection('task_groups')
          .doc(taskGroupId);

      Map<String, dynamic> updates = {
        'taskCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (wasCompleted) {
        updates['completedTaskCount'] = FieldValue.increment(-1);
      }

      batch.update(groupRef, updates);

      await batch.commit();
    } catch (e) {
      throw Exception('Error al eliminar tarea: $e');
    }
  }

  Future<List<TaskModel>> searchTasks(String userId, String query) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('tasks')
          .where('userId', isEqualTo: userId)
          .get();

      List<TaskModel> tasks = snapshot.docs
          .map((doc) => TaskModel.fromFirestore(doc))
          .where(
            (task) => task.title.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();

      return tasks;
    } catch (e) {
      throw Exception('Error al buscar tareas: $e');
    }
  }

  Future<Map<String, dynamic>> getTasksStats(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('tasks')
          .where('userId', isEqualTo: userId)
          .get();

      int totalTasks = snapshot.docs.length;
      int completedTasks = snapshot.docs.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['isCompleted'] == true;
      }).length;

      int pendingTasks = totalTasks - completedTasks;

      // Tareas con fecha de vencimiento hoy
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);

      int tasksToday = snapshot.docs.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['dueDate'] == null) return false;
        DateTime dueDate = (data['dueDate'] as Timestamp).toDate();
        DateTime dueDateOnly = DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day,
        );
        return dueDateOnly == today && data['isCompleted'] != true;
      }).length;

      return {
        'totalTasks': totalTasks,
        'completedTasks': completedTasks,
        'pendingTasks': pendingTasks,
        'tasksToday': tasksToday,
      };
    } catch (e) {
      throw Exception('Error al obtener estadísticas de tareas: $e');
    }
  }
}
