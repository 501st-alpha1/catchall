import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const CaptureScreen(),
    );
  }
}

class NoteStorage {
  static Future<Directory> _notesDirectory() async {
    final appDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory('${appDirectory.path}/notes');

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  static String _timestamp(DateTime dateTime) {
    String pad(int value, int width) => value.toString().padLeft(width, '0');

    return '${dateTime.year}-'
        '${pad(dateTime.month, 2)}-'
        '${pad(dateTime.day, 2)}_'
        '${pad(dateTime.hour, 2)}-'
        '${pad(dateTime.minute, 2)}-'
        '${pad(dateTime.second, 2)}-'
        '${pad(dateTime.millisecond, 3)}'
        '${pad(dateTime.microsecond, 3)}';
  }

  static Future<File> save(String content) async {
    final directory = await _notesDirectory();
    final timestamp = _timestamp(DateTime.now());
    final file = File('${directory.path}/$timestamp.txt');

    await file.writeAsString(content, flush: true);
    return file;
  }

  static Future<List<NoteRecord>> list() async {
    final directory = await _notesDirectory();
    final records = <NoteRecord>[];

    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.txt')) {
        continue;
      }

      final name = entity.uri.pathSegments.last;
      final timestamp = _parseTimestamp(name);

      if (timestamp != null) {
        records.add(NoteRecord(file: entity, createdAt: timestamp));
      }
    }

    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  static DateTime? _parseTimestamp(String filename) {
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})-(\d{6})\.txt$',
    ).firstMatch(filename);

    if (match == null) return null;

    try {
      final microseconds = int.parse(match.group(7)!);
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
        int.parse(match.group(6)!),
        microseconds ~/ 1000,
        microseconds % 1000,
      );
    } on FormatException {
      return null;
    }
  }
}

class NoteRecord {
  const NoteRecord({required this.file, required this.createdAt});

  final File file;
  final DateTime createdAt;
}

String formatTimestamp(DateTime dateTime) {
  String pad(int value) => value.toString().padLeft(2, '0');

  return '${dateTime.year}-${pad(dateTime.month)}-'
      '${pad(dateTime.day)} '
      '${pad(dateTime.hour)}:${pad(dateTime.minute)}:'
      '${pad(dateTime.second)}';
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

class NoteDetailScreen extends StatelessWidget {
  const NoteDetailScreen({super.key, required this.note});

  final NoteRecord note;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved note'),
        actions: [
          IconButton(
            tooltip: 'Copy note',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              final content = await note.file.readAsString();

              if (!context.mounted) return;

              await Clipboard.setData(ClipboardData(text: content));

              if (!context.mounted) return;

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Note copied')));
            },
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
                formatTimestamp(note.createdAt),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const Divider(height: 24),
              Expanded(
                child: FutureBuilder<String>(
                  future: note.file.readAsString(),
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
