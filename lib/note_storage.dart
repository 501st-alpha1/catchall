import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'models/note_record.dart';
import 'note_metadata_storage.dart';

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

  static Future<File> save(String content, {DateTime? createdAt}) async {
    final directory = await _notesDirectory();
    var timestampDateTime = createdAt ?? DateTime.now();
    var timestamp = _timestamp(timestampDateTime);
    var file = File('${directory.path}/$timestamp.txt');

    while (await file.exists()) {
      timestampDateTime = timestampDateTime.add(
        const Duration(microseconds: 1),
      );
      timestamp = _timestamp(timestampDateTime);
      file = File('${directory.path}/$timestamp.txt');
    }

    await file.writeAsString(content, flush: true);
    return file;
  }

  static Future<File> update(
    NoteRecord note,
    String content, {
    required DateTime createdAt,
  }) async {
    final directory = await _notesDirectory();
    final timestamp = _timestamp(createdAt);
    final destination = File('${directory.path}/$timestamp.txt');
    final sameFile = note.file.absolute.path == destination.absolute.path;

    if (!sameFile && await destination.exists()) {
      throw const FileSystemException(
        'Another note already uses that timestamp.',
      );
    }

    final temporary = File(
      '${directory.path}/.edit-${DateTime.now().microsecondsSinceEpoch}.tmp',
    );

    try {
      await temporary.writeAsString(content, flush: true);
      final updatedFile = await temporary.rename(destination.path);

      if (!sameFile) {
        await note.file.delete();
        await NoteMetadataStorage.renameNote(
          note.file.uri.pathSegments.last,
          updatedFile.uri.pathSegments.last,
        );
      }

      return updatedFile;
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  static Future<void> delete(NoteRecord note) async {
    await note.file.delete();
    await NoteMetadataStorage.deleteNote(note.file.uri.pathSegments.last);
  }

  static Future<NoteRecord> setReviewed(NoteRecord note, bool reviewed) async {
    await NoteMetadataStorage.setReviewed(
      note.file.uri.pathSegments.last,
      reviewed,
    );

    return NoteRecord(
      file: note.file,
      createdAt: note.createdAt,
      reviewed: reviewed,
    );
  }

  static Future<List<NoteRecord>> list() async {
    final directory = await _notesDirectory();
    final reviewedNotes = await NoteMetadataStorage.loadReviewed();
    final records = <NoteRecord>[];

    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.txt')) {
        continue;
      }

      final name = entity.uri.pathSegments.last;
      final timestamp = _parseTimestamp(name);

      if (timestamp != null) {
        records.add(
          NoteRecord(
            file: entity,
            createdAt: timestamp,
            reviewed: reviewedNotes.contains(name),
          ),
        );
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
