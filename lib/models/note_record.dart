import 'dart:io';

class NoteRecord {
  const NoteRecord({required this.file, required this.createdAt});

  final File file;
  final DateTime createdAt;
}
