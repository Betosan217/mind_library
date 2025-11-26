import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String userId;
  final String taskGroupId;
  final String title;
  final bool isCompleted;
  final DateTime? dueDate;
  final DateTime? reminderDate;
  final String? repeatType; // 'daily', 'weekly', 'custom'
  final List<int>? customRepeatDays; // [1,2,3,4,5,6,7] para lun-dom
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskModel({
    required this.id,
    required this.userId,
    required this.taskGroupId,
    required this.title,
    this.isCompleted = false,
    this.dueDate,
    this.reminderDate,
    this.repeatType,
    this.customRepeatDays,
    required this.createdAt,
    required this.updatedAt,
  });

  // Crear desde Firestore
  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return TaskModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      taskGroupId: data['taskGroupId'] ?? '',
      title: data['title'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      dueDate: data['dueDate'] != null
          ? (data['dueDate'] as Timestamp).toDate()
          : null,
      reminderDate: data['reminderDate'] != null
          ? (data['reminderDate'] as Timestamp).toDate()
          : null,
      repeatType: data['repeatType'],
      customRepeatDays: data['customRepeatDays'] != null
          ? List<int>.from(data['customRepeatDays'])
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'taskGroupId': taskGroupId,
      'title': title,
      'isCompleted': isCompleted,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'reminderDate': reminderDate != null
          ? Timestamp.fromDate(reminderDate!)
          : null,
      'repeatType': repeatType,
      'customRepeatDays': customRepeatDays,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Para actualizar
  Map<String, dynamic> toUpdateMap() {
    return {
      'title': title,
      'isCompleted': isCompleted,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'reminderDate': reminderDate != null
          ? Timestamp.fromDate(reminderDate!)
          : null,
      'repeatType': repeatType,
      'customRepeatDays': customRepeatDays,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // CopyWith para inmutabilidad
  TaskModel copyWith({
    String? id,
    String? userId,
    String? taskGroupId,
    String? title,
    bool? isCompleted,
    DateTime? dueDate,
    DateTime? reminderDate,
    String? repeatType,
    List<int>? customRepeatDays,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      taskGroupId: taskGroupId ?? this.taskGroupId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate ?? this.dueDate,
      reminderDate: reminderDate ?? this.reminderDate,
      repeatType: repeatType ?? this.repeatType,
      customRepeatDays: customRepeatDays ?? this.customRepeatDays,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
