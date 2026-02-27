import 'package:pointycastle/export.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// SecurityService implements AES-256-CBC encryption for biometric templates.
///
/// Key derivation: PBKDF2-HMAC-SHA256 with a random 16-byte salt and 100 000
/// iterations, seeded by the userId. This ensures that:
///   - Different encryptions of the same userId produce different keys (random salt)
///   - Brute-force is infeasible (high iteration count)
///   - The salt is stored alongside the ciphertext for decryption
///
/// Ciphertext format: base64( salt[16] + IV[16] + AES_CBC_ciphertext )
class SecurityService {
  static const int _pbkdf2Iterations = 100000;
  static const int _keyLength = 32; // 256 bits
  static const int _saltLength = 16; // 128 bits
  static const int _ivLength = 16; // 128 bits (AES block size)

  // ─── Key Derivation (PBKDF2-HMAC-SHA256) ──────────────────────
  /// Derive a 256-bit AES key from [userId] and a random [salt].
  /// PBKDF2 with 100 000 iterations makes brute-force infeasible.
  Uint8List deriveKey(String userId, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyLength));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(userId)));
  }

  // ─── Random bytes ─────────────────────────────────────────────
  Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }

  // ─── PKCS7 Padding ───────────────────────────────────────────
  Uint8List _pkcs7Pad(Uint8List data) {
    final padLen = 16 - (data.length % 16);
    final padded = Uint8List(data.length + padLen);
    padded.setAll(0, data);
    padded.fillRange(data.length, padded.length, padLen);
    return padded;
  }

  Uint8List _pkcs7Unpad(Uint8List data) {
    if (data.isEmpty) return data;
    final padLen = data.last;
    if (padLen < 1 || padLen > 16) return data;
    return data.sublist(0, data.length - padLen);
  }

  // ─── AES-256-CBC Encrypt ──────────────────────────────────────
  /// Encrypt [plaintext] with AES-256-CBC.
  /// Returns base64(salt[16] + IV[16] + ciphertext).
  String encryptData(String plaintext, String userId) {
    final salt = _randomBytes(_saltLength);
    final iv = _randomBytes(_ivLength);
    final key = deriveKey(userId, salt);

    final cipher = CBCBlockCipher(AESEngine());
    cipher.init(true, ParametersWithIV(KeyParameter(key), iv));

    final input = _pkcs7Pad(Uint8List.fromList(utf8.encode(plaintext)));
    final output = Uint8List(input.length);

    for (int offset = 0; offset < input.length; offset += cipher.blockSize) {
      cipher.processBlock(input, offset, output, offset);
    }

    // Prepend salt + IV so both are available for decryption
    final combined = Uint8List(salt.length + iv.length + output.length);
    combined.setAll(0, salt);
    combined.setAll(salt.length, iv);
    combined.setAll(salt.length + iv.length, output);

    return base64.encode(combined);
  }

  // ─── AES-256-CBC Decrypt ──────────────────────────────────────
  /// Decrypt a base64(salt[16] + IV[16] + ciphertext) string.
  String decryptData(String encryptedBase64, String userId) {
    final combined = base64.decode(encryptedBase64);

    final salt = Uint8List.fromList(combined.sublist(0, _saltLength));
    final iv = combined.sublist(_saltLength, _saltLength + _ivLength);
    final ciphertext = combined.sublist(_saltLength + _ivLength);
    final key = deriveKey(userId, salt);

    final cipher = CBCBlockCipher(AESEngine());
    cipher.init(false, ParametersWithIV(KeyParameter(key), iv));

    final output = Uint8List(ciphertext.length);
    for (int offset = 0; offset < ciphertext.length; offset += cipher.blockSize) {
      cipher.processBlock(ciphertext, offset, output, offset);
    }

    return utf8.decode(_pkcs7Unpad(output));
  }

  // ─── SHA-256 Hash (utility) ────────────────────────────────────
  /// One-way hash for integrity verification (using pointycastle SHA-256)
  String hashData(String data) {
    final digest = SHA256Digest();
    final bytes = Uint8List.fromList(utf8.encode(data));
    final hash = digest.process(bytes);
    return hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Verify data matches stored hash
  bool verifyHash(String data, String expectedHash) {
    return hashData(data) == expectedHash;
  }
}