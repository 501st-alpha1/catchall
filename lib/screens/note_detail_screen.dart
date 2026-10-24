import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/note_record.dart';
import '../utils/date_time_utils.dart';

import 'note_edit_screen.dart';

class NoteDetailScreen extends StatefulWidget {
  const NoteDetailScreen({super.key, required this.note});

  final NoteRecord note;

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late NoteRecord _note;
  late Future<String> _content;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _content = _note.file.readAsString();
  }

  Future<void> _editNote() async {
    final updatedNote = await Navigator.of(context).push<NoteRecord>(
      MaterialPageRoute<NoteRecord>(
        builder: (_) => NoteEditScreen(note: _note),
      ),
    );

    if (!mounted || updatedNote == null) return;

    setState(() {
      _note = updatedNote;
      _content = _note.file.readAsString();
    });
  }

  Future<void> _copyNote() async {
    try {
      final content = await _content;

      if (!mounted) return;

      await Clipboard.setData(ClipboardData(text: content));

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note copied')));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not read this note')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved note'),
        actions: [
          IconButton(
            tooltip: 'Edit note',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editNote,
          ),
          IconButton(
            tooltip: 'Copy note',
            icon: const Icon(Icons.copy),
            onPressed: _copyNote,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatTimestamp(_note.createdAt),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const Divider(height: 24),
              Expanded(
                child: FutureBuilder<String>(
                  future: _content,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text('Could not read this note.');
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return SingleChildScrollView(
                      child: SelectableText(
                        snapshot.data!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

