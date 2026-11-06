import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

import 'ssh_connection_settings.dart';
import 'ssh_key_manager.dart';

class SshConnection {
  SshConnection({required this.keyManager});

  final SshKeyManager keyManager;

  Future<String> getPresentedHostFingerprint(
    SshConnectionSettings settings,
  ) async {
    if (settings.host.trim().isEmpty ||
        settings.port < 1 ||
        settings.port > 65535) {
      throw StateError('Invalid SSH host or port.');
    }

    final socket = await SSHSocket.connect(settings.host.trim(), settings.port);

    String? fingerprint;

    final client = SSHClient(
      socket,
      username: settings.username.trim().isEmpty
          ? 'fingerprint-check'
          : settings.username.trim(),
      onVerifyHostKey: (type, value) {
        fingerprint = utf8.decode(value);
        return false;
      },
      handshakeTimeout: const Duration(seconds: 15),
    );

    try {
      await client.authenticated;
    } catch (_) {
      if (fingerprint == null) rethrow;
    } finally {
      await client.close();
    }

    if (fingerprint == null) {
      throw StateError('The SSH server did not provide a host key.');
    }

    return fingerprint!;
  }

  Future<void> testConnection(SshConnectionSettings settings) async {
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

    try {
      await client.authenticated;
    } finally {
      await client.close();
    }
  }
}
