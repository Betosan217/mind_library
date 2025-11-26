import 'package:flutter/material.dart';
import 'package:mind_library/models/note_model.dart';
import 'package:provider/provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;
import 'package:http/http.dart' as http;
import 'package:screen_brightness/screen_brightness.dart';
import 'package:lottie/lottie.dart';
import 'dart:typed_data';
import '../../models/book_model.dart';
import '../../providers/reader_provider.dart';
import '../../providers/note_provider.dart';
import '../../widgets/notes/note_bottom_sheet.dart';
import '../../utils/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PdfReaderScreen extends StatefulWidget {
  final BookModel book;
  final int? initialPage;

  const PdfReaderScreen({super.key, required this.book, this.initialPage});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  PdfControllerPinch? _pdfControllerPinch;

  bool _isLoading = true;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _showControls = true;
  Uint8List? _pdfData;
  bool _showBrightnessPopup = false;
  bool _hasNotesOnCurrentPage = false;

  // Búsqueda
  List<int> _searchResults = [];
  String _currentSearchQuery = '';
  bool _showSearchPanel = false;

  @override
  void initState() {
    super.initState();
    _initializePdf();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotesOnPage();
    });
  }

  Future<void> _initializePdf() async {
    try {
      final pdfData = await _downloadPdfData(widget.book.pdfUrl);
      if (!mounted) return;

      _pdfData = pdfData;

      final readerProvider = context.read<ReaderProvider>();
      await readerProvider.loadLastPage(widget.book.id);
      readerProvider.initStreams(widget.book.id);

      final savedPage = widget.initialPage ?? readerProvider.currentPage;

      _pdfControllerPinch = PdfControllerPinch(
        document: PdfDocument.openData(pdfData),
        initialPage: savedPage,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar PDF: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<Uint8List> _downloadPdfData(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Error al descargar PDF: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de red: $e');
    }
  }

  @override
  void dispose() {
    final readerProvider = context.read<ReaderProvider>();
    readerProvider.saveProgress(widget.book.id);
    _pdfControllerPinch?.dispose();
    super.dispose();
  }

  void _toggleControls() {
    final readerProvider = context.read<ReaderProvider>();
    if (!readerProvider.controlsLocked) {
      setState(() {
        _showControls = !_showControls;
        if (!_showControls) {
          _showBrightnessPopup = false;
        }
      });
    }
  }

  void _goToPage(int page) {
    if (_pdfControllerPinch != null && page >= 1 && page <= _totalPages) {
      _pdfControllerPinch!.animateToPage(
        pageNumber: page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _checkNotesOnPage() async {
    final noteProvider = context.read<NoteProvider>();
    final hasNotes = await noteProvider.hasNotesOnPage(
      widget.book.id,
      _currentPage,
    );
    if (mounted) {
      setState(() {
        _hasNotesOnCurrentPage = hasNotes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/animations/sync_data.json',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Cargando ${widget.book.title}...',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary.withValues(alpha: 0.8),
                  ),
                  backgroundColor: theme.brightness == Brightness.light
                      ? AppColors.grey200
                      : AppColors.grey800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<ReaderProvider>(
      builder: (context, readerProvider, _) {
        return Scaffold(
          backgroundColor: colorScheme.surfaceContainerHighest,
          body: Stack(
            children: [
              Column(
                children: [
                  // Top bar
                  _buildTopBar(readerProvider),

                  // PDF Viewer
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!readerProvider.controlsLocked) {
                          _toggleControls();
                        }
                      },
                      child: ColorFiltered(
                        colorFilter: readerProvider.nightMode
                            ? ColorFilter.mode(
                                Colors.amber.withValues(alpha: 0.1),
                                BlendMode.darken,
                              )
                            : const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.multiply,
                              ),
                        child: Stack(
                          children: [
                            PdfViewPinch(
                              controller: _pdfControllerPinch!,
                              onPageChanged: (page) {
                                setState(() {
                                  _currentPage = page;
                                });
                                readerProvider.updateCurrentPage(page);
                                _checkNotesOnPage();
                              },
                              onDocumentLoaded: (document) {
                                setState(() {
                                  _totalPages = document.pagesCount;
                                });
                                readerProvider.updateTotalPages(
                                  document.pagesCount,
                                );
                              },
                              onDocumentError: (error) {
                                debugPrint('Error PDF: $error');
                              },
                              builders:
                                  PdfViewPinchBuilders<DefaultBuilderOptions>(
                                    options: const DefaultBuilderOptions(),
                                    documentLoaderBuilder: (_) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    pageLoaderBuilder: (_) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    errorBuilder: (_, error) =>
                                        Center(child: Text('Error: $error')),
                                  ),
                            ),

                            // Overlay de búsqueda
                            if (_searchResults.contains(_currentPage))
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: AppColors.highlightYellow,
                                        width: 3,
                                      ),
                                    ),
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.highlightYellow
                                              .withValues(alpha: 0.95),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.1,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          'Coincidencia: "$_currentSearchQuery"',
                                          style: TextStyle(
                                            color:
                                                theme.brightness ==
                                                    Brightness.light
                                                ? AppColors.textPrimaryLight
                                                : AppColors.textPrimaryDark,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom bar
                  if (!readerProvider.controlsLocked &&
                      (_showControls || _showBrightnessPopup))
                    _buildBottomBar(readerProvider),
                ],
              ),

              // Indicador de página flotante
              Positioned(
                bottom: _showControls || _showBrightnessPopup ? 85 : 30,
                right: 20,
                child: AnimatedOpacity(
                  opacity: _showControls || _showBrightnessPopup ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: theme.brightness == Brightness.light
                              ? AppColors.shadowLight
                              : AppColors.shadowDark,
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_currentPage',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          ' / $_totalPages',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Panel de búsqueda
              if (_showSearchPanel &&
                  _searchResults.isNotEmpty &&
                  !readerProvider.controlsLocked)
                Positioned(
                  top: 80,
                  right: 16,
                  child: _buildSearchResultsPanel(),
                ),

              // Popup de brillo
              if (_showBrightnessPopup && !readerProvider.controlsLocked)
                Positioned(
                  bottom: 75,
                  left: 20,
                  right: 20,
                  child: _buildBrightnessPopup(readerProvider),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(ReaderProvider readerProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.light
                ? AppColors.shadowLight
                : AppColors.shadowDark,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Botón de retroceso
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: SvgPicture.asset(
                      'assets/icons/arrow_back.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onSurface.withValues(alpha: 0.8),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // Título del libro
              Expanded(
                child: Text(
                  widget.book.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(width: 8),

              // Botón de búsqueda
              _buildTopBarButton(
                icon: SvgPicture.asset(
                  'assets/icons/search_status.svg',
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(
                    readerProvider.controlsLocked
                        ? AppColors.grey300
                        : (_showSearchPanel
                              ? colorScheme.primary.withValues(alpha: 0.8)
                              : colorScheme.onSurface),
                    BlendMode.srcIn,
                  ),
                ),
                onTap: readerProvider.controlsLocked ? null : _showSearchDialog,
                isActive: _showSearchPanel,
              ),

              // Botón de cerrar búsqueda
              if (_showSearchPanel && !readerProvider.controlsLocked)
                _buildTopBarButton(
                  icon: SvgPicture.asset(
                    'assets/icons/close.svg',
                    width: 22,
                    height: 22,
                    colorFilter: ColorFilter.mode(
                      AppColors.error.withValues(alpha: 0.7),
                      BlendMode.srcIn,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _showSearchPanel = false;
                      _searchResults.clear();
                      _currentSearchQuery = '';
                    });
                  },
                ),

              // Botón de modo lectura
              _buildTopBarButton(
                icon: SvgPicture.asset(
                  'assets/icons/book_open.svg',
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(
                    readerProvider.controlsLocked
                        ? colorScheme.primary.withValues(alpha: 0.8)
                        : colorScheme.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
                onTap: () {
                  readerProvider.toggleControlsLock();
                  if (!mounted) return;

                  setState(() {
                    if (readerProvider.controlsLocked) {
                      _showBrightnessPopup = false;
                      _showSearchPanel = false;
                      _showControls = false;
                    }
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        readerProvider.controlsLocked
                            ? 'Modo lectura activado'
                            : 'Modo lectura desactivado',
                        style: const TextStyle(fontSize: 14),
                      ),
                      duration: const Duration(seconds: 2),
                      backgroundColor: readerProvider.controlsLocked
                          ? colorScheme.primary.withValues(alpha: 0.9)
                          : AppColors.grey700,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
                isActive: readerProvider.controlsLocked,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBarButton({
    required Widget icon,
    required VoidCallback? onTap,
    bool isActive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: icon,
        ),
      ),
    );
  }

  Widget _buildBottomBar(ReaderProvider readerProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.light
                ? AppColors.shadowLight
                : AppColors.shadowDark,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Botón de Notas
              _buildBottomBarButton(
                icon: SvgPicture.asset(
                  _hasNotesOnCurrentPage
                      ? 'assets/icons/note_filled.svg'
                      : 'assets/icons/note_bord.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    _hasNotesOnCurrentPage
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.6),
                    BlendMode.srcIn,
                  ),
                ),
                label: 'Notas',
                onTap: _showNotesBottomSheet,
                hasNotification: _hasNotesOnCurrentPage,
              ),

              // Botón de Brillo
              _buildBottomBarButton(
                icon: SvgPicture.asset(
                  'assets/icons/lamp.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    _showBrightnessPopup
                        ? AppColors.warning
                        : colorScheme.onSurface.withValues(alpha: 0.6),
                    BlendMode.srcIn,
                  ),
                ),
                label: 'Brillo',
                onTap: () {
                  setState(() {
                    _showBrightnessPopup = !_showBrightnessPopup;
                    if (_showBrightnessPopup) {
                      _showControls = true;
                    }
                  });
                },
                isActive: _showBrightnessPopup,
              ),

              // Botón de Modo Noche
              _buildBottomBarButton(
                icon: SvgPicture.asset(
                  readerProvider.nightMode
                      ? 'assets/icons/moon_filled.svg'
                      : 'assets/icons/moon.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    readerProvider.nightMode
                        ? AppColors.warning
                        : colorScheme.onSurface.withValues(alpha: 0.6),
                    BlendMode.srcIn,
                  ),
                ),
                label: 'Noche',
                onTap: () {
                  setState(() {
                    readerProvider.setNightMode(!readerProvider.nightMode);
                  });
                },
                isActive: readerProvider.nightMode,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBarButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    bool hasNotification = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  icon,
                  if (hasNotification)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive || hasNotification
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildNotesPanel(),
    );
  }

  Widget _buildNotesPanel() {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, _) {
        noteProvider.initPageNotesStream(widget.book.id, _currentPage);

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.light
                          ? AppColors.grey300
                          : AppColors.grey700,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SvgPicture.asset(
                        'assets/icons/note_icon.svg',
                        width: 22,
                        height: 22,
                        colorFilter: ColorFilter.mode(
                          colorScheme.primary.withValues(alpha: 0.8),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notas - Página $_currentPage',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${noteProvider.notes.length} nota${noteProvider.notes.length != 1 ? 's' : ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _showCreateNoteSheet();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          child: SvgPicture.asset(
                            'assets/icons/add_file.svg',
                            width: 24,
                            height: 24,
                            colorFilter: ColorFilter.mode(
                              colorScheme.primary.withValues(alpha: 0.8),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(
                height: 1,
                color: theme.brightness == Brightness.light
                    ? AppColors.dividerLight
                    : AppColors.dividerDark,
              ),

              // Lista de notas
              Expanded(
                child: noteProvider.notes.isEmpty
                    ? _buildEmptyNotesState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: noteProvider.notes.length,
                        itemBuilder: (context, index) {
                          final note = noteProvider.notes[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.brightness == Brightness.light
                                    ? AppColors.dividerLight
                                    : AppColors.dividerDark,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.brightness == Brightness.light
                                      ? AppColors.shadowLight
                                      : Colors.transparent,
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  _showEditNoteSheet(note);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              note.title,
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    fontSize: 15,
                                                    letterSpacing: -0.2,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (note.category != null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.folderOrange
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                note.category!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.folderOrange
                                                      .withValues(alpha: 0.9),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        note.preview,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: colorScheme.onSurface
                                                  .withValues(alpha: 0.8),
                                              height: 1.4,
                                            ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          SvgPicture.asset(
                                            'assets/icons/clock.svg',
                                            width: 12,
                                            height: 12,
                                            colorFilter: ColorFilter.mode(
                                              colorScheme.onSurface.withValues(
                                                alpha: 0.5,
                                              ),
                                              BlendMode.srcIn,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            note.formattedDate,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme.onSurface
                                                      .withValues(alpha: 0.6),
                                                  fontWeight: FontWeight.w500,
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
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyNotesState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              'assets/icons/add_file.svg',
              width: 48,
              height: 48,
              colorFilter: ColorFilter.mode(
                colorScheme.onSurface.withValues(alpha: 0.4),
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No hay notas en esta página',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Toca + para crear tu primera nota',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateNoteSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          NoteBottomSheet(bookId: widget.book.id, pageNumber: _currentPage),
    );
  }

  void _showEditNoteSheet(NoteModel note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NoteBottomSheet(note: note),
    );
  }

  Widget _buildBrightnessPopup(ReaderProvider readerProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.light
                ? AppColors.shadowLight
                : AppColors.shadowDark,
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SvgPicture.asset(
                  'assets/icons/lamp.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    AppColors.warning.withValues(alpha: 0.8),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Ajustar brillo',
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SvgPicture.asset(
                'assets/icons/sun_low.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  colorScheme.onSurface.withValues(alpha: 0.6),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: AppColors.warning.withValues(alpha: 0.8),
                    inactiveTrackColor: theme.brightness == Brightness.light
                        ? AppColors.grey200
                        : AppColors.grey700,
                    thumbColor: AppColors.warning,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                      elevation: 2,
                    ),
                    overlayColor: AppColors.warning.withValues(alpha: 0.2),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                  ),
                  child: Slider(
                    value: readerProvider.brightness,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (value) async {
                      try {
                        await ScreenBrightness().setApplicationScreenBrightness(
                          value,
                        );
                        readerProvider.setBrightness(value);
                      } catch (e) {
                        debugPrint('Error ajustando brillo: $e');
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SvgPicture.asset(
                'assets/icons/sun_high.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  colorScheme.onSurface.withValues(alpha: 0.6),
                  BlendMode.srcIn,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${(readerProvider.brightness * 100).toInt()}%',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsPanel() {
    final currentIndex = _searchResults.indexOf(_currentPage);
    final hasResults = currentIndex != -1;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.light
                ? AppColors.shadowLight
                : AppColors.shadowDark,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.highlightYellow.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SvgPicture.asset(
                  'assets/icons/search_status.svg',
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(
                    AppColors.warning.withValues(alpha: 0.8),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_searchResults.length} resultado${_searchResults.length != 1 ? 's' : ''}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (hasResults)
                      Text(
                        'Coincidencia ${currentIndex + 1}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (hasResults) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.highlightYellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.highlightYellow.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                'Página $_currentPage',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: currentIndex > 0
                      ? colorScheme.primary.withValues(alpha: 0.1)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: currentIndex > 0
                        ? () => _goToPage(_searchResults[currentIndex - 1])
                        : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/arrow_left.svg',
                            width: 14,
                            height: 14,
                            colorFilter: ColorFilter.mode(
                              currentIndex > 0
                                  ? colorScheme.primary.withValues(alpha: 0.8)
                                  : AppColors.grey400,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Anterior',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: currentIndex > 0
                                  ? colorScheme.primary.withValues(alpha: 0.8)
                                  : AppColors.grey400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Material(
                  color: currentIndex < _searchResults.length - 1
                      ? colorScheme.primary.withValues(alpha: 0.1)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: currentIndex < _searchResults.length - 1
                        ? () => _goToPage(_searchResults[currentIndex + 1])
                        : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Siguiente',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: currentIndex < _searchResults.length - 1
                                  ? colorScheme.primary.withValues(alpha: 0.8)
                                  : AppColors.grey400,
                            ),
                          ),
                          const SizedBox(width: 4),
                          SvgPicture.asset(
                            'assets/icons/arrow_right.svg',
                            width: 14,
                            height: 14,
                            colorFilter: ColorFilter.mode(
                              currentIndex < _searchResults.length - 1
                                  ? colorScheme.primary.withValues(alpha: 0.8)
                                  : AppColors.grey400,
                              BlendMode.srcIn,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    final TextEditingController searchController = TextEditingController(
      text: _currentSearchQuery,
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SvgPicture.asset(
                'assets/icons/search_status.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  colorScheme.primary.withValues(alpha: 0.8),
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Buscar en el PDF',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: searchController,
          autofocus: true,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Palabra o frase...',
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: SvgPicture.asset(
                'assets/icons/search_status.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  colorScheme.onSurface.withValues(alpha: 0.5),
                  BlendMode.srcIn,
                ),
              ),
            ),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.pop(context);
              _performSearch(value);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (searchController.text.isNotEmpty) {
                Navigator.pop(context);
                _performSearch(searchController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary.withValues(alpha: 0.9),
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Buscar',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    if (_pdfData == null) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  colorScheme.primary.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Buscando...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final sf_pdf.PdfDocument document = sf_pdf.PdfDocument(
        inputBytes: _pdfData!,
      );
      List<int> foundPages = [];

      for (int i = 0; i < document.pages.count; i++) {
        final sf_pdf.PdfTextExtractor extractor = sf_pdf.PdfTextExtractor(
          document,
        );
        final String text = extractor.extractText(
          startPageIndex: i,
          endPageIndex: i,
        );

        if (text.toLowerCase().contains(query.toLowerCase())) {
          foundPages.add(i + 1);
        }
      }

      document.dispose();

      if (mounted) {
        Navigator.pop(context);

        if (foundPages.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/information.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      Colors.white.withValues(alpha: 0.9),
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No se encontró "$query"',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.warning.withValues(alpha: 0.9),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          setState(() {
            _searchResults = foundPages;
            _currentSearchQuery = query;
            _showSearchPanel = true;
          });

          _goToPage(foundPages.first);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/check.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      Colors.white.withValues(alpha: 0.9),
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${foundPages.length} coincidencia${foundPages.length != 1 ? 's' : ''} encontrada${foundPages.length != 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.success.withValues(alpha: 0.9),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/error.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    Colors.white.withValues(alpha: 0.9),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error en búsqueda: $e',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.error.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}
