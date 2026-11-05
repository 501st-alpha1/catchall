import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SshKeyManager {
  SshKeyManager({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _privateSeedKey = 'ssh_private_seed';
  static const _keyComment = 'catchall';

  final FlutterSecureStorage _storage;
  final Ed25519 _algorithm = Ed25519();

  Future<bool> hasKeyPair() async {
    return await _storage.read(key: _privateSeedKey) != null;
  }

  Future<String> generateKeyPair() async {
    if (await hasKeyPair()) {
      throw StateError(
        'An SSH key already exists. Delete it before generating another.',
      );
    }

    final keyPair = await _algorithm.newKeyPair();
    final keyData = await keyPair.extract();
    final seed = keyData.bytes;

    await _storage.write(key: _privateSeedKey, value: base64Encode(seed));

    final publicKey = await getPublicKey();

    if (publicKey == null) {
      throw StateError('Could not retrieve generated SSH public key.');
    }

    return publicKey;
  }

  Future<String?> getPublicKey() async {
    final seed = await _readPrivateSeed();
    if (seed == null) return null;

    final keyPair = await _createSshKeyPair(seed);
    final encodedKey = base64Encode(keyPair.toPublicKey().encode());

    return 'ssh-ed25519 $encodedKey $_keyComment';
  }

  Future<SSHKeyPair?> getPrivateKey() async {
    final seed = await _readPrivateSeed();
    if (seed == null) return null;

    return _createSshKeyPair(seed);
  }

  Future<void> deleteKeyPair() async {
    await _storage.delete(key: _privateSeedKey);
  }

  Future<Uint8List?> _readPrivateSeed() async {
    final encoded = await _storage.read(key: _privateSeedKey);
    if (encoded == null) return null;

    final seed = base64Decode(encoded);

    if (seed.length != 32) {
      throw const FormatException('Stored SSH private key is invalid.');
    }

    return seed;
  }

  Future<OpenSSHEd25519KeyPair> _createSshKeyPair(Uint8List seed) async {
    final keyPair = await _algorithm.newKeyPairFromSeed(seed);
    final keyData = await keyPair.extract();
    final publicKey = await keyPair.extractPublicKey();

    final privateKey = Uint8List.fromList([
      ...keyData.bytes,
      ...publicKey.bytes,
    ]);

    return OpenSSHEd25519KeyPair(
      Uint8List.fromList(publicKey.bytes),
      privateKey,
      _keyComment,
    );
  }
}
