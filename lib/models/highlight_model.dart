import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HighlightModel {
  final String id;
  final String bookId;
  final String userId;
  final int pageNumber;
  final String selectedText;
  final Color highlightColor;
  final double startX; // Coordenada normalizada (0-1)
  final double startY; // Coordenada normalizada (0-1)
  final double endX; // Coordenada normalizada (0-1)
  final double endY; // Coordenada normalizada (0-1)
  final DateTime createdAt;

  HighlightModel({
    required this.id,
    required this.bookId,
    required this.userId,
    required this.pageNumber,
    required this.selectedText,
    required this.highlightColor,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.createdAt,
  });

  // Convertir de Firestore a Modelo
  factory HighlightModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return HighlightModel(
      id: doc.id,
      bookId: data['bookId'] ?? '',
      userId: data['userId'] ?? '',
      pageNumber: data['pageNumber'] ?? 0,
      selectedText: data['selectedText'] ?? '',
      highlightColor: Color(
        data['highlightColor'] ?? 0xFFFFEB3B,
      ), // Amarillo por defecto
      startX: (data['startX'] ?? 0.0).toDouble(),
      startY: (data['startY'] ?? 0.0).toDouble(),
      endX: (data['endX'] ?? 0.0).toDouble(),
      endY: (data['endY'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convertir de Modelo a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'bookId': bookId,
      'userId': userId,
      'pageNumber': pageNumber,
      'selectedText': selectedText,
      // ignore: deprecated_member_use
      'highlightColor': highlightColor.value, // Guardar como int
      'startX': startX,
      'startY': startY,
      'endX': endX,
      'endY': endY,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // CopyWith
  HighlightModel copyWith({
    String? id,
    String? bookId,
    String? userId,
    int? pageNumber,
    String? selectedText,
    Color? highlightColor,
    double? startX,
    double? startY,
    double? endX,
    double? endY,
    DateTime? createdAt,
  }) {
    return HighlightModel(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      userId: userId ?? this.userId,
      pageNumber: pageNumber ?? this.pageNumber,
      selectedText: selectedText ?? this.selectedText,
      highlightColor: highlightColor ?? this.highlightColor,
      startX: startX ?? this.startX,
      startY: startY ?? this.startY,
      endX: endX ?? this.endX,
      endY: endY ?? this.endY,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
