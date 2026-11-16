import 'dart:io';

class NoteRecord {
  const NoteRecord({
    required this.file,
    required this.createdAt,
    this.reviewed = false,
  });

  final File file;
  final DateTime createdAt;
  final bool reviewed;
}
