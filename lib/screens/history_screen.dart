import 'package:flutter/material.dart';

import '../models/note_record.dart';
import '../screens/note_detail_screen.dart';
import '../utils/date_time_utils.dart';
import '../note_storage.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<_SearchableNote>> _notes;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  String _query = '';
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _reload();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<_SearchableNote>> _loadNotes() async {
    final notes = await NoteStorage.list();

    return Future.wait(
      notes.map((note) async {
        final content = await note.file.readAsString();
        return _SearchableNote(note: note, content: content);
      }),
    );
  }

  void _reload() {
    _notes = _loadNotes();
  }

  void _onSearchChanged() {
    setState(() {
      _query = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _toggleReviewed(NoteRecord note) async {
    try {
      await NoteStorage.setReviewed(note, !note.reviewed);

      if (!mounted) return;

      setState(_reload);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update reviewed status')),
      );
    }
  }

  Future<void> _deleteNote(NoteRecord note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This note will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await NoteStorage.delete(note);

      if (!mounted) return;

      setState(_reload);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note deleted')));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not delete note')));
    }
  }

  Future<void> _openNote(NoteRecord note) async {
    _scrollOffset = _scrollController.hasClients ? _scrollController.offset : 0;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NoteDetailScreen(note: note)),
    );

    if (!mounted) return;

    final notesFuture = _loadNotes();
    setState(() {
      _notes = notesFuture;
    });

    await notesFuture;
    if (!mounted) return;

    await WidgetsBinding.instance.endOfFrame;

    if (!_scrollController.hasClients) return;

    final maxOffset = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(_scrollOffset.clamp(0.0, maxOffset).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Note history')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notes',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: _searchController.clear,
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<_SearchableNote>>(
              future: _notes,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Could not load notes.'));
                }

                final allNotes = snapshot.data ?? [];
                final notes = _query.isEmpty
                    ? allNotes
                    : allNotes.where((item) {
                        return item.content.toLowerCase().contains(_query);
                      }).toList();

                if (allNotes.isEmpty) {
                  return const Center(child: Text('No saved notes yet.'));
                }

                if (notes.isEmpty) {
                  return const Center(child: Text('No matching notes.'));
                }

                return ListView.separated(
                  controller: _scrollController,
                  itemCount: notes.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = notes[index];
                    final note = item.note;

                    return ListTile(
                      title: Text(formatTimestamp(note.createdAt)),
                      subtitle: Text(
                        item.content.replaceAll(RegExp(r'\s+'), ' ').trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _openNote(note),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: note.reviewed
                                ? 'Mark as unreviewed'
                                : 'Mark as reviewed',
                            icon: Icon(
                              note.reviewed
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                            ),
                            onPressed: () => _toggleReviewed(note),
                          ),
                          IconButton(
                            tooltip: 'Delete note',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteNote(note),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchableNote {
  const _SearchableNote({required this.note, required this.content});

  final NoteRecord note;
  final String content;
}
