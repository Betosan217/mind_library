import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../utils/app_colors.dart';

class AddTaskBottomSheet extends StatefulWidget {
  final String userId;
  final String taskGroupId;
  final TaskModel? taskToEdit; // 🆕 Para editar tareas

  const AddTaskBottomSheet({
    super.key,
    required this.userId,
    required this.taskGroupId,
    this.taskToEdit,
  });

  @override
  State<AddTaskBottomSheet> createState() => _AddTaskBottomSheetState();
}

class _AddTaskBottomSheetState extends State<AddTaskBottomSheet> {
  final _titleController = TextEditingController();
  DateTime? _dueDate;
  DateTime? _reminderDate;
  String? _repeatType;
  List<int>? _customRepeatDays;

  bool _showDueDateOptions = false;
  bool _showReminderOptions = false;
  bool _showRepeatOptions = false;

  @override
  void initState() {
    super.initState();
    // 🆕 Si hay una tarea para editar, cargar sus datos
    if (widget.taskToEdit != null) {
      _titleController.text = widget.taskToEdit!.title;
      _dueDate = widget.taskToEdit!.dueDate;
      _reminderDate = widget.taskToEdit!.reminderDate;
      _repeatType = widget.taskToEdit!.repeatType;
      _customRepeatDays = widget.taskToEdit!.customRepeatDays;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.taskToEdit != null;

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.grey700 : AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Text(
                    _isEditing ? 'Editar Tarea' : 'Nueva Tarea',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Input de tarea
                  Row(
                    children: [
                      // Checkbox decorativo
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark
                                ? AppColors.grey600
                                : AppColors.grey400,
                            width: 2.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // TextField
                      Expanded(
                        child: TextField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            hintText: 'Escribe una tarea...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                              color: isDark
                                  ? AppColors.textHintDark
                                  : AppColors.textHintLight,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          autofocus: !_isEditing,
                          maxLines: null,
                          onChanged: (value) {
                            // 🔧 Forzar rebuild para actualizar el botón
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Divider(
                    color: isDark
                        ? AppColors.dividerDark
                        : AppColors.dividerLight,
                  ),
                  const SizedBox(height: 16),

                  // Opciones
                  _buildOptionButton(
                    icon: Icons.calendar_today_rounded,
                    label: _dueDate == null
                        ? 'Fecha de vencimiento'
                        : _formatDate(_dueDate!),
                    isExpanded: _showDueDateOptions,
                    onTap: () {
                      setState(() {
                        _showDueDateOptions = !_showDueDateOptions;
                        _showReminderOptions = false;
                        _showRepeatOptions = false;
                      });
                    },
                    isDark: isDark,
                    hasValue: _dueDate != null,
                  ),

                  if (_showDueDateOptions) _buildDueDateOptions(isDark),

                  const SizedBox(height: 12),

                  _buildOptionButton(
                    icon: Icons.notifications_outlined,
                    label: _reminderDate == null
                        ? 'Recordarme'
                        : _formatDateTime(_reminderDate!),
                    isExpanded: _showReminderOptions,
                    onTap: () {
                      setState(() {
                        _showReminderOptions = !_showReminderOptions;
                        _showDueDateOptions = false;
                        _showRepeatOptions = false;
                      });
                    },
                    isDark: isDark,
                    hasValue: _reminderDate != null,
                  ),

                  if (_showReminderOptions) _buildReminderOptions(isDark),

                  const SizedBox(height: 12),

                  _buildOptionButton(
                    icon: Icons.repeat_rounded,
                    label: _repeatType == null
                        ? 'Repetir'
                        : _getRepeatText(_repeatType!),
                    isExpanded: _showRepeatOptions,
                    onTap: () {
                      setState(() {
                        _showRepeatOptions = !_showRepeatOptions;
                        _showDueDateOptions = false;
                        _showReminderOptions = false;
                      });
                    },
                    isDark: isDark,
                    hasValue: _repeatType != null,
                  ),

                  if (_showRepeatOptions) _buildRepeatOptions(isDark),

                  const SizedBox(height: 24),

                  // Botón de guardar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      // 🔧 CORREGIDO: Solo verificar que el título no esté vacío
                      onPressed:
                          taskProvider.isLoading ||
                              _titleController.text.trim().isEmpty
                          ? null
                          : () async {
                              if (_isEditing) {
                                // Actualizar tarea existente
                                final success = await taskProvider.updateTask(
                                  taskId: widget.taskToEdit!.id,
                                  taskGroupId: widget.taskGroupId,
                                  title: _titleController.text.trim(),
                                  dueDate: _dueDate,
                                  reminderDate: _reminderDate,
                                  repeatType: _repeatType,
                                  customRepeatDays: _customRepeatDays,
                                );

                                if (success && context.mounted) {
                                  Navigator.pop(context);
                                }
                              } else {
                                // Crear nueva tarea
                                final taskId = await taskProvider.createTask(
                                  userId: widget.userId,
                                  taskGroupId: widget.taskGroupId,
                                  title: _titleController.text.trim(),
                                  dueDate: _dueDate,
                                  reminderDate: _reminderDate,
                                  repeatType: _repeatType,
                                  customRepeatDays: _customRepeatDays,
                                );

                                if (taskId != null && context.mounted) {
                                  Navigator.pop(context);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: taskProvider.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isEditing
                                      ? Icons.check_rounded
                                      : Icons.arrow_upward_rounded,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isEditing
                                      ? 'Actualizar Tarea'
                                      : 'Agregar Tarea',
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required bool isExpanded,
    required VoidCallback onTap,
    required bool isDark,
    bool hasValue = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: hasValue
              ? (isDark
                    ? AppColors.surfaceVariantDark
                    : AppColors.surfaceVariantLight)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: hasValue
                  ? AppColors.secondaryLight
                  : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
                  color: hasValue
                      ? (isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight)
                      : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                ),
              ),
            ),
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 22,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDueDateOptions(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceVariantDark
            : AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildOptionItem('Hoy', () {
            setState(() {
              _dueDate = DateTime.now();
              _showDueDateOptions = false;
            });
          }, isDark),
          const SizedBox(height: 8),
          _buildOptionItem('Mañana', () {
            setState(() {
              _dueDate = DateTime.now().add(const Duration(days: 1));
              _showDueDateOptions = false;
            });
          }, isDark),
          const SizedBox(height: 8),
          _buildOptionItem('Elegir fecha', () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _dueDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) {
              setState(() {
                _dueDate = date;
                _showDueDateOptions = false;
              });
            }
          }, isDark),
          if (_dueDate != null) ...[
            const SizedBox(height: 8),
            _buildOptionItem(
              'Eliminar fecha',
              () {
                setState(() {
                  _dueDate = null;
                  _showDueDateOptions = false;
                });
              },
              isDark,
              isDelete: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReminderOptions(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceVariantDark
            : AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildOptionItem('Más tarde hoy (${_getLaterTodayTime()})', () {
            setState(() {
              final now = DateTime.now();
              _reminderDate = DateTime(
                now.year,
                now.month,
                now.day,
                now.hour + 2,
                0,
              );
              _showReminderOptions = false;
            });
          }, isDark),
          const SizedBox(height: 8),
          _buildOptionItem('Mañana (9:00 AM)', () {
            setState(() {
              final tomorrow = DateTime.now().add(const Duration(days: 1));
              _reminderDate = DateTime(
                tomorrow.year,
                tomorrow.month,
                tomorrow.day,
                9,
                0,
              );
              _showReminderOptions = false;
            });
          }, isDark),
          const SizedBox(height: 8),
          _buildOptionItem('Elegir fecha y hora', () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _reminderDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) {
              if (!mounted) return;

              final time = await showTimePicker(
                context: context,
                initialTime: _reminderDate != null
                    ? TimeOfDay.fromDateTime(_reminderDate!)
                    : TimeOfDay.now(),
              );

              if (time != null && mounted) {
                setState(() {
                  _reminderDate = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  );
                  _showReminderOptions = false;
                });
              }
            }
          }, isDark),
          if (_reminderDate != null) ...[
            const SizedBox(height: 8),
            _buildOptionItem(
              'Eliminar recordatorio',
              () {
                setState(() {
                  _reminderDate = null;
                  _showReminderOptions = false;
                });
              },
              isDark,
              isDelete: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRepeatOptions(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceVariantDark
            : AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildOptionItem('Diariamente', () {
            setState(() {
              _repeatType = 'daily';
              _customRepeatDays = null;
              _showRepeatOptions = false;
            });
          }, isDark),
          const SizedBox(height: 8),
          _buildOptionItem('Semanalmente', () {
            setState(() {
              _repeatType = 'weekly';
              _customRepeatDays = null;
              _showRepeatOptions = false;
            });
          }, isDark),
          const SizedBox(height: 8),
          _buildOptionItem('Personalizado', () {
            _showCustomRepeatDialog(isDark);
          }, isDark),
          if (_repeatType != null) ...[
            const SizedBox(height: 8),
            _buildOptionItem(
              'No repetir',
              () {
                setState(() {
                  _repeatType = null;
                  _customRepeatDays = null;
                  _showRepeatOptions = false;
                });
              },
              isDark,
              isDelete: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionItem(
    String label,
    VoidCallback onTap,
    bool isDark, {
    bool isDelete = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: isDelete
                      ? AppColors.error
                      : (isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight),
                ),
              ),
            ),
            if (!isDelete)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
          ],
        ),
      ),
    );
  }

  void _showCustomRepeatDialog(bool isDark) {
    List<int> selectedDays = _customRepeatDays ?? [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Repetir personalizado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Selecciona los días de la semana:'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDayChip('L', 1, selectedDays, setDialogState, isDark),
                  _buildDayChip('M', 2, selectedDays, setDialogState, isDark),
                  _buildDayChip('M', 3, selectedDays, setDialogState, isDark),
                  _buildDayChip('J', 4, selectedDays, setDialogState, isDark),
                  _buildDayChip('V', 5, selectedDays, setDialogState, isDark),
                  _buildDayChip('S', 6, selectedDays, setDialogState, isDark),
                  _buildDayChip('D', 7, selectedDays, setDialogState, isDark),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: selectedDays.isEmpty
                  ? null
                  : () {
                      setState(() {
                        _repeatType = 'custom';
                        _customRepeatDays = List.from(selectedDays)..sort();
                        _showRepeatOptions = false;
                      });
                      Navigator.pop(context);
                    },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayChip(
    String label,
    int day,
    List<int> selectedDays,
    StateSetter setDialogState,
    bool isDark,
  ) {
    final isSelected = selectedDays.contains(day);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setDialogState(() {
          if (selected) {
            selectedDays.add(day);
          } else {
            selectedDays.remove(day);
          }
        });
      },
      selectedColor: AppColors.secondaryLight,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
      ),
    );
  }

  String _getLaterTodayTime() {
    final now = DateTime.now();
    final laterTime = now.add(const Duration(hours: 2));
    return '${laterTime.hour.toString().padLeft(2, '0')}:00';
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

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${_formatDate(dateTime)} $hour:$minute';
  }

  String _getRepeatText(String repeatType) {
    switch (repeatType) {
      case 'daily':
        return 'Diariamente';
      case 'weekly':
        return 'Semanalmente';
      case 'custom':
        if (_customRepeatDays != null && _customRepeatDays!.isNotEmpty) {
          final days = _customRepeatDays!
              .map((d) {
                switch (d) {
                  case 1:
                    return 'L';
                  case 2:
                    return 'M';
                  case 3:
                    return 'M';
                  case 4:
                    return 'J';
                  case 5:
                    return 'V';
                  case 6:
                    return 'S';
                  case 7:
                    return 'D';
                  default:
                    return '';
                }
              })
              .join(', ');
          return 'Personalizado ($days)';
        }
        return 'Personalizado';
      default:
        return '';
    }
  }
}
