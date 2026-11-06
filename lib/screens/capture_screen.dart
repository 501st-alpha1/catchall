import 'package:flutter/material.dart';

import 'history_screen.dart';
import 'ssh_settings_screen.dart';
import '../note_storage.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _editorFocusNode = FocusNode();

  bool _saving = false;
  DateTime? _customTimestamp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_saving) {
      _editorFocusNode.requestFocus();
    }
  }

  Future<void> _setCustomTimestamp() async {
    final initial = _customTimestamp ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: 'Choose note date',
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Choose note time',
    );

    if (time == null || !mounted) return;

    setState(() {
      _customTimestamp = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String _formatTimestamp(DateTime timestamp) {
    final date = MaterialLocalizations.of(context).formatMediumDate(timestamp);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(timestamp));

    return '$date at $time';
  }

  Future<void> _saveNote() async {
    final content = _controller.text;

    if (content.trim().isEmpty || _saving) return;

    setState(() => _saving = true);

    try {
      await NoteStorage.save(content, createdAt: _customTimestamp);

      if (!mounted) return;

      _controller.clear();
      _customTimestamp = null;
      _editorFocusNode.requestFocus();

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Note saved'),
            duration: Duration(seconds: 1),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catchall'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'timestamp') {
                _setCustomTimestamp();
              } else if (value == 'ssh') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SshSettingsScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'timestamp',
                child: ListTile(
                  leading: Icon(Icons.calendar_month),
                  title: Text('Set note date/time'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'ssh',
                child: ListTile(
                  leading: Icon(Icons.sync),
                  title: Text('SSH transfer settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
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
              if (_customTimestamp != null) ...[
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatTimestamp(_customTimestamp!),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Use current date/time',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() => _customTimestamp = null);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
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
                  textCapitalization: TextCapitalization.none,
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
