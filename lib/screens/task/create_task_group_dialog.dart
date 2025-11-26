import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../utils/app_colors.dart';

class CreateTaskGroupDialog extends StatefulWidget {
  final String userId;

  const CreateTaskGroupDialog({super.key, required this.userId});

  @override
  State<CreateTaskGroupDialog> createState() => _CreateTaskGroupDialogState();
}

class _CreateTaskGroupDialogState extends State<CreateTaskGroupDialog> {
  final _nameController = TextEditingController();
  Color _selectedColor = AppColors.folderColors[0];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);

    return AlertDialog(
      title: const Text('Nuevo grupo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre del grupo',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onChanged: (value) {
              // Forzar rebuild para actualizar el botón
              setState(() {});
            },
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
              final isSelected = _selectedColor == color;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = color;
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
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
          onPressed:
              taskProvider.isLoading || _nameController.text.trim().isEmpty
              ? null
              : () async {
                  final groupId = await taskProvider.createTaskGroup(
                    userId: widget.userId,
                    name: _nameController.text.trim(),
                    color: _selectedColor,
                  );

                  if (groupId != null && context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Grupo creado exitosamente'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error al crear el grupo'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
          child: taskProvider.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Crear'),
        ),
      ],
    );
  }
}
