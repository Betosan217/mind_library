// lib/models/note_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class NoteModel {
  final String id;
  final String userId;
  final String bookId;
  final String folderId;
  final int? pageNumber; // Opcional: null si no está vinculada a una página
  final String title;
  final String content;
  final String? category; // Opcional: "Resumen", "Importante", "Duda", etc.
  final DateTime createdAt;
  final DateTime? updatedAt;

  NoteModel({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.folderId,
    this.pageNumber,
    required this.title,
    required this.content,
    this.category,
    required this.createdAt,
    this.updatedAt,
  });

  // Convertir de Firestore a Modelo
  factory NoteModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return NoteModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      bookId: data['bookId'] ?? '',
      folderId: data['folderId'] ?? '',
      pageNumber: data['pageNumber'] as int?,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      category: data['category'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // Convertir de Modelo a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'bookId': bookId,
      'folderId': folderId,
      'pageNumber': pageNumber,
      'title': title,
      'content': content,
      'category': category,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Método para actualizar
  Map<String, dynamic> toUpdateMap() {
    return {
      'title': title,
      'content': content,
      'category': category,
      'pageNumber': pageNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // CopyWith para crear copias modificadas
  NoteModel copyWith({
    String? id,
    String? userId,
    String? bookId,
    String? folderId,
    int? pageNumber,
    String? title,
    String? content,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      folderId: folderId ?? this.folderId,
      pageNumber: pageNumber ?? this.pageNumber,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper: Texto del preview para lista
  String get preview {
    if (content.isEmpty) return 'Sin contenido';
    return content.length > 100 ? '${content.substring(0, 100)}...' : content;
  }

  // Helper: Formatear fecha de creación
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Hace ${difference.inMinutes} min';
      }
      return 'Hace ${difference.inHours} h';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  // Helper: Texto descriptivo de página
  String get pageInfo {
    if (pageNumber == null) return 'Sin página vinculada';
    return 'Página $pageNumber';
  }
}
