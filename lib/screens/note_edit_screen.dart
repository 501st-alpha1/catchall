import 'dart:io';

import 'package:flutter/material.dart';

import '../models/note_record.dart';
import '../note_storage.dart';
import '../utils/date_time_utils.dart';

class NoteEditScreen extends StatefulWidget {
  const NoteEditScreen({super.key, required this.note});

  final NoteRecord note;

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  late DateTime _timestamp;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  bool get _timestampChanged => _timestamp != widget.note.createdAt;

  @override
  void initState() {
    super.initState();
    _timestamp = widget.note.createdAt;
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final content = await widget.note.file.readAsString();

      if (!mounted) return;

      _controller.text = content;
      setState(() => _loading = false);
      _focusNode.requestFocus();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _loadError = 'Could not read this note.';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _changeTimestamp() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _timestamp,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: 'Choose note date',
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_timestamp),
      helpText: 'Choose note time',
    );

    if (time == null || !mounted) return;

    setState(() {
      _timestamp = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _saveChanges() async {
    if (_saving || _loading || _loadError != null) return;

    setState(() => _saving = true);

    try {
      final updatedFile = await NoteStorage.update(
        widget.note,
        _controller.text,
        createdAt: _timestamp,
      );

      if (!mounted) return;

      Navigator.of(
        context,
      ).pop(NoteRecord(file: updatedFile, createdAt: _timestamp));
    } on FileSystemException catch (error) {
      if (!mounted) return;

      final message = error.message.contains('already uses that timestamp')
          ? 'Another note already has that timestamp. Choose a different time.'
          : 'Could not save changes. Your original note should still be available.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save changes. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit note'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'timestamp') {
                _changeTimestamp();
              } else if (value == 'reset') {
                setState(() => _timestamp = widget.note.createdAt);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'timestamp',
                child: ListTile(
                  leading: Icon(Icons.calendar_month),
                  title: Text('Change note date/time'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (_timestampChanged)
                const PopupMenuItem(
                  value: 'reset',
                  child: ListTile(
                    leading: Icon(Icons.restore),
                    title: Text('Keep original date/time'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_timestampChanged) ...[
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        formatTimestamp(_timestamp),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Keep original date/time',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() => _timestamp = widget.note.createdAt);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _loadError != null
                    ? Center(child: Text(_loadError!))
                    : TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        onTap: () => _focusNode.requestFocus(),
                        enabled: !_saving,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.none,
                        textAlignVertical: TextAlignVertical.top,
                        expands: true,
                        maxLines: null,
                        decoration: const InputDecoration(
                          hintText: 'Edit your note',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: !_loading && _loadError == null && !_saving
                      ? _saveChanges
                      : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
