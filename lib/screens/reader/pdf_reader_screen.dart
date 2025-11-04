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

class PdfReaderScreen extends StatefulWidget {
  final BookModel book;
  final int? initialPage;

  const PdfReaderScreen({super.key, required this.book, this.initialPage});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  //Usar PdfControllerPinch en lugar de PdfController
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

      // Inicializar PdfControllerPinch
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
        _showBrightnessPopup = false;
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
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
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
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
          backgroundColor: const Color(
            0xFFE0E0E0,
          ), // Gris claro para separadores
          body: Stack(
            children: [
              Column(
                children: [
                  // Top bar
                  _buildTopBar(readerProvider),

                  // 🔥 CAMBIO 3: Usar PdfViewPinch en lugar de PdfView
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
                            // PDF Viewer
                            PdfViewPinch(
                              controller: _pdfControllerPinch!,

                              // Callbacks
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

                            // Overlay de búsqueda (encima del PDF)
                            if (_searchResults.contains(_currentPage))
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.yellow.shade700,
                                        width: 4,
                                      ),
                                    ),
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.yellow.withValues(
                                            alpha: 0.9,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'Coincidencia: "$_currentSearchQuery"',
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.bold,
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
                bottom: 90,
                right: 16,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.7,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_currentPage/$_totalPages',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
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
                  bottom: 80,
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

  // 🔥 Builder personalizado para páginas con overlay de búsqueda

  Widget _buildTopBar(ReaderProvider readerProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_outlined,
                color: Colors.black54,
                size: 22,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.book.title,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.search_outlined,
                color: readerProvider.controlsLocked
                    ? Colors.grey.shade300
                    : (_showSearchPanel
                          ? AppColors.primary.withValues(alpha: 0.7)
                          : Colors.black54),
                size: 24,
              ),
              onPressed: readerProvider.controlsLocked
                  ? null
                  : _showSearchDialog,
            ),
            if (_showSearchPanel && !readerProvider.controlsLocked)
              IconButton(
                icon: Icon(
                  Icons.close_outlined,
                  color: Colors.red.shade300,
                  size: 24,
                ),
                onPressed: () {
                  setState(() {
                    _showSearchPanel = false;
                    _searchResults.clear();
                    _currentSearchQuery = '';
                  });
                },
              ),
            IconButton(
              icon: Icon(
                Icons.menu_book_outlined,
                color: readerProvider.controlsLocked
                    ? AppColors.primary.withValues(alpha: 0.7)
                    : Colors.black54,
                size: 24,
              ),
              onPressed: () {
                readerProvider.toggleControlsLock();
                if (!mounted) return;

                setState(() {
                  if (readerProvider.controlsLocked) {
                    _showBrightnessPopup = false;
                    _showSearchPanel = false;
                  }
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      readerProvider.controlsLocked
                          ? 'Modo lectura activado - Toca el libro para salir'
                          : 'Modo lectura desactivado',
                    ),
                    duration: const Duration(seconds: 2),
                    backgroundColor: readerProvider.controlsLocked
                        ? AppColors.primary
                        : Colors.grey[700],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ReaderProvider readerProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🆕 Botón de Notas
              IconButton(
                onPressed: () => _showNotesBottomSheet(),
                icon: Stack(
                  children: [
                    Icon(
                      _hasNotesOnCurrentPage ? Icons.note : Icons.note_outlined,
                      color: _hasNotesOnCurrentPage
                          ? AppColors.primary
                          : Colors.black54,
                      size: 24,
                    ),
                    // Badge de cantidad de notas
                    if (_hasNotesOnCurrentPage)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 8,
                            minHeight: 8,
                          ),
                        ),
                      ),
                  ],
                ),
                tooltip: 'Notas',
              ),
              const SizedBox(width: 20),
              IconButton(
                onPressed: () {
                  setState(() {
                    _showBrightnessPopup = !_showBrightnessPopup;
                  });
                },
                icon: Icon(
                  Icons.brightness_6_outlined,
                  color: _showBrightnessPopup
                      ? Colors.amber.shade600
                      : Colors.black54,
                  size: 24,
                ),
                tooltip: 'Brillo',
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: Icon(
                  Icons.nightlight_outlined,
                  color: readerProvider.nightMode
                      ? Colors.amber.shade600
                      : Colors.black54,
                  size: 24,
                ),
                onPressed: () {
                  readerProvider.setNightMode(!readerProvider.nightMode);
                },
                tooltip: 'Modo noche',
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
        // Inicializar stream de notas de esta página
        noteProvider.initPageNotesStream(widget.book.id, _currentPage);

        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
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

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.note_outlined,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notas de la página $_currentPage',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '${noteProvider.notes.length} nota(s)',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: AppColors.primary,
                      ),
                      onPressed: () {
                        Navigator.pop(context); // Cerrar panel actual
                        _showCreateNoteSheet();
                      },
                      tooltip: 'Nueva nota',
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: Colors.grey[300]),

              // Lista de notas
              Expanded(
                child: noteProvider.notes.isEmpty
                    ? _buildEmptyNotesState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: noteProvider.notes.length,
                        itemBuilder: (context, index) {
                          final note = noteProvider.notes[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () {
                                // Aquí podrías abrir el detalle o permitir editar
                                Navigator.pop(context);
                                _showEditNoteSheet(note);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            note.title,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (note.category != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              note.category!,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.orange,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      note.preview,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      note.formattedDate,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
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
        );
      },
    );
  }

  Widget _buildEmptyNotesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_add_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No hay notas en esta página',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toca + para crear una',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.brightness_low, color: Colors.black87, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: Colors.amber,
                inactiveTrackColor: Colors.grey[300],
                thumbColor: Colors.amber,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
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
          const Icon(Icons.brightness_high, color: Colors.black87, size: 18),
        ],
      ),
    );
  }

  Widget _buildSearchResultsPanel() {
    final currentIndex = _searchResults.indexOf(_currentPage);
    final hasResults = currentIndex != -1;

    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.yellow.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.search,
                  size: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_searchResults.length} resultados',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasResults) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.yellow.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.yellow.shade700),
              ),
              child: Text(
                'Actual: ${currentIndex + 1}/${_searchResults.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: currentIndex > 0
                    ? () => _goToPage(_searchResults[currentIndex - 1])
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: const Size(60, 32),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Ant', style: TextStyle(fontSize: 11)),
              ),
              ElevatedButton(
                onPressed: currentIndex < _searchResults.length - 1
                    ? () => _goToPage(_searchResults[currentIndex + 1])
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: const Size(60, 32),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sig', style: TextStyle(fontSize: 11)),
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buscar en el PDF'),
        content: TextField(
          controller: searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ingresa palabra o frase...',
            prefixIcon: Icon(Icons.search),
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
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (searchController.text.isNotEmpty) {
                Navigator.pop(context);
                _performSearch(searchController.text);
              }
            },
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    if (_pdfData == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
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
              content: Text('No se encontró "$query"'),
              backgroundColor: Colors.orange,
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
              content: Text('${foundPages.length} coincidencias encontradas'),
              backgroundColor: Colors.green,
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
            content: Text('Error en búsqueda: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
