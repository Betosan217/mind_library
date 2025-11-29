import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task_group_model.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import 'add_task_bottom_sheet.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskGroupModel taskGroup;

  const TaskDetailScreen({super.key, required this.taskGroup});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _showCompleted = true;
  bool _showPending = true;

  // 🆕 Listas anteriores para detectar cambios
  List<TaskModel> _previousPendingTasks = [];
  List<TaskModel> _previousCompletedTasks = [];

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  void _initStreams() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      taskProvider.initTasksStream(widget.taskGroup.id);
    });
  }

  @override
  void dispose() {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    taskProvider.stopTasksStream(widget.taskGroup.id);
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
        title: Text(widget.taskGroup.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {
              _showTaskGroupOptions(context);
            },
          ),
        ],
      ),
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, child) {
          final allTasks = taskProvider.getTasksForGroup(widget.taskGroup.id);

          final pendingTasks = allTasks.where((t) => !t.isCompleted).toList();
          final completedTasks = allTasks.where((t) => t.isCompleted).toList();

          final totalTasks = allTasks.length;
          final completedCount = completedTasks.length;
          final pendingCount = pendingTasks.length;

          return Column(
            children: [
              // Header con estadísticas
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.taskGroup.color.withValues(alpha: 0.9),
                      widget.taskGroup.color,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: widget.taskGroup.color.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(label: 'Total', value: '$totalTasks'),
                    Container(
                      height: 25,
                      width: 1,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    _buildStatItem(
                      label: 'Completadas',
                      value: '$completedCount',
                    ),
                    Container(
                      height: 25,
                      width: 1,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    _buildStatItem(label: 'Pendientes', value: '$pendingCount'),
                  ],
                ),
              ),

              Expanded(
                child: _buildTasksList(
                  pendingTasks,
                  completedTasks,
                  taskProvider,
                  isDark,
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddTaskBottomSheet(context, userId);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva Tarea'),
        backgroundColor: widget.taskGroup.color,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildTasksList(
    List<TaskModel> pendingTasks,
    List<TaskModel> completedTasks,
    TaskProvider taskProvider,
    bool isDark,
  ) {
    if (pendingTasks.isEmpty && completedTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay tareas',
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
              'Agrega tu primera tarea',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // SECCIÓN DE PENDIENTES
        if (pendingTasks.isNotEmpty) ...[
          _buildSectionHeader(
            'Pendientes',
            pendingTasks.length,
            _showPending,
            () {
              setState(() {
                _showPending = !_showPending;
              });
            },
            isDark,
          ),
          if (_showPending)
            // 🆕 AnimatedList mejorado
            ...pendingTasks.map((task) {
              final wasInCompleted = _previousCompletedTasks.any(
                (t) => t.id == task.id,
              );
              final key = ValueKey('pending_${task.id}');

              return AnimatedSwitcher(
                key: key,
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  // Si venía de completadas, animar desde abajo
                  final offsetTween = wasInCompleted
                      ? Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        )
                      : Tween<Offset>(
                          begin: const Offset(0, -0.3),
                          end: Offset.zero,
                        );

                  return SlideTransition(
                    position: animation.drive(offsetTween),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: _buildTaskItem(context, task, taskProvider, isDark),
              );
            }),
          const SizedBox(height: 16),
        ],

        // SECCIÓN DE COMPLETADAS
        if (completedTasks.isNotEmpty) ...[
          _buildSectionHeader(
            'Completadas',
            completedTasks.length,
            _showCompleted,
            () {
              setState(() {
                _showCompleted = !_showCompleted;
              });
            },
            isDark,
          ),
          if (_showCompleted)
            ...completedTasks.map((task) {
              final wasInPending = _previousPendingTasks.any(
                (t) => t.id == task.id,
              );
              final key = ValueKey('completed_${task.id}');

              return AnimatedSwitcher(
                key: key,
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  // Si venía de pendientes, animar desde arriba
                  final offsetTween = wasInPending
                      ? Tween<Offset>(
                          begin: const Offset(0, -0.3),
                          end: Offset.zero,
                        )
                      : Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        );

                  return SlideTransition(
                    position: animation.drive(offsetTween),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: _buildTaskItem(context, task, taskProvider, isDark),
              );
            }),
        ],
      ],
    );
  }

  Widget _buildStatItem({required String label, required String value}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    int count,
    bool isExpanded,
    VoidCallback onToggle,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_right_rounded,
              size: 24,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (isDark
                    ? AppColors.surfaceVariantDark
                    : AppColors.surfaceVariantLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(
    BuildContext context,
    TaskModel task,
    TaskProvider taskProvider,
    bool isDark,
  ) {
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar tarea'),
            content: const Text('¿Estás seguro de eliminar esta tarea?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        taskProvider.deleteTask(
          taskId: task.id,
          taskGroupId: widget.taskGroup.id,
          wasCompleted: task.isCompleted,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarea eliminada'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? AppColors.dividerDark.withValues(alpha: 0.5)
                : AppColors.dividerLight.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // ✅ CHECKBOX ANIMADO
            GestureDetector(
              onTap: () {
                // 🆕 Guardar listas anteriores antes del cambio
                setState(() {
                  final allTasks = context
                      .read<TaskProvider>()
                      .getTasksForGroup(widget.taskGroup.id);
                  _previousPendingTasks = allTasks
                      .where((t) => !t.isCompleted)
                      .toList();
                  _previousCompletedTasks = allTasks
                      .where((t) => t.isCompleted)
                      .toList();
                });

                taskProvider.toggleTaskCompletion(
                  taskId: task.id,
                  taskGroupId: widget.taskGroup.id,
                  isCompleted: !task.isCompleted,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: task.isCompleted
                      ? widget.taskGroup.color
                      : Colors.transparent,
                  border: Border.all(
                    color: task.isCompleted
                        ? widget.taskGroup.color
                        : (isDark
                              ? Colors.grey.shade600
                              : Colors.grey.shade400),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: task.isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),

            // 📝 CONTENIDO DE LA TAREA
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: task.isCompleted
                          ? (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight)
                          : (isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight),
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      decorationThickness: 1.5,
                    ),
                    child: Text(task.title),
                  ),
                  if (task.dueDate != null || task.reminderDate != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (task.dueDate != null) ...[
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(task.dueDate!),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                        if (task.dueDate != null && task.reminderDate != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '•',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                        if (task.reminderDate != null) ...[
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(task.reminderDate!),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // 🔘 BOTÓN DE MENÚ
            IconButton(
              icon: Icon(
                Icons.more_horiz_rounded,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                size: 20,
              ),
              onPressed: () {
                _showTaskOptions(context, task, taskProvider);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskOptions(
    BuildContext context,
    TaskModel task,
    TaskProvider taskProvider,
  ) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? '';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar tarea'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditTaskBottomSheet(context, userId, task);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Eliminar tarea',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteTask(context, task, taskProvider);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteTask(
    BuildContext context,
    TaskModel task,
    TaskProvider taskProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: const Text('¿Estás seguro de eliminar esta tarea?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              taskProvider.deleteTask(
                taskId: task.id,
                taskGroupId: widget.taskGroup.id,
                wasCompleted: task.isCompleted,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Tarea eliminada')));
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Hoy';
    } else if (dateOnly == tomorrow) {
      return 'Mañana';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showTaskGroupOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar grupo'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditTaskGroupDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Eliminar grupo',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteTaskGroupDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditTaskGroupDialog(BuildContext context) {
    final nameController = TextEditingController(text: widget.taskGroup.name);
    Color selectedColor = widget.taskGroup.color;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Editar grupo'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del grupo',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Color',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppColors.folderColors.map((color) {
                      final isSelected = selectedColor == color;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedColor = color;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('El nombre no puede estar vacío'),
                        ),
                      );
                      return;
                    }

                    final taskProvider = Provider.of<TaskProvider>(
                      context,
                      listen: false,
                    );

                    final success = await taskProvider.updateTaskGroup(
                      taskGroupId: widget.taskGroup.id,
                      name: nameController.text.trim(),
                      color: selectedColor,
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Grupo actualizado correctamente'),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Error al actualizar el grupo'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteTaskGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: Text(
          '¿Estás seguro de eliminar "${widget.taskGroup.name}"?\n\n'
          'Se eliminarán todas las tareas de este grupo. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final taskProvider = Provider.of<TaskProvider>(
                context,
                listen: false,
              );

              Navigator.pop(context);

              final success = await taskProvider.deleteTaskGroup(
                widget.taskGroup.id,
              );

              if (context.mounted) {
                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Grupo eliminado correctamente'),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error al eliminar el grupo'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showAddTaskBottomSheet(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AddTaskBottomSheet(userId: userId, taskGroupId: widget.taskGroup.id),
    );
  }

  void _showEditTaskBottomSheet(
    BuildContext context,
    String userId,
    TaskModel task,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTaskBottomSheet(
        userId: userId,
        taskGroupId: widget.taskGroup.id,
        taskToEdit: task,
      ),
    );
  }
}
