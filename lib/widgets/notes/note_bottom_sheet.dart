// lib/widgets/note_bottom_sheet.dart (REDISEÑADO - CON ICONOS SVG)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/note_model.dart';
import '../../providers/note_provider.dart';
import '../../providers/book_provider.dart';
import '../../utils/app_colors.dart';

class NoteBottomSheet extends StatefulWidget {
  final NoteModel? note;
  final String? bookId;
  final int? pageNumber;

  const NoteBottomSheet({super.key, this.note, this.bookId, this.pageNumber});

  @override
  State<NoteBottomSheet> createState() => _NoteBottomSheetState();
}

class _NoteBottomSheetState extends State<NoteBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _pageController;

  String? _selectedBookId;
  String? _selectedCategory;
  bool _linkToPage = false;
  bool _isLoading = false;

  final List<String> _categories = [
    'Resumen',
    'Importante',
    'Duda',
    'Idea',
    'Pendiente',
  ];

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
    _pageController = TextEditingController(
      text:
          widget.note?.pageNumber?.toString() ??
          widget.pageNumber?.toString() ??
          '',
    );

    _selectedBookId = widget.note?.bookId ?? widget.bookId;
    _selectedCategory = widget.note?.category;
    _linkToPage = widget.note?.pageNumber != null || widget.pageNumber != null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header más compacto con iconos SVG
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SvgPicture.asset(
                        widget.note == null
                            ? 'assets/icons/add_file.svg'
                            : 'assets/icons/edit_note.svg',
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(
                          AppColors.primary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.note == null ? 'Nueva Nota' : 'Editar Nota',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Campo: Título
                _buildLabel('Título'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _titleController,
                  hint: 'Ej: Capítulo 5 - Resumen',
                  icon: 'assets/icons/text.svg',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El título es requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Campo: Contenido
                _buildLabel('Contenido'),
                const SizedBox(height: 8),
                _buildTextArea(
                  controller: _contentController,
                  hint: 'Escribe aquí el contenido de tu nota...',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El contenido es requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Dropdown: Libro
                Consumer<BookProvider>(
                  builder: (context, bookProvider, _) {
                    if (bookProvider.books.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Libro (opcional)'),
                        const SizedBox(height: 8),
                        _buildCustomDropdown(
                          value: _selectedBookId,
                          hint: 'Selecciona un libro',
                          icon: 'assets/icons/book.svg',
                          items: [
                            {'value': null, 'label': 'Sin libro'},
                            ...bookProvider.books.map(
                              (book) => {'value': book.id, 'label': book.title},
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedBookId = value;
                              if (value == null) {
                                _linkToPage = false;
                                _pageController.clear();
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),

                // Vincular página (si hay libro seleccionado)
                if (_selectedBookId != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            SvgPicture.asset(
                              'assets/icons/bookmark.svg',
                              width: 18,
                              height: 18,
                              colorFilter: ColorFilter.mode(
                                Colors.grey[600]!,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Vincular a una página',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: _linkToPage,
                                onChanged: (value) {
                                  setState(() {
                                    _linkToPage = value;
                                    if (!value) {
                                      _pageController.clear();
                                    }
                                  });
                                },
                                activeColor: AppColors.primary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                        if (_linkToPage) ...[
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _pageController,
                            hint: 'Número de página',
                            icon: 'assets/icons/bookmark.svg',
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (_linkToPage &&
                                  (value == null || value.trim().isEmpty)) {
                                return 'El número de página es requerido';
                              }
                              if (value != null && value.isNotEmpty) {
                                final page = int.tryParse(value);
                                if (page == null || page <= 0) {
                                  return 'Número inválido';
                                }
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Dropdown: Categoría
                _buildLabel('Categoría (opcional)'),
                const SizedBox(height: 8),
                _buildCustomDropdown(
                  value: _selectedCategory,
                  hint: 'Selecciona una categoría',
                  icon: 'assets/icons/tag.svg',
                  items: [
                    {'value': null, 'label': 'Sin categoría'},
                    ..._categories.map((cat) => {'value': cat, 'label': cat}),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: _buildSecondaryButton(
                        label: 'Cancelar',
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPrimaryButton(
                        label: widget.note == null ? 'Crear' : 'Guardar',
                        onPressed: _isLoading ? null : _saveNote,
                        isLoading: _isLoading,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey[700],
        letterSpacing: -0.1,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required String icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey[800],
          letterSpacing: -0.1,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(14),
            child: SvgPicture.asset(
              icon,
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(Colors.grey[400]!, BlendMode.srcIn),
            ),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red[300]!, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red[300]!, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildTextArea({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: 5,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey[800],
          letterSpacing: -0.1,
          height: 1.5,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(top: 12, left: 12),
            child: SvgPicture.asset(
              'assets/icons/description.svg',
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(Colors.grey[400]!, BlendMode.srcIn),
            ),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red[300]!, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red[300]!, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildCustomDropdown({
    required String? value,
    required String hint,
    required String icon,
    required List<Map<String, dynamic>> items,
    required Function(String?) onChanged,
  }) {
    final selectedLabel = value == null
        ? hint
        : items.firstWhere(
                (item) => item['value'] == value,
                orElse: () => {'label': hint},
              )['label']
              as String;

    return GestureDetector(
      onTap: () => _showDropdownSheet(items, onChanged, value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              icon,
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(Colors.grey[400]!, BlendMode.srcIn),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: value == null ? Colors.grey[400] : Colors.grey[800],
                  letterSpacing: -0.1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showDropdownSheet(
    List<Map<String, dynamic>> items,
    Function(String?) onChanged,
    String? currentValue,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Título
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Seleccionar opción',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey[200]),

            // Lista de opciones
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 20,
                  endIndent: 20,
                  color: Colors.grey[200],
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = item['value'] == currentValue;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        onChanged(item['value']);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.04)
                            : Colors.transparent,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['label'] as String,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey[800],
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    String? folderId = '';
    if (_selectedBookId != null && _selectedBookId!.isNotEmpty) {
      final bookProvider = context.read<BookProvider>();
      try {
        final book = bookProvider.books.firstWhere(
          (b) => b.id == _selectedBookId,
        );
        folderId = book.folderId;
      } catch (e) {
        folderId = '';
      }
    }

    final int? pageNumber = _linkToPage && _pageController.text.isNotEmpty
        ? int.tryParse(_pageController.text)
        : null;

    final noteData = NoteModel(
      id: widget.note?.id ?? '',
      userId: userId,
      bookId: _selectedBookId ?? '',
      folderId: folderId,
      pageNumber: pageNumber,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      category: _selectedCategory,
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final noteProvider = context.read<NoteProvider>();
    final bool success;

    if (widget.note == null) {
      success = await noteProvider.createNote(noteData);
    } else {
      success = await noteProvider.updateNote(widget.note!.id, noteData);
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.note == null
                ? 'Nota creada exitosamente'
                : 'Nota actualizada',
          ),
          backgroundColor: Colors.green[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error al guardar la nota'),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}
