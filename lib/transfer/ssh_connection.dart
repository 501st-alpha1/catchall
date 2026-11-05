import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

import 'ssh_connection_settings.dart';
import 'ssh_key_manager.dart';

class SshConnection {
  SshConnection({required this.keyManager});

  final SshKeyManager keyManager;

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
