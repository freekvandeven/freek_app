import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Handles all cryptographic operations for the Password Vault.
///
/// Uses AES-256-CBC with random IV per encryption. Key is derived from
/// master password + salt via PBKDF2-like SHA-256 stretching.
class VaultCrypto {
  /// Derives a 256-bit AES key from [masterPassword] and [salt].
  /// Uses iterated SHA-256 hashing as a key derivation function.
  static Uint8List deriveKey(String masterPassword, String salt) {
    List<int> bytes = utf8.encode(masterPassword + salt);
    // Iterate 100,000 rounds of SHA-256 for key stretching
    for (var i = 0; i < 100000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return Uint8List.fromList(bytes);
  }

  /// Creates a verification hash for the master password.
  /// This is stored to verify the master password without storing it.
  static String createVerificationHash(String masterPassword, String salt) {
    final key = deriveKey(masterPassword, salt);
    // Hash the derived key with an additional marker to create verification hash
    final verificationBytes = sha256.convert([
      ...key,
      ...utf8.encode('vault_verify'),
    ]).bytes;
    return base64.encode(verificationBytes);
  }

  /// Verifies a master password against a stored verification hash.
  static bool verifyMasterPassword(
    String masterPassword,
    String salt,
    String storedHash,
  ) {
    return createVerificationHash(masterPassword, salt) == storedHash;
  }

  /// Encrypts [plaintext] using AES-256-CBC with a random IV.
  /// Returns a base64-encoded string of "IV:ciphertext".
  static String encryptField(String plaintext, Uint8List keyBytes) {
    final key = enc.Key(keyBytes);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypts a string produced by [encryptField].
  static String decryptField(String encrypted, Uint8List keyBytes) {
    final parts = encrypted.split(':');
    if (parts.length != 2) {
      throw const FormatException('Invalid encrypted data');
    }
    final iv = enc.IV.fromBase64(parts[0]);
    final key = enc.Key(keyBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt64(parts[1], iv: iv);
  }

  /// Generates a cryptographically random salt.
  static String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64.encode(bytes);
  }

  /// Generates a random password with the given length and character sets.
  static String generatePassword({
    int length = 20,
    bool uppercase = true,
    bool lowercase = true,
    bool digits = true,
    bool special = true,
  }) {
    final chars = StringBuffer();
    if (uppercase) chars.write('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
    if (lowercase) chars.write('abcdefghijklmnopqrstuvwxyz');
    if (digits) chars.write('0123456789');
    if (special) chars.write('!@#\$%^&*()_+-=[]{}|;:,.<>?');
    if (chars.isEmpty) chars.write('abcdefghijklmnopqrstuvwxyz');

    final charSet = chars.toString();
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charSet[random.nextInt(charSet.length)],
    ).join();
  }
}
