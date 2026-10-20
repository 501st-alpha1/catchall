import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/note_record.dart';
import '../utils/date_time_utils.dart';

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
