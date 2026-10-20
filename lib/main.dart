import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'models/note_record.dart';
import 'screens/note_detail_screen.dart';
import 'utils/date_time_utils.dart';

import 'note_storage.dart';

void main() {
  runApp(const CatchallApp());
}

class CatchallApp extends StatelessWidget {
  const CatchallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catchall',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const CaptureScreen(),
    );
  }
}


class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final content = _controller.text;

    if (content.trim().isEmpty || _saving) return;

    setState(() => _saving = true);

    try {
      await NoteStorage.save(content);

      if (!mounted) return;

      _controller.clear();
      FocusScope.of(context).requestFocus(FocusNode());

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Note saved'),
            duration: Duration(seconds: 1),
          ),
        );

      FocusScope.of(context).requestFocus(_editorFocusNode);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not save note')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  final _editorFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catchall'),
        actions: [
          IconButton(
            tooltip: 'Note history',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _editorFocusNode,
                  autofocus: true,
                  onTap: () {
                    _editorFocusNode.requestFocus();
                  },
                  enabled: !_saving,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  textAlignVertical: TextAlignVertical.top,
                  expands: true,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: 'What do you want to remember?',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {},
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _controller.text.trim().isNotEmpty && !_saving
                      ? _saveNote
                      : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save note'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
