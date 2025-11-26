// lib/widgets/add_book_widget.dart (ADAPTADO A TEMAS CLARO/OSCURO)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';
import '../../models/folder_model.dart';
import '../../providers/book_provider.dart';
import '../../utils/app_colors.dart';

class AddBookWidget extends StatefulWidget {
  final FolderModel folder;

  const AddBookWidget({super.key, required this.folder});

  @override
  State<AddBookWidget> createState() => _AddBookWidgetState();
}

class _AddBookWidgetState extends State<AddBookWidget>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  File? _selectedPdf;
  String? _pdfFileName;
  int? _pdfFileSize;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pickPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileSize = await file.length();

        setState(() {
          _selectedPdf = file;
          _pdfFileName = result.files.single.name;
          _pdfFileSize = fileSize;
        });

        _animationController.forward();

        // Auto-completar título si está vacío
        if (_titleController.text.isEmpty) {
          String fileName = result.files.single.name;
          if (fileName.endsWith('.pdf')) {
            fileName = fileName.substring(0, fileName.length - 4);
          }
          _titleController.text = fileName;
        }
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar archivo: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _removePDF() {
    setState(() {
      _selectedPdf = null;
      _pdfFileName = null;
      _pdfFileSize = null;
      _titleController.clear();
    });
    _animationController.reset();
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedPdf == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Por favor selecciona un archivo PDF'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }

      if (!mounted) return;

      final bookProvider = Provider.of<BookProvider>(context, listen: false);

      bool success = await bookProvider.createBook(
        folderId: widget.folder.id,
        title: _titleController.text.trim(),
        pdfFile: _selectedPdf!,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              bookProvider.errorMessage ?? 'Error al agregar libro',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<BookProvider>(
      builder: (context, bookProvider, child) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header con handle y botón cerrar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 20),
                child: Row(
                  children: [
                    // Handle indicator centrado
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.grey700
                                : AppColors.grey300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    // Botón X
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: bookProvider.isUploading
                            ? null
                            : () => Navigator.pop(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceVariantDark
                                : const Color(0xFFF5F5F5),
                            shape: BoxShape.circle,
                          ),
                          child: SvgPicture.asset(
                            'assets/icons/close.svg',
                            width: 20,
                            height: 20,
                            colorFilter: ColorFilter.mode(
                              bookProvider.isUploading
                                  ? (isDark
                                        ? AppColors.grey600
                                        : AppColors.grey400)
                                  : (isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Título y carpeta
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      'Agregar Libro',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/folder_icon.svg',
                          width: 14,
                          height: 14,
                          colorFilter: ColorFilter.mode(
                            widget.folder.color,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.folder.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.folder.color,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Contenido scrolleable
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // PDF Preview o Selector
                        if (_selectedPdf != null)
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: _buildPdfPreviewCard(),
                            ),
                          )
                        else
                          _buildSelectPdfCard(),

                        const SizedBox(height: 20),

                        // Campo de título
                        _buildTitleField(bookProvider),

                        const SizedBox(height: 20),

                        // Progreso de subida
                        if (bookProvider.isUploading)
                          _buildUploadProgress(bookProvider),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),

              // Botones de acción (fijos abajo) - SIN SOMBRA
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surface : Colors.white,
                ),
                child: SafeArea(child: _buildActionButtons(bookProvider)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectPdfCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: _pickPDF,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surface : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceVariantDark : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/export.svg',
                  width: 28,
                  height: 28,
                  colorFilter: ColorFilter.mode(
                    isDark ? AppColors.textHintDark : AppColors.textHintLight,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Seleccionar PDF',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Toca para elegir un archivo',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfPreviewCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.folder.color.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // PDF Icon y Info
          Row(
            children: [
              // Icono PDF
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: widget.folder.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/add_pdf.svg',
                    width: 26,
                    height: 26,
                    colorFilter: ColorFilter.mode(
                      widget.folder.color,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Info del archivo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pdfFileName ?? 'Archivo PDF',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: widget.folder.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'PDF',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: widget.folder.color,
                            ),
                          ),
                        ),
                        if (_pdfFileSize != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _formatFileSize(_pdfFileSize!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Botón eliminar
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _removePDF,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: SvgPicture.asset(
                      'assets/icons/close.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Botón cambiar archivo
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _pickPDF,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceVariantDark
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? AppColors.dividerDark
                        : AppColors.dividerLight,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/icons/swap.svg',
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(
                        isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Cambiar archivo',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField(BookProvider bookProvider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            'Título del libro',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              letterSpacing: -0.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              width: 1.5,
            ),
          ),
          child: TextFormField(
            controller: _titleController,
            enabled: !bookProvider.isUploading,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
            decoration: InputDecoration(
              hintText: 'Ingresa el título del libro',
              hintStyle: TextStyle(
                color: isDark
                    ? AppColors.textHintDark
                    : AppColors.textHintLight,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(14),
                child: SvgPicture.asset(
                  'assets/icons/book.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    isDark ? AppColors.textHintDark : AppColors.textHintLight,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              filled: true,
              fillColor: isDark
                  ? theme.colorScheme.surface
                  : const Color(0xFFF5F5F5),
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
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.error, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.error,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'El título es requerido';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUploadProgress(BookProvider bookProvider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.folder.color.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subiendo archivo',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              Text(
                '${(bookProvider.uploadProgress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: widget.folder.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: bookProvider.uploadProgress,
              backgroundColor: isDark ? AppColors.grey800 : AppColors.grey100,
              valueColor: AlwaysStoppedAnimation<Color>(widget.folder.color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BookProvider bookProvider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        // Botón Cancelar
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: isDark ? null : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.grey700 : AppColors.grey300,
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: bookProvider.isUploading
                    ? null
                    : () => Navigator.pop(context),
                child: Center(
                  child: Text(
                    'Cancelar',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: bookProvider.isUploading
                          ? (isDark ? AppColors.grey600 : AppColors.grey400)
                          : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight),
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Botón Guardar
        Expanded(
          flex: 2,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: bookProvider.isUploading
                  ? LinearGradient(
                      colors: [
                        isDark ? AppColors.grey700 : AppColors.grey300,
                        isDark ? AppColors.grey800 : AppColors.grey400,
                      ],
                    )
                  : LinearGradient(
                      colors: [
                        widget.folder.color,
                        widget.folder.color.withValues(alpha: 0.85),
                      ],
                    ),
              boxShadow: bookProvider.isUploading
                  ? null
                  : [
                      BoxShadow(
                        color: widget.folder.color.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: bookProvider.isUploading ? null : _handleSave,
                child: Center(
                  child: bookProvider.isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset(
                              'assets/icons/check.svg',
                              width: 20,
                              height: 20,
                              colorFilter: const ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Guardar libro',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
