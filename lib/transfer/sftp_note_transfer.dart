import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dartssh2/dartssh2.dart';

import '../models/note_record.dart';
import 'ssh_connection_settings.dart';
import 'ssh_key_manager.dart';

abstract interface class NoteTransfer {
  Future<NoteTransferResult> transfer(List<NoteRecord> notes);
}

class SftpNoteTransfer implements NoteTransfer {
  SftpNoteTransfer({required this.settings, required this.keyManager});

  final SshConnectionSettings settings;
  final SshKeyManager keyManager;

  @override
  Future<NoteTransferResult> transfer(List<NoteRecord> notes) async {
    if (!settings.isConfigured) {
      throw StateError('SSH connection settings are incomplete.');
    }

    if (!settings.hasTrustedHost) {
      throw StateError('The SSH server host key has not been trusted.');
    }

    final identity = await keyManager.getPrivateKey();

    if (identity == null) {
      throw StateError('No Catchall SSH key has been generated.');
    }

    final socket = await SSHSocket.connect(settings.host.trim(), settings.port);

    final client = SSHClient(
      socket,
      username: settings.username.trim(),
      identities: [identity],
      onVerifyHostKey: (type, fingerprint) {
        return utf8.decode(fingerprint) == settings.hostFingerprint;
      },
      handshakeTimeout: const Duration(seconds: 15),
      authTimeout: const Duration(seconds: 15),
    );

    SftpClient? sftp;

    try {
      await client.authenticated;
      sftp = await client.sftp();

      final destination = _normalizeRemotePath(settings.destination);
      final remoteItems = await sftp.listdir(destination);
      final remoteNames = remoteItems.map((item) => item.filename).toSet();

      var uploaded = 0;
      var unchanged = 0;
      var conflicts = 0;
      final errors = <String>[];

      for (final note in notes) {
        final filename = note.file.uri.pathSegments.last;

        try {
          final localBytes = await note.file.readAsBytes();
          final remotePath = '$destination/$filename';

          if (remoteNames.contains(filename)) {
            final remoteBytes = await _readRemoteFile(sftp, remotePath);

            if (_bytesEqual(localBytes, remoteBytes)) {
              unchanged++;
              continue;
            }

            final conflictPath = await _findConflictPath(
              sftp,
              destination,
              filename,
              localBytes,
              remoteNames,
            );

            if (conflictPath == null) {
              unchanged++;
              continue;
            }

            await _uploadFile(sftp, conflictPath, localBytes);
            remoteNames.add(conflictPath.split('/').last);
            conflicts++;
            continue;
          }

          await _uploadFile(sftp, remotePath, localBytes);
          remoteNames.add(filename);
          uploaded++;
        } catch (error) {
          errors.add('$filename: $error');
        }
      }

      return NoteTransferResult(
        uploaded: uploaded,
        unchanged: unchanged,
        conflicts: conflicts,
        errors: errors,
      );
    } finally {
      await sftp?.close();
      await client.close();
    }
  }

  Future<Uint8List> _readRemoteFile(SftpClient sftp, String path) async {
    final file = await sftp.open(path);

    try {
      return await file.readBytes();
    } finally {
      await file.close();
    }
  }

  Future<String?> _findConflictPath(
    SftpClient sftp,
    String destination,
    String filename,
    Uint8List localBytes,
    Set<String> remoteNames,
  ) async {
    final digest = await Sha256().hash(localBytes);
    final hash = digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()
        .substring(0, 12);

    final dotIndex = filename.lastIndexOf('.');
    final basename = dotIndex > 0 ? filename.substring(0, dotIndex) : filename;
    final extension = dotIndex > 0 ? filename.substring(dotIndex) : '';

    var suffix = 1;

    while (true) {
      final suffixText = suffix == 1 ? '' : '-$suffix';
      final conflictName = '$basename.conflict-$hash$suffixText$extension';
      final conflictPath = '$destination/$conflictName';

      if (!remoteNames.contains(conflictName)) {
        return conflictPath;
      }

      final existingBytes = await _readRemoteFile(sftp, conflictPath);

      if (_bytesEqual(localBytes, existingBytes)) {
        return null;
      }

      suffix++;
    }
  }

  Future<void> _uploadFile(
    SftpClient sftp,
    String destinationPath,
    Uint8List bytes,
  ) async {
    final temporaryPath =
        '$destinationPath.upload-${DateTime.now().microsecondsSinceEpoch}.tmp';

    final file = await sftp.open(
      temporaryPath,
      mode:
          SftpFileOpenMode.create |
          SftpFileOpenMode.exclusive |
          SftpFileOpenMode.write,
    );

    try {
      await file.writeBytes(bytes);
    } catch (_) {
      await file.close();
      try {
        await sftp.remove(temporaryPath);
      } catch (_) {}
      rethrow;
    }

    await file.close();

    try {
      await sftp.rename(temporaryPath, destinationPath);
    } catch (_) {
      try {
        await sftp.remove(temporaryPath);
      } catch (_) {}
      rethrow;
    }
  }

  String _normalizeRemotePath(String path) {
    final normalized = path.trim().replaceAll(RegExp(r'/+$'), '');

    if (normalized.isEmpty || normalized == '.') {
      throw StateError('The remote destination directory is invalid.');
    }

    if (normalized.split('/').contains('..')) {
      throw StateError('The remote destination cannot contain "..".');
    }

    return normalized;
  }

  bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;

    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }

    return true;
  }
}

class NoteTransferResult {
  const NoteTransferResult({
    required this.uploaded,
    required this.unchanged,
    required this.conflicts,
    required this.errors,
  });

  final int uploaded;
  final int unchanged;
  final int conflicts;
  final List<String> errors;

  int get failed => errors.length;

  bool get hasErrors => errors.isNotEmpty;
}
