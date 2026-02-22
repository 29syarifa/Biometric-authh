import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// SecurityService implements AES-256-CBC encryption for biometric templates.
/// Key derivation: SHA-256 of userId ensures per-user unique keys.
/// Each encryption uses a random 16-byte IV, prepended to the ciphertext.
/// Format: base64( IV[16 bytes] + AES_CBC_ciphertext )
class SecurityService {
  // ─── Key Derivation ───────────────────────────────────────────
  /// Derive a 256-bit (32-byte) AES key from userId using SHA-256
  Uint8List deriveKey(String userId) {
    final bytes = utf8.encode('biometric_aes256_$userId');
    final digest = sha256.convert(bytes);
    return Uint8List.fromList(digest.bytes);
  }

  // ─── Random IV ───────────────────────────────────────────────
  Uint8List _generateIV() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
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
  /// Returns base64(IV + ciphertext).
  String encryptData(String plaintext, String userId) {
    final key = deriveKey(userId);
    final iv = _generateIV();

    final cipher = CBCBlockCipher(AESEngine());
    cipher.init(true, ParametersWithIV(KeyParameter(key), iv));

    final input = _pkcs7Pad(Uint8List.fromList(utf8.encode(plaintext)));
    final output = Uint8List(input.length);

    for (int offset = 0; offset < input.length; offset += cipher.blockSize) {
      cipher.processBlock(input, offset, output, offset);
    }

    // Prepend IV so it's available for decryption
    final combined = Uint8List(iv.length + output.length);
    combined.setAll(0, iv);
    combined.setAll(iv.length, output);

    return base64.encode(combined);
  }

  // ─── AES-256-CBC Decrypt ──────────────────────────────────────
  /// Decrypt a base64(IV + ciphertext) string.
  String decryptData(String encryptedBase64, String userId) {
    final key = deriveKey(userId);
    final combined = base64.decode(encryptedBase64);

    final iv = combined.sublist(0, 16);
    final ciphertext = combined.sublist(16);

    final cipher = CBCBlockCipher(AESEngine());
    cipher.init(false, ParametersWithIV(KeyParameter(key), iv));

    final output = Uint8List(ciphertext.length);
    for (int offset = 0; offset < ciphertext.length; offset += cipher.blockSize) {
      cipher.processBlock(ciphertext, offset, output, offset);
    }

    return utf8.decode(_pkcs7Unpad(output));
  }

  // ─── SHA-256 Hash ─────────────────────────────────────────────
  /// One-way hash for integrity verification
  String hashData(String data) {
    final bytes = utf8.encode(data);
    return sha256.convert(bytes).toString();
  }

  /// Verify data matches stored hash
  bool verifyHash(String data, String expectedHash) {
    return hashData(data) == expectedHash;
  }
}