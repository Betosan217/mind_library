import 'package:cloud_firestore/cloud_firestore.dart';

enum ReadingStatus { unread, reading, finished }

class BookModel {
  final String id;
  final String userId;
  final String folderId;
  final String title;
  final String pdfUrl;
  final String? coverUrl;
  final int totalPages;
  final int currentPage;
  final double progress; // 0.0 a 1.0
  final ReadingStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastReadAt;
  final int fileSize; // en bytes
  final List<String> tags;

  BookModel({
    required this.id,
    required this.userId,
    required this.folderId,
    required this.title,
    required this.pdfUrl,
    this.coverUrl,
    this.totalPages = 0,
    this.currentPage = 0,
    this.progress = 0.0,
    this.status = ReadingStatus.unread,
    required this.createdAt,
    this.updatedAt,
    this.lastReadAt,
    this.fileSize = 0,
    this.tags = const [],
  });

  // Convertir de Firestore a Modelo
  factory BookModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return BookModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      folderId: data['folderId'] ?? '',
      title: data['title'] ?? '',
      pdfUrl: data['pdfUrl'] ?? '',
      coverUrl: data['coverUrl'],
      totalPages: data['totalPages'] ?? 0,
      currentPage: data['currentPage'] ?? 0,
      progress: (data['progress'] ?? 0.0).toDouble(),
      status: _statusFromString(data['status'] ?? 'unread'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      lastReadAt: (data['lastReadAt'] as Timestamp?)?.toDate(),
      fileSize: data['fileSize'] ?? 0,
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  // Convertir de Modelo a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'folderId': folderId,
      'title': title,
      'pdfUrl': pdfUrl,
      'coverUrl': coverUrl,
      'totalPages': totalPages,
      'currentPage': currentPage,
      'progress': progress,
      'status': _statusToString(status),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastReadAt': lastReadAt,
      'fileSize': fileSize,
      'tags': tags,
    };
  }

  // Método para actualizar
  Map<String, dynamic> toUpdateMap() {
    return {
      'title': title,
      'coverUrl': coverUrl,
      'totalPages': totalPages,
      'currentPage': currentPage,
      'progress': progress,
      'status': _statusToString(status),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastReadAt': lastReadAt,
      'tags': tags,
    };
  }

  // Helper para convertir status
  static ReadingStatus _statusFromString(String status) {
    switch (status) {
      case 'reading':
        return ReadingStatus.reading;
      case 'finished':
        return ReadingStatus.finished;
      default:
        return ReadingStatus.unread;
    }
  }

  static String _statusToString(ReadingStatus status) {
    switch (status) {
      case ReadingStatus.reading:
        return 'reading';
      case ReadingStatus.finished:
        return 'finished';
      default:
        return 'unread';
    }
  }

  // CopyWith
  BookModel copyWith({
    String? id,
    String? userId,
    String? folderId,
    String? title,
    String? pdfUrl,
    String? coverUrl,
    int? totalPages,
    int? currentPage,
    double? progress,
    ReadingStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastReadAt,
    int? fileSize,
    List<String>? tags,
  }) {
    return BookModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      folderId: folderId ?? this.folderId,
      title: title ?? this.title,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      fileSize: fileSize ?? this.fileSize,
      tags: tags ?? this.tags,
    );
  }

  // Calcular progreso
  double calculateProgress() {
    if (totalPages == 0) return 0.0;
    return currentPage / totalPages;
  }

  // Formatear tamaño de archivo
  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1048576) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / 1048576).toStringAsFixed(1)} MB';
  }
}
