import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../note_storage.dart';
import '../transfer/ssh_connection.dart';
import '../transfer/ssh_connection_settings.dart';
import '../transfer/ssh_key_manager.dart';
import '../transfer/sftp_note_transfer.dart';

class SshSettingsScreen extends StatefulWidget {
  const SshSettingsScreen({super.key});

  @override
  State<SshSettingsScreen> createState() => _SshSettingsScreenState();
}

class _SshSettingsScreenState extends State<SshSettingsScreen> {
  final _keyManager = SshKeyManager();
  late final SshConnection _connection;

  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _usernameController = TextEditingController();
  final _destinationController = TextEditingController();

  String? _publicKey;
  String? _presentedFingerprint;
  String _trustedFingerprint = '';

  bool _loading = true;
  bool _working = false;
  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    _connection = SshConnection(keyManager: _keyManager);
    _loadSettings();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await SshConnectionSettings.load();
    final hasKey = await _keyManager.hasKeyPair();
    final publicKey = hasKey ? await _keyManager.getPublicKey() : null;

    if (!mounted) return;

    setState(() {
      _hostController.text = settings.host;
      _portController.text = settings.port.toString();
      _usernameController.text = settings.username;
      _destinationController.text = settings.destination;
      _trustedFingerprint = settings.hostFingerprint;
      _hasKey = hasKey;
      _publicKey = publicKey;
      _loading = false;
    });
  }

  SshConnectionSettings _currentSettings() {
    return SshConnectionSettings(
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 0,
      username: _usernameController.text.trim(),
      destination: _destinationController.text.trim(),
      hostFingerprint: _trustedFingerprint,
    );
  }

  Future<void> _saveSettings() async {
    final settings = _currentSettings();

    if (!settings.isConfigured) {
      _showMessage('Please complete all connection settings.');
      return;
    }

    await settings.save();

    if (!mounted) return;
    _showMessage('Settings saved');
  }

  Future<void> _generateKey() async {
    if (_working) return;

    setState(() => _working = true);

    try {
      final publicKey = await _keyManager.generateKeyPair();

      if (!mounted) return;

      setState(() {
        _hasKey = true;
        _publicKey = publicKey;
      });

      _showMessage('SSH key generated');
    } catch (error) {
      if (mounted) _showMessage('Could not generate SSH key: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _copyPublicKey() async {
    final publicKey = _publicKey;
    if (publicKey == null) return;

    await Clipboard.setData(ClipboardData(text: publicKey));

    if (mounted) _showMessage('Public key copied');
  }

  Future<void> _retrieveFingerprint() async {
    if (_working) return;

    final settings = _currentSettings();

    if (settings.host.trim().isEmpty ||
        settings.port < 1 ||
        settings.port > 65535) {
      _showMessage('Enter a valid host and port first.');
      return;
    }

    setState(() => _working = true);

    try {
      final fingerprint = await _connection.getPresentedHostFingerprint(
        settings,
      );

      if (!mounted) return;

      setState(() => _presentedFingerprint = fingerprint);
      _showMessage(
        'Fingerprint retrieved. Verify it against your computer before trusting it.',
      );
    } catch (error) {
      if (mounted) {
        _showMessage('Could not retrieve server fingerprint: $error');
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _trustFingerprint() async {
    final fingerprint = _presentedFingerprint;

    if (fingerprint == null || !fingerprint.startsWith('SHA256:')) {
      _showMessage('Retrieve a valid server fingerprint first.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trust SSH server?'),
        content: SelectableText(
          'Only continue if this fingerprint matches the one '
          'reported by ssh-keygen on your Linux computer:\n\n'
          '$fingerprint',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Trust server'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _currentSettings().saveHostFingerprint(fingerprint);

    if (!mounted) return;

    setState(() {
      _trustedFingerprint = fingerprint;
      _presentedFingerprint = null;
    });

    _showMessage('Server fingerprint saved');
  }

  Future<void> _testConnection() async {
    if (_working) return;

    final settings = _currentSettings();

    if (!settings.isConfigured || !settings.hasTrustedHost) {
      _showMessage('Complete settings and trust the server first.');
      return;
    }

    await settings.save();

    setState(() => _working = true);

    try {
      await _connection.testConnection(settings);

      if (mounted) _showMessage('SSH connection successful');
    } catch (error) {
      if (mounted) _showMessage('SSH connection failed: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _transferNotes() async {
    if (_working) return;

    setState(() => _working = true);

    try {
      final settings = await _currentSettings();
      final notes = await NoteStorage.list();

      if (notes.isEmpty) {
        if (mounted) _showMessage('There are no notes to transfer.');
        return;
      }

      final transfer = SftpNoteTransfer(
        settings: settings,
        keyManager: _keyManager,
      );

      final result = await transfer.transfer(notes);

      if (!mounted) return;

      final summary = [
        '${result.uploaded} uploaded',
        '${result.unchanged} unchanged',
        '${result.conflicts} conflicts',
        if (result.failed > 0) '${result.failed} failed',
      ].join(', ');

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Transfer complete'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(summary),
                if (result.errors.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Files that could not be transferred:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (final error in result.errors)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(error),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        _showMessage('Transfer failed: $error');
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('SSH settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Connection', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _textField(
              label: 'Host or IP address',
              controller: _hostController,
            ),
            const SizedBox(height: 12),
            _textField(
              label: 'Port',
              controller: _portController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _textField(label: 'Username', controller: _usernameController),
            const SizedBox(height: 12),
            _textField(
              label: 'Destination directory',
              controller: _destinationController,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _working ? null : _saveSettings,
              child: const Text('Save settings'),
            ),
            const Divider(height: 32),
            Text('SSH key', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (!_hasKey)
              FilledButton.icon(
                onPressed: _working ? null : _generateKey,
                icon: const Icon(Icons.key),
                label: const Text('Generate SSH key'),
              )
            else ...[
              const Text('A Catchall SSH key has been generated.'),
              const SizedBox(height: 8),
              if (_publicKey != null)
                SelectableText(
                  _publicKey!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              OutlinedButton.icon(
                onPressed: _copyPublicKey,
                icon: const Icon(Icons.copy),
                label: const Text('Copy public key'),
              ),
            ],
            const Divider(height: 32),
            Text(
              'Server identity',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_trustedFingerprint.isNotEmpty) ...[
              const Text('Trusted server fingerprint:'),
              SelectableText(_trustedFingerprint),
            ] else
              const Text('No server fingerprint has been trusted yet.'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _working ? null : _retrieveFingerprint,
              child: const Text('Retrieve server fingerprint'),
            ),
            if (_presentedFingerprint != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Compare this fingerprint with the one reported '
                'by your Linux computer before trusting it:',
              ),
              SelectableText(_presentedFingerprint!),
              FilledButton(
                onPressed: _trustFingerprint,
                child: const Text('Trust this fingerprint'),
              ),
            ],
            const Divider(height: 32),
            FilledButton.icon(
              onPressed: _working || !_hasKey ? null : _testConnection,
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Test SSH connection'),
            ),
            const Divider(height: 32),
            Text('Transfer', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(
              'Transfer all notes to the configured directory. '
              'Existing files are compared and never overwritten.',
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _working ? null : _transferNotes,
              icon: const Icon(Icons.upload),
              label: const Text('Transfer notes'),
            ),
            if (_working) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
