import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TaskGroupModel {
  final String id;
  final String userId;
  final String name;
  final Color color;
  final int taskCount;
  final int completedTaskCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskGroupModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    this.taskCount = 0,
    this.completedTaskCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  // Crear desde Firestore
  factory TaskGroupModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return TaskGroupModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      color: Color(data['colorValue'] ?? 0xFFFFB300),
      taskCount: data['taskCount'] ?? 0,
      completedTaskCount: data['completedTaskCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      // ignore: deprecated_member_use
      'colorValue': color.value,
      'taskCount': taskCount,
      'completedTaskCount': completedTaskCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Para actualizar
  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      // ignore: deprecated_member_use
      'colorValue': color.value,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // CopyWith para inmutabilidad
  TaskGroupModel copyWith({
    String? id,
    String? userId,
    String? name,
    Color? color,
    int? taskCount,
    int? completedTaskCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskGroupModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      color: color ?? this.color,
      taskCount: taskCount ?? this.taskCount,
      completedTaskCount: completedTaskCount ?? this.completedTaskCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Calcular progreso
  double get progress {
    if (taskCount == 0) return 0.0;
    return completedTaskCount / taskCount;
  }
}
