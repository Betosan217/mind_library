// lib/models/folder_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FolderModel {
  final String id;
  final String userId;
  final String name;
  final Color color;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int bookCount;

  FolderModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    required this.createdAt,
    this.updatedAt,
    this.bookCount = 0,
  });

  // Convertir de Firestore a Modelo
  factory FolderModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return FolderModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      color: Color(data['colorValue'] ?? 0xFF42A5F5),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      bookCount: data['bookCount'] ?? 0,
    );
  }

  // Convertir de Modelo a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      // ignore: deprecated_member_use
      'colorValue': color.value,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'bookCount': bookCount,
    };
  }

  // Método para actualizar
  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      // ignore: deprecated_member_use
      'colorValue': color.value,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // CopyWith para crear copias modificadas
  FolderModel copyWith({
    String? id,
    String? userId,
    String? name,
    Color? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? bookCount,
  }) {
    return FolderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      bookCount: bookCount ?? this.bookCount,
    );
  }
}
