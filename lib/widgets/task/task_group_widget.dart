import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../../models/task_group_model.dart';
import '../../utils/app_colors.dart';

class TaskGroupWidget extends StatefulWidget {
  final TaskGroupModel taskGroup;
  final List<TaskModel> tasks;
  final Function(String taskId, bool isCompleted) onTaskToggle;
  final VoidCallback onViewAllTasks;
  final bool isDark;

  const TaskGroupWidget({
    super.key,
    required this.taskGroup,
    required this.tasks,
    required this.onTaskToggle,
    required this.onViewAllTasks,
    required this.isDark,
  });

  @override
  State<TaskGroupWidget> createState() => _TaskGroupWidgetState();
}

class _TaskGroupWidgetState extends State<TaskGroupWidget>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  int _currentPage = 0;
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _heightAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _nextPage() {
    final totalPages = (widget.tasks.length / 4).ceil();
    if (_currentPage < totalPages - 1) {
      setState(() {
        _currentPage++;
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
    }
  }

  List<TaskModel> _getCurrentPageTasks() {
    final startIndex = _currentPage * 4;
    final endIndex = (startIndex + 4).clamp(0, widget.tasks.length);
    return widget.tasks.sublist(startIndex, endIndex);
  }

  @override
  Widget build(BuildContext context) {
    final displayTasks = _getCurrentPageTasks();
    final totalPages = (widget.tasks.length / 4).ceil();
    final hasPreviousPage = _currentPage > 0;
    final hasNextPage = _currentPage < totalPages - 1;

    final backgroundColor = widget.isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final textColor = widget.isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondaryColor = widget.isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 10), // 12 → 10
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            widget.taskGroup.color.withValues(alpha: 0.9),
            widget.taskGroup.color,
          ],
        ),
        borderRadius: BorderRadius.circular(24), // 32 → 24
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06), // 0.08 → 0.06
            blurRadius: 8, // 12 → 8
            offset: const Offset(0, 2), // (0, 4) → (0, 2)
          ),
        ],
      ),
      padding: const EdgeInsets.all(8), // 10 → 8
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tarjeta Blanca Interior
          Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(18), // 24 → 18
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                InkWell(
                  onTap: displayTasks.isNotEmpty ? _toggleExpand : null,
                  borderRadius: BorderRadius.circular(18), // 24 → 18
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, // 16 → 14
                      vertical: 12, // 16 → 12
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.taskGroup.name,
                                style: TextStyle(
                                  fontSize: 15, // 17 → 15
                                  fontWeight: FontWeight.w700, // bold → w700
                                  color: textColor,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.taskGroup.taskCount}/${widget.taskGroup.completedTaskCount} completadas',
                                style: TextStyle(
                                  fontSize: 11, // 12 → 11
                                  color: textSecondaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (displayTasks.isNotEmpty)
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: textSecondaryColor,
                            size: 22, // 24 → 22
                          ),
                      ],
                    ),
                  ),
                ),

                // Lista de Tareas Expandible
                if (displayTasks.isNotEmpty)
                  SizeTransition(
                    sizeFactor: _heightAnimation,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 14, // 16 → 14
                        right: 14,
                        bottom: 12, // 16 → 12
                      ),
                      child: Column(
                        children: displayTasks.map((task) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6), // 8 → 6
                            child: InkWell(
                              onTap: () => widget.onTaskToggle(
                                task.id,
                                !task.isCompleted,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2, // Padding interno
                                ),
                                child: Row(
                                  children: [
                                    // Checkbox
                                    Container(
                                      width: 18, // 20 → 18
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: task.isCompleted
                                            ? Colors.black
                                            : backgroundColor,
                                        border: Border.all(
                                          color: task.isCompleted
                                              ? Colors.black
                                              : (widget.isDark
                                                    ? AppColors.grey600
                                                    : AppColors.grey300),
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          5,
                                        ), // 6 → 5
                                      ),
                                      child: task.isCompleted
                                          ? const Icon(
                                              Icons.check_rounded,
                                              color: Colors.white,
                                              size: 12, // 14 → 12
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 8), // 10 → 8
                                    // Texto de la tarea
                                    Expanded(
                                      child: Text(
                                        task.title,
                                        style: TextStyle(
                                          fontSize: 13, // 14 → 13
                                          color: task.isCompleted
                                              ? textSecondaryColor
                                              : textColor,
                                          decoration: task.isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8), // 10 → 8
          // Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: widget.onViewAllTasks,
                  child: Text(
                    'Ver todas las tareas',
                    style: TextStyle(
                      fontSize: 12, // 13 → 12
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? Colors.black87 : Colors.black87,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.chevron_left_rounded,
                        color: hasPreviousPage
                            ? (widget.isDark ? Colors.black87 : Colors.black87)
                            : (widget.isDark
                                  ? Colors.black.withValues(alpha: 0.3)
                                  : Colors.black.withValues(alpha: 0.3)),
                      ),
                      iconSize: 18, // 20 → 18
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: hasPreviousPage ? _previousPage : null,
                    ),
                    const SizedBox(width: 2), // 4 → 2
                    if (totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                        ), // 4 → 2
                        child: Text(
                          '${_currentPage + 1}/$totalPages',
                          style: TextStyle(
                            fontSize: 10, // 11 → 10
                            fontWeight: FontWeight.w600,
                            color: widget.isDark
                                ? Colors.black87
                                : Colors.black87,
                          ),
                        ),
                      ),
                    const SizedBox(width: 2), // 4 → 2
                    IconButton(
                      icon: Icon(
                        Icons.chevron_right_rounded,
                        color: hasNextPage
                            ? (widget.isDark ? Colors.black87 : Colors.black87)
                            : (widget.isDark
                                  ? Colors.black.withValues(alpha: 0.3)
                                  : Colors.black.withValues(alpha: 0.3)),
                      ),
                      iconSize: 18, // 20 → 18
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: hasNextPage ? _nextPage : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
