import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:convert';

class AuthService {
  static const String _userKey = 'user_data';
  static const String _biometricKey = 'biometric_enabled';

  // SHA-256 password hashing – required for cryptographic security
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
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
        'password': _hashPassword(password), // SHA-256 hashed
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
      
      // Check credentials
      if (userData['email'] == email && userData['password'] == _hashPassword(password)) {
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

      // Update password (SHA-256 hashed)
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