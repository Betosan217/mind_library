// lib/screens/notes/notes_list_screen.dart (MEJORADO CON ICONOS SVG)

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/note_model.dart';
import '../../providers/note_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/notes/note_bottom_sheet.dart';
import '../../widgets/notes/note_detail_bottom_sheet.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  String _searchQuery = '';
  String? _filterCategory;

  final GlobalKey _filterButtonKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NoteProvider>().initUserNotesStream();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _searchFocusNode.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset:
            false, // Evita que el FAB se mueva con el teclado
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: SvgPicture.asset(
              'assets/icons/arrow_back.svg',
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(Colors.grey[700]!, BlendMode.srcIn),
            ),
            onPressed: () {
              _searchFocusNode.unfocus();
              Navigator.pop(context);
            },
          ),
          title: const Text(
            'Mis Notas',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 16),
            Expanded(
              child: Consumer<NoteProvider>(
                builder: (context, noteProvider, _) {
                  if (noteProvider.isLoading && noteProvider.notes.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    );
                  }

                  if (noteProvider.notes.isEmpty) {
                    return _buildEmptyState();
                  }

                  List<NoteModel> filteredNotes = noteProvider.notes;

                  if (_searchQuery.isNotEmpty) {
                    filteredNotes = filteredNotes
                        .where(
                          (note) =>
                              note.title.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              ) ||
                              note.content.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              ),
                        )
                        .toList();
                  }

                  if (_filterCategory != null) {
                    filteredNotes = noteProvider.getNotesByCategory(
                      _filterCategory,
                    );
                  }

                  if (filteredNotes.isEmpty) {
                    return _buildNoResultsState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: filteredNotes.length,
                    itemBuilder: (context, index) {
                      return _buildNoteCard(filteredNotes[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: _buildModernFAB(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/icons/search_note.svg',
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(Colors.grey[400]!, BlendMode.srcIn),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar notas...',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                          _searchFocusNode.unfocus();
                        },
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: Colors.grey[400],
                        ),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ),
          ),
          Container(width: 1, height: 24, color: Colors.grey[200]),
          const SizedBox(width: 8),
          GestureDetector(
            key: _filterButtonKey,
            onTap: () {
              _searchFocusNode.unfocus();
              _showFilterPopup();
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _filterCategory != null
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SvgPicture.asset(
                'assets/icons/filter_note.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  _filterCategory != null
                      ? AppColors.primary
                      : Colors.grey[600]!,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(NoteModel note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showNoteDetail(note),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Colors.white,
                      elevation: 8,
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditNoteSheet(note);
                        } else if (value == 'delete') {
                          _confirmDelete(note);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          height: 48,
                          child: Row(
                            children: [
                              SvgPicture.asset(
                                'assets/icons/edit_note.svg',
                                width: 18,
                                height: 18,
                                colorFilter: ColorFilter.mode(
                                  Colors.grey[600]!,
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Editar',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          height: 48,
                          child: Row(
                            children: [
                              SvgPicture.asset(
                                'assets/icons/note_delete.svg',
                                width: 18,
                                height: 18,
                                colorFilter: const ColorFilter.mode(
                                  Colors.red,
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Eliminar',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (note.pageNumber != null) ...[
                      _buildBadge(
                        icon: 'assets/icons/bookmark.svg',
                        label: 'Pág. ${note.pageNumber}',
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (note.category != null) ...[
                      _buildBadge(
                        icon: 'assets/icons/tag.svg',
                        label: note.category!,
                        color: _getCategoryColor(note.category!),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      note.formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
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
  }

  Widget _buildBadge({
    required String icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            icon,
            width: 12,
            height: 12,
            colorFilter: ColorFilter.mode(
              color.withValues(alpha: 0.7),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/note_empty.json',
            width: 120,
            height: 120,
            repeat: true,
            animate: true,
          ),

          const SizedBox(height: 24),
          Text(
            'No tienes notas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea tu primera nota para empezar',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/search_empty.json',
            width: 120,
            height: 120,
            repeat: true,
            animate: true,
          ),
          const SizedBox(height: 24),
          Text(
            'No se encontraron notas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Intenta con otros términos de búsqueda',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildModernFAB() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showCreateNoteSheet(null, null),
          child: Center(
            child: SvgPicture.asset(
              'assets/icons/add_file.svg',
              width: 28,
              height: 28,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterPopup() {
    final RenderBox? button =
        _filterButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (button == null) return;

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );

    const double menuWidth = 200;

    final RelativeRect position = RelativeRect.fromLTRB(
      buttonPosition.dx + button.size.width - menuWidth,
      buttonPosition.dy + button.size.height + 8,
      MediaQuery.of(context).size.width -
          (buttonPosition.dx + button.size.width),
      MediaQuery.of(context).size.height -
          (buttonPosition.dy + button.size.height + 8),
    );

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      color: Colors.white,
      items: [
        _buildFilterItem('Todas', null),
        _buildFilterItem('Resumen', 'Resumen'),
        _buildFilterItem('Importante', 'Importante'),
        _buildFilterItem('Duda', 'Duda'),
        _buildFilterItem('Idea', 'Idea'),
        _buildFilterItem('Pendiente', 'Pendiente'),
      ],
    ).then((value) {
      if (value != null) {
        setState(() {
          _filterCategory = value.isEmpty ? null : value;
        });
      }
    });
  }

  PopupMenuItem<String> _buildFilterItem(String title, String? value) {
    final isSelected = _filterCategory == value;

    return PopupMenuItem<String>(
      value: value ?? '',
      height: 48,
      child: Row(
        children: [
          SvgPicture.asset(
            isSelected
                ? 'assets/icons/check.svg'
                : 'assets/icons/option_select.svg',
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(
              isSelected ? AppColors.primary : Colors.grey[300]!,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateNoteSheet(String? bookId, int? pageNumber) {
    _searchFocusNode.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          NoteBottomSheet(bookId: bookId, pageNumber: pageNumber),
    );
  }

  void _showEditNoteSheet(NoteModel note) {
    _searchFocusNode.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NoteBottomSheet(note: note),
    );
  }

  void _showNoteDetail(NoteModel note) {
    _searchFocusNode.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NoteDetailBottomSheet(note: note),
    );
  }

  void _confirmDelete(NoteModel note) {
    _searchFocusNode.unfocus();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Eliminar Nota',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        content: Text(
          '¿Estás seguro de eliminar "${note.title}"?',
          style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 1.5),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Colors.red, Color(0xFFE53935)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextButton(
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(context);
                final noteProvider = context.read<NoteProvider>();

                navigator.pop();
                final success = await noteProvider.deleteNote(note.id);

                if (!mounted) return;

                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Nota eliminada' : 'Error al eliminar nota',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              },
              child: const Text(
                'Eliminar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Resumen':
        return const Color(0xFF64B5F6);
      case 'Importante':
        return const Color(0xFFEF5350);
      case 'Duda':
        return const Color(0xFFFFB74D);
      case 'Idea':
        return const Color(0xFFBA68C8);
      case 'Pendiente':
        return const Color(0xFF81C784);
      default:
        return Colors.grey;
    }
  }
}
