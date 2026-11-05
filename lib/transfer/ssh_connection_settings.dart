import 'package:shared_preferences/shared_preferences.dart';

class SshConnectionSettings {
  const SshConnectionSettings({
    this.host = '',
    this.port = 22,
    this.username = '',
    this.destination = '',
    this.hostFingerprint = '',
  });

  final String host;
  final int port;
  final String username;
  final String destination;
  final String hostFingerprint;

  static const _hostKey = 'ssh_host';
  static const _portKey = 'ssh_port';
  static const _usernameKey = 'ssh_username';
  static const _destinationKey = 'ssh_destination';
  static const _fingerprintKey = 'ssh_host_fingerprint';

  static Future<SshConnectionSettings> load() async {
    final preferences = SharedPreferencesAsync();

    return SshConnectionSettings(
      host: await preferences.getString(_hostKey) ?? '',
      port: await preferences.getInt(_portKey) ?? 22,
      username: await preferences.getString(_usernameKey) ?? '',
      destination: await preferences.getString(_destinationKey) ?? '',
      hostFingerprint: await preferences.getString(_fingerprintKey) ?? '',
    );
  }

  Future<void> save() async {
    final preferences = SharedPreferencesAsync();

    await preferences.setString(_hostKey, host.trim());
    await preferences.setInt(_portKey, port);
    await preferences.setString(_usernameKey, username.trim());
    await preferences.setString(_destinationKey, destination.trim());
    await preferences.setString(_fingerprintKey, hostFingerprint.trim());
  }

  Future<void> saveHostFingerprint(String fingerprint) async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString(_fingerprintKey, fingerprint.trim());
  }

  bool get isConfigured =>
      host.trim().isNotEmpty &&
      port > 0 &&
      port <= 65535 &&
      username.trim().isNotEmpty &&
      destination.trim().isNotEmpty;

  bool get hasTrustedHost => hostFingerprint.startsWith('SHA256:');
}
