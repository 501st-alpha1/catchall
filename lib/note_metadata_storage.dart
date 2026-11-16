import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class NoteMetadataStorage {
  static Future<File> _metadataFile() async {
    final appDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory('${appDirectory.path}/metadata');

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return File('${directory.path}/notes.json');
  }

  static Future<Set<String>> loadReviewed() async {
    final file = await _metadataFile();

    if (!await file.exists()) {
      return {};
    }

    final decoded = jsonDecode(await file.readAsString());

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid note metadata file.');
    }

    return decoded.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toSet();
  }

  static Future<void> setReviewed(String filename, bool reviewed) async {
    final reviewedNotes = await loadReviewed();

    if (reviewed) {
      reviewedNotes.add(filename);
    } else {
      reviewedNotes.remove(filename);
    }

    await _save(reviewedNotes);
  }

  static Future<void> renameNote(String oldFilename, String newFilename) async {
    if (oldFilename == newFilename) return;

    final reviewedNotes = await loadReviewed();

    if (reviewedNotes.remove(oldFilename)) {
      reviewedNotes.add(newFilename);
      await _save(reviewedNotes);
    }
  }

  static Future<void> deleteNote(String filename) async {
    final reviewedNotes = await loadReviewed();

    if (reviewedNotes.remove(filename)) {
      await _save(reviewedNotes);
    }
  }

  static Future<void> _save(Set<String> reviewedNotes) async {
    final file = await _metadataFile();
    final temporary = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );

    try {
      final metadata = {for (final filename in reviewedNotes) filename: true};

      await temporary.writeAsString(jsonEncode(metadata), flush: true);

      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }
}
