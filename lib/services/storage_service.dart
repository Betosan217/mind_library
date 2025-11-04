import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ========== SUBIR FOTO DE PERFIL ==========
  Future<String> uploadUserProfilePhoto({
    required File file,
    required String userId,
  }) async {
    try {
      String fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String filePath = 'users/$userId/profile/$fileName';

      Reference ref = _storage.ref().child(filePath);
      UploadTask uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Error al subir foto de perfil: $e');
    }
  }

  // ========== SUBIR FOTO DE PORTADA ==========
  Future<String> uploadUserCoverPhoto({
    required File file,
    required String userId,
  }) async {
    try {
      String fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String filePath = 'users/$userId/cover/$fileName';

      Reference ref = _storage.ref().child(filePath);
      UploadTask uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Error al subir foto de portada: $e');
    }
  }

  // ========== ELIMINAR FOTO ANTIGUA DEL USUARIO ==========
  Future<void> deleteUserPhoto(String? photoUrl) async {
    if (photoUrl == null || photoUrl.isEmpty) return;

    try {
      // Solo eliminar si es una URL de Firebase Storage
      if (photoUrl.contains('firebasestorage.googleapis.com')) {
        Reference ref = _storage.refFromURL(photoUrl);
        await ref.delete();
      }
    } catch (e) {
      // Si el archivo no existe, ignorar el error
      if (!e.toString().contains('object-not-found')) {
        throw Exception('Error al eliminar foto: $e');
      }
    }
  }

  // Subir PDF
  Future<String> uploadPDF({
    required File file,
    required String userId,
    required String folderId,
    Function(double)? onProgress,
  }) async {
    try {
      String fileName = path.basename(file.path);
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String filePath =
          'users/$userId/folders/$folderId/pdfs/${timestamp}_$fileName';

      Reference ref = _storage.ref().child(filePath);
      UploadTask uploadTask = ref.putFile(file);

      // Escuchar progreso
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          double progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      // Esperar a que termine
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Error al subir PDF: $e');
    }
  }

  // Subir imagen de portada
  Future<String> uploadCover({
    required File file,
    required String userId,
    required String folderId,
  }) async {
    try {
      String fileName = path.basename(file.path);
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String filePath =
          'users/$userId/folders/$folderId/covers/${timestamp}_$fileName';

      Reference ref = _storage.ref().child(filePath);
      UploadTask uploadTask = ref.putFile(file);

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Error al subir portada: $e');
    }
  }

  // Subir imagen de perfil
  Future<String> uploadProfileImage({
    required File file,
    required String userId,
  }) async {
    try {
      String fileName = path.basename(file.path);
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String filePath = 'users/$userId/profile/${timestamp}_$fileName';

      Reference ref = _storage.ref().child(filePath);
      UploadTask uploadTask = ref.putFile(file);

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Error al subir imagen de perfil: $e');
    }
  }

  // Eliminar archivo
  Future<void> deleteFile(String fileUrl) async {
    try {
      Reference ref = _storage.refFromURL(fileUrl);
      await ref.delete();
    } catch (e) {
      // Si el archivo no existe, ignorar el error
      if (!e.toString().contains('object-not-found')) {
        throw Exception('Error al eliminar archivo: $e');
      }
    }
  }

  // Obtener URL de descarga
  Future<String> getDownloadURL(String filePath) async {
    try {
      Reference ref = _storage.ref().child(filePath);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Error al obtener URL: $e');
    }
  }

  // Obtener metadata del archivo
  Future<FullMetadata> getFileMetadata(String filePath) async {
    try {
      Reference ref = _storage.ref().child(filePath);
      return await ref.getMetadata();
    } catch (e) {
      throw Exception('Error al obtener metadata: $e');
    }
  }

  // Listar archivos en una carpeta
  Future<List<String>> listFiles(String folderPath) async {
    try {
      Reference ref = _storage.ref().child(folderPath);
      ListResult result = await ref.listAll();

      List<String> urls = [];
      for (Reference item in result.items) {
        String url = await item.getDownloadURL();
        urls.add(url);
      }

      return urls;
    } catch (e) {
      throw Exception('Error al listar archivos: $e');
    }
  }

  // Calcular tamaño de carpeta (en bytes)
  Future<int> getFolderSize(String folderPath) async {
    try {
      Reference ref = _storage.ref().child(folderPath);
      ListResult result = await ref.listAll();

      int totalSize = 0;
      for (Reference item in result.items) {
        FullMetadata metadata = await item.getMetadata();
        totalSize += metadata.size ?? 0;
      }

      return totalSize;
    } catch (e) {
      throw Exception('Error al calcular tamaño: $e');
    }
  }
}
