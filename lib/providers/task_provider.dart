import 'package:flutter/material.dart';
import 'dart:async';
import '../models/task_model.dart';
import '../models/task_group_model.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class TaskProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  NotificationService get _notificationService => NotificationService();

  // =====================================================
  // ESTADO SEPARADO PARA GRUPOS Y TAREAS
  // =====================================================

  // Grupos de tareas (para TaskGroupsScreen)
  List<TaskGroupModel> _taskGroups = [];

  // 🆕 Múltiples listas de tareas por groupId
  final Map<String, List<TaskModel>> _tasksMap = {};

  bool _isLoading = false;
  String? _error;

  // Getters
  List<TaskGroupModel> get taskGroups => _taskGroups;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // 🆕 Getter para tareas de un grupo específico
  List<TaskModel> getTasksForGroup(String taskGroupId) {
    return _tasksMap[taskGroupId] ?? [];
  }

  // 🆕 Getter para obtener las próximas 5 tareas pendientes con fecha de vencimiento
  List<TaskModel> getUpcomingTasks() {
    List<TaskModel> allPendingTasks = [];

    // Recolectar todas las tareas pendientes de todos los grupos
    _tasksMap.forEach((groupId, tasks) {
      final pendingTasks = tasks
          .where((task) => !task.isCompleted && task.dueDate != null)
          .toList();
      allPendingTasks.addAll(pendingTasks);
    });

    // Ordenar por fecha de vencimiento (más cercanas primero)
    allPendingTasks.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    // Retornar solo las primeras 5
    return allPendingTasks.take(5).toList();
  }

  // 🆕 Obtener el nombre del grupo de una tarea específica
  String getTaskGroupName(String taskGroupId) {
    try {
      final group = _taskGroups.firstWhere((g) => g.id == taskGroupId);
      return group.name;
    } catch (e) {
      return 'Sin grupo';
    }
  }

  // 🆕 Obtener el color del grupo de una tarea específica
  Color getTaskGroupColor(String taskGroupId) {
    try {
      final group = _taskGroups.firstWhere((g) => g.id == taskGroupId);
      return group.color;
    } catch (e) {
      return Colors.grey;
    }
  }

  // =====================================================
  // STREAMS SEPARADOS (como en FolderProvider)
  // =====================================================

  StreamSubscription<List<TaskGroupModel>>? _taskGroupsSubscription;
  final Map<String, StreamSubscription<List<TaskModel>>> _tasksSubscriptions =
      {};

  // =====================================================
  // 🆕 INICIAR STREAMS PARA HOME (grupos + todas las tareas)
  // =====================================================
  void initHomeStreams(String userId) {
    debugPrint('🏠 Iniciando streams para Home');

    // Iniciar stream de grupos
    initTaskGroupsStream(userId);

    // Esperar a que se carguen los grupos y luego cargar todas las tareas
    Future.delayed(const Duration(milliseconds: 500), () {
      for (var group in _taskGroups) {
        initTasksStream(group.id);
      }
    });
  }

  // 🆕 DETENER STREAMS DEL HOME
  void stopHomeStreams() {
    debugPrint('🏠 Deteniendo streams de Home');
    stopTaskGroupsStream();

    // Detener todos los streams de tareas
    final groupIds = _tasksSubscriptions.keys.toList();
    for (var groupId in groupIds) {
      stopTasksStream(groupId);
    }
  }

  // =====================================================
  // INICIAR STREAM DE GRUPOS (Solo para TaskGroupsScreen)
  // =====================================================
  void initTaskGroupsStream(String userId) {
    if (_taskGroupsSubscription != null) {
      debugPrint('⚠️ Stream de grupos ya activo');
      return;
    }

    debugPrint('🔵 Iniciando stream de task groups');

    _taskGroupsSubscription = _firestoreService
        .getUserTaskGroups(userId)
        .listen(
          (groups) {
            debugPrint('📦 Recibidos ${groups.length} grupos de tareas');
            _taskGroups = groups;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('❌ Error en stream de grupos: $error');
            _error = error.toString();
            notifyListeners();
          },
        );
  }

  // =====================================================
  // INICIAR STREAM DE TAREAS (Para un grupo específico)
  // =====================================================
  void initTasksStream(String taskGroupId) {
    debugPrint('🔵 Iniciando stream de tareas para: $taskGroupId');

    // Si ya existe un stream para este grupo, no crear otro
    if (_tasksSubscriptions.containsKey(taskGroupId)) {
      debugPrint('⚠️ Stream ya existe para $taskGroupId');
      return;
    }

    // Crear nuevo stream para este grupo específico
    _tasksSubscriptions[taskGroupId] = _firestoreService
        .getTaskGroupTasks(taskGroupId)
        .listen(
          (tasks) {
            debugPrint('📦 Recibidas ${tasks.length} tareas para $taskGroupId');
            _tasksMap[taskGroupId] = tasks;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('❌ Error en stream de tareas: $error');
            _error = error.toString();
            notifyListeners();
          },
        );
  }

  // =====================================================
  // DETENER STREAM DE TAREAS (Al salir de TaskDetailScreen)
  // =====================================================
  void stopTasksStream(String taskGroupId) {
    debugPrint('🔴 Deteniendo stream de tareas: $taskGroupId');

    _tasksSubscriptions[taskGroupId]?.cancel();
    _tasksSubscriptions.remove(taskGroupId);
    _tasksMap.remove(taskGroupId);

    notifyListeners();
  }

  // =====================================================
  // DETENER STREAM DE GRUPOS (Al cerrar sesión)
  // =====================================================
  void stopTaskGroupsStream() {
    debugPrint('🔴 Deteniendo stream de grupos');
    _taskGroupsSubscription?.cancel();
    _taskGroupsSubscription = null;
    _taskGroups = [];
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint('🗑️ Disposing TaskProvider');
    _taskGroupsSubscription?.cancel();
    _tasksSubscriptions.forEach((_, sub) => sub.cancel());
    _tasksSubscriptions.clear();
    _tasksMap.clear();
    super.dispose();
  }

  // =====================================================
  // CRUD OPERATIONS - TASK GROUPS
  // =====================================================

  Future<String?> createTaskGroup({
    required String userId,
    required String name,
    required Color color,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final now = DateTime.now();
      final taskGroup = TaskGroupModel(
        id: '',
        userId: userId,
        name: name,
        color: color,
        createdAt: now,
        updatedAt: now,
      );

      String groupId = await _firestoreService.createTaskGroup(taskGroup);

      _isLoading = false;
      notifyListeners();

      return groupId;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateTaskGroup({
    required String taskGroupId,
    required String name,
    required Color color,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final taskGroup = _taskGroups.firstWhere((g) => g.id == taskGroupId);
      final updatedGroup = taskGroup.copyWith(name: name, color: color);

      await _firestoreService.updateTaskGroup(taskGroupId, updatedGroup);

      _isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTaskGroup(String taskGroupId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 🆕 Cancelar notificaciones de todas las tareas del grupo
      final tasks = _tasksMap[taskGroupId] ?? [];
      for (var task in tasks) {
        if (task.reminderDate != null) {
          await _notificationService.cancelTaskNotification(task.id);
        }
      }

      await _firestoreService.deleteTaskGroup(taskGroupId);

      // Limpiar stream de tareas si existe
      stopTasksStream(taskGroupId);

      _isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // =====================================================
  // CRUD OPERATIONS - TASKS
  // =====================================================

  Future<String?> createTask({
    required String userId,
    required String taskGroupId,
    required String title,
    DateTime? dueDate,
    DateTime? reminderDate,
    String? repeatType,
    List<int>? customRepeatDays,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final now = DateTime.now();
      final task = TaskModel(
        id: '',
        userId: userId,
        taskGroupId: taskGroupId,
        title: title,
        isCompleted: false,
        dueDate: dueDate,
        reminderDate: reminderDate,
        repeatType: repeatType,
        customRepeatDays: customRepeatDays,
        createdAt: now,
        updatedAt: now,
      );

      String taskId = await _firestoreService.createTask(task);

      // 🆕 Programar notificación si hay reminderDate
      if (reminderDate != null && reminderDate.isAfter(DateTime.now())) {
        // Obtener el nombre del grupo para la notificación
        final taskGroup = _taskGroups.firstWhere(
          (g) => g.id == taskGroupId,
          orElse: () => _taskGroups.first,
        );

        await _notificationService.scheduleTaskNotification(
          taskId: taskId,
          taskTitle: title,
          scheduledDate: reminderDate,
          taskGroupName: taskGroup.name,
        );

        debugPrint('🔔 Notificación programada para: $title');
      }

      _isLoading = false;
      notifyListeners();

      return taskId;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateTask({
    required String taskId,
    required String taskGroupId,
    required String title,
    DateTime? dueDate,
    DateTime? reminderDate,
    String? repeatType,
    List<int>? customRepeatDays,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final tasks = _tasksMap[taskGroupId] ?? [];
      final task = tasks.firstWhere((t) => t.id == taskId);
      final updatedTask = task.copyWith(
        title: title,
        dueDate: dueDate,
        reminderDate: reminderDate,
        repeatType: repeatType,
        customRepeatDays: customRepeatDays,
      );

      await _firestoreService.updateTask(taskId, updatedTask);

      // 🆕 Actualizar notificación
      // Cancelar notificación anterior
      await _notificationService.cancelTaskNotification(taskId);

      // Programar nueva notificación si hay reminderDate
      if (reminderDate != null && reminderDate.isAfter(DateTime.now())) {
        final taskGroup = _taskGroups.firstWhere(
          (g) => g.id == taskGroupId,
          orElse: () => _taskGroups.first,
        );

        await _notificationService.scheduleTaskNotification(
          taskId: taskId,
          taskTitle: title,
          scheduledDate: reminderDate,
          taskGroupName: taskGroup.name,
        );

        debugPrint('🔔 Notificación reprogramada para: $title');
      }

      _isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleTaskCompletion({
    required String taskId,
    required String taskGroupId,
    required bool isCompleted,
  }) async {
    try {
      await _firestoreService.toggleTaskCompletion(
        taskId,
        taskGroupId,
        isCompleted,
      );

      // 🆕 Si se marca como completada, cancelar notificación
      if (isCompleted) {
        await _notificationService.cancelTaskNotification(taskId);
        debugPrint('🔕 Notificación cancelada para tarea completada');
      } else {
        // Si se desmarca, reprogramar notificación si existe
        final tasks = _tasksMap[taskGroupId] ?? [];
        final task = tasks.firstWhere((t) => t.id == taskId);

        if (task.reminderDate != null &&
            task.reminderDate!.isAfter(DateTime.now())) {
          final taskGroup = _taskGroups.firstWhere(
            (g) => g.id == taskGroupId,
            orElse: () => _taskGroups.first,
          );

          await _notificationService.scheduleTaskNotification(
            taskId: taskId,
            taskTitle: task.title,
            scheduledDate: task.reminderDate!,
            taskGroupName: taskGroup.name,
          );
          debugPrint('🔔 Notificación reprogramada para tarea desmarcada');
        }
      }

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTask({
    required String taskId,
    required String taskGroupId,
    required bool wasCompleted,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 🆕 Cancelar notificación si existe
      await _notificationService.cancelTaskNotification(taskId);

      await _firestoreService.deleteTask(taskId, taskGroupId, wasCompleted);

      _isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
