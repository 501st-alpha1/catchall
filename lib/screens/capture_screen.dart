import 'package:flutter/material.dart';

import 'history_screen.dart';
import '../note_storage.dart';

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
