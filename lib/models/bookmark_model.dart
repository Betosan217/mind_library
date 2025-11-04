import 'package:cloud_firestore/cloud_firestore.dart';

class BookmarkModel {
  final String id;
  final String bookId;
  final String userId;
  final int pageNumber;
  final String? note;
  final DateTime createdAt;

  BookmarkModel({
    required this.id,
    required this.bookId,
    required this.userId,
    required this.pageNumber,
    this.note,
    required this.createdAt,
  });

  // Convertir de Firestore a Modelo
  factory BookmarkModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return BookmarkModel(
      id: doc.id,
      bookId: data['bookId'] ?? '',
      userId: data['userId'] ?? '',
      pageNumber: data['pageNumber'] ?? 0,
      note: data['note'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convertir de Modelo a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'bookId': bookId,
      'userId': userId,
      'pageNumber': pageNumber,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // CopyWith
  BookmarkModel copyWith({
    String? id,
    String? bookId,
    String? userId,
    int? pageNumber,
    String? note,
    DateTime? createdAt,
  }) {
    return BookmarkModel(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      userId: userId ?? this.userId,
      pageNumber: pageNumber ?? this.pageNumber,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
