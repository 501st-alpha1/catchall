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
  late Future<List<NoteRecord>> _notes;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _notes = NoteStorage.list();
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
      await note.file.delete();

      if (!mounted) return;

      setState(_reload);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note deleted')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not delete note')));
    }
  }

  Future<void> _openNote(NoteRecord note) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NoteDetailScreen(note: note)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Note history')),
      body: FutureBuilder<List<NoteRecord>>(
        future: _notes,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Could not load notes.'));
          }

          final notes = snapshot.data ?? [];

          if (notes.isEmpty) {
            return const Center(child: Text('No saved notes yet.'));
          }

          return ListView.separated(
            itemCount: notes.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final note = notes[index];

              return ListTile(
                title: Text(formatTimestamp(note.createdAt)),
                subtitle: FutureBuilder<String>(
                  future: note.file.readAsString(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Text('Loading…');
                    }

                    final content = snapshot.data!;
                    return Text(
                      content.replaceAll(RegExp(r'\s+'), ' ').trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
                onTap: () => _openNote(note),
                trailing: IconButton(
                  tooltip: 'Delete note',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteNote(note),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
