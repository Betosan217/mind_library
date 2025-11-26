import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/task/task_group_widget.dart';
import 'task_detail_screen.dart';
import 'create_task_group_dialog.dart';

class TaskGroupsScreen extends StatefulWidget {
  const TaskGroupsScreen({super.key});

  @override
  State<TaskGroupsScreen> createState() => _TaskGroupsScreenState();
}

class _TaskGroupsScreenState extends State<TaskGroupsScreen> {
  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  void _initStreams() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? '';

      if (userId.isNotEmpty) {
        // 🔵 Iniciar SOLO el stream de grupos
        taskProvider.initTaskGroupsStream(userId);
      }
    });
  }

  @override
  void dispose() {
    // Detener stream de grupos al salir
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    taskProvider.stopTaskGroupsStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Mis Tareas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              _showCreateTaskGroupDialog(context, userId);
            },
            tooltip: 'Crear grupo de tareas',
          ),
        ],
      ),
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, child) {
          final taskGroups = taskProvider.taskGroups;

          // Loading inicial
          if (taskGroups.isEmpty && taskProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error
          if (taskProvider.error != null && taskGroups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar grupos de tareas',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            );
          }

          // Empty state
          if (taskGroups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.checklist_rounded,
                    size: 80,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes grupos de tareas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crea tu primer grupo para empezar',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      _showCreateTaskGroupDialog(context, userId);
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Crear grupo'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Lista de grupos (sin StreamBuilder anidado)
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: taskGroups.length,
            itemBuilder: (context, index) {
              final taskGroup = taskGroups[index];

              // 🆕 Iniciar stream de tareas SOLO para este grupo
              WidgetsBinding.instance.addPostFrameCallback((_) {
                taskProvider.initTasksStream(taskGroup.id);
              });

              // Obtener tareas desde el mapa (no desde StreamBuilder)
              final tasks = taskProvider.getTasksForGroup(taskGroup.id);

              // Mostrar solo primeras 4 tareas
              final displayTasks = tasks.take(4).toList();

              return TaskGroupWidget(
                taskGroup: taskGroup,
                tasks: displayTasks,
                onTaskToggle: (taskId, isCompleted) async {
                  await taskProvider.toggleTaskCompletion(
                    taskId: taskId,
                    taskGroupId: taskGroup.id,
                    isCompleted: isCompleted,
                  );
                },
                onViewAllTasks: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          TaskDetailScreen(taskGroup: taskGroup),
                    ),
                  );
                },
                isDark: isDark,
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateTaskGroupDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => CreateTaskGroupDialog(userId: userId),
    );
  }
}
