import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../constants/app_constants.dart';

/// AES-GCM encryption matching the web app's encrypt() in encryptionUtils.js
/// Produces { iv, data, tag } as base64 strings
class EncryptionService {
  // AES-256-GCM with 12-byte IV — must match web app's encrypt() in encryptionUtils.js
  static final _algorithm = AesGcm.with256bits(nonceLength: 12);

  static Future<Map<String, String>> encrypt(String plainText, {String? secret}) async {
    final passphrase = secret ?? AppConstants.encryptionSecret;
    final key = await _deriveKey(passphrase);

    final nonce = _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plainText),
      secretKey: key,
      nonce: nonce,
    );

    // secretBox.cipherText = encrypted data WITHOUT tag
    // secretBox.mac.bytes = 16-byte GCM authentication tag
    return {
      'iv': base64.encode(nonce),
      'data': base64.encode(secretBox.cipherText),
      'tag': base64.encode(secretBox.mac.bytes),
    };
  }

  static Future<String> decrypt(Map<String, String> encrypted, {String? secret}) async {
    final passphrase = secret ?? AppConstants.encryptionSecret;
    final key = await _deriveKey(passphrase);

    final iv = base64.decode(encrypted['iv']!);
    final data = base64.decode(encrypted['data']!);
    final tag = base64.decode(encrypted['tag']!);

    final secretBox = SecretBox(data, nonce: iv, mac: Mac(tag));
    final decrypted = await _algorithm.decrypt(secretBox, secretKey: key);
    return utf8.decode(decrypted);
  }

  /// SHA-256 of passphrase → 32-byte key (matches web app's deriveKey)
  static Future<SecretKey> _deriveKey(String passphrase) async {
    final sha256 = Sha256();
    final hash = await sha256.hash(utf8.encode(passphrase));
    // AES-128 uses first 16 bytes, AES-256 uses all 32 — backend uses AES-GCM from 32-byte key
    // Matching: AES-GCM with 256-bit key derived from SHA-256
    return SecretKeyData(Uint8List.fromList(hash.bytes));
  }
}
