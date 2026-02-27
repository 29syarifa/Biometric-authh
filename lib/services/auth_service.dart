import 'package:shared_preferences/shared_preferences.dart';
import 'package:pointycastle/export.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class AuthService {
  static const String _userKey = 'user_data';
  static const String _biometricKey = 'biometric_enabled';

  /// Number of PBKDF2 iterations — high count to resist brute-force.
  static const int _pbkdf2Iterations = 100000;
  static const int _saltLength = 16; // 128-bit random salt
  static const int _keyLength = 32; // 256-bit derived hash

  // ─── PBKDF2-HMAC-SHA256 password hashing with random salt ─────
  // Returns "salt_hex:hash_hex" so the salt is stored alongside the hash.
  // PBKDF2 is intentionally slow (100 000 iterations) to resist brute-force
  // and rainbow-table attacks, unlike plain SHA-256 which is a fast hash.

  /// Generate a cryptographically secure random salt.
  Uint8List _generateSalt() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(_saltLength, (_) => rng.nextInt(256)));
  }

  /// Derive a 256-bit key from [password] and [salt] using PBKDF2-HMAC-SHA256.
  Uint8List _pbkdf2(String password, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyLength));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Hash [password] with a fresh random salt.
  /// Returns "salt_hex:hash_hex".
  String _hashPassword(String password) {
    final salt = _generateSalt();
    final hash = _pbkdf2(password, salt);
    final saltHex = salt.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final hashHex = hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$saltHex:$hashHex';
  }

  /// Verify [password] against a stored "salt_hex:hash_hex" string.
  bool _verifyPassword(String password, String stored) {
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    final saltHex = parts[0];
    final expectedHashHex = parts[1];
    // Reconstruct salt bytes
    final salt = Uint8List.fromList(
      List.generate(saltHex.length ~/ 2,
          (i) => int.parse(saltHex.substring(i * 2, i * 2 + 2), radix: 16)),
    );
    final hash = _pbkdf2(password, salt);
    final hashHex = hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return hashHex == expectedHashHex;
  }

  // Check if user is registered
  Future<bool> hasRegisteredUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_userKey);
  }

  // Register new user
  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final userData = {
        'username': username,
        'email': email,
        'password': _hashPassword(password), // PBKDF2-HMAC-SHA256 + random salt
        'created_at': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(_userKey, jsonEncode(userData));
      return true;
    } catch (e) {
      debugPrint('Registration error: $e');
      return false;
    }
  }

  // Login user
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(_userKey);
      
      if (userDataString == null) return false;
      
      final userData = jsonDecode(userDataString) as Map<String, dynamic>;
      
      // Check credentials — PBKDF2 verify (re-derives key from stored salt)
      if (userData['email'] == email &&
          _verifyPassword(password, userData['password'] as String)) {
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  // Get current user data
  Future<Map<String, String>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(_userKey);
      
      if (userDataString == null) return null;
      
      final userData = jsonDecode(userDataString) as Map<String, dynamic>;
      
      return {
        'username': userData['username'] as String,
        'email': userData['email'] as String,
      };
    } catch (e) {
      debugPrint('Get user error: $e');
      return null;
    }
  }

  // Check if biometric is enabled
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricKey) ?? false;
  }

  // Enable biometric authentication
  Future<void> enableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, true);
  }

  // Disable biometric authentication
  Future<void> disableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, false);
  }

  // Reset password (for forgot password feature)
  Future<bool> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(_userKey);
      if (userDataString == null) return false;

      final userData = jsonDecode(userDataString) as Map<String, dynamic>;

      // Check email matches
      if (userData['email'] != email) return false;

      // Update password (PBKDF2 with fresh random salt)
      userData['password'] = _hashPassword(newPassword);
      await prefs.setString(_userKey, jsonEncode(userData));
      return true;
    } catch (e) {
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    // Note: We don't delete user data, just logout
    // In a real app, you might want to clear session tokens
  }

  // Delete account (optional - for testing)
  Future<void> deleteAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_biometricKey);
  }
}