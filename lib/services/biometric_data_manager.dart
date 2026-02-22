import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/biometric_template.dart';
import 'security_service.dart';

class BiometricDataManager {
  final SecurityService _securityService = SecurityService();

  Future<void> saveTemplate(String userId, String rawTemplate) async {
    final prefs = await SharedPreferences.getInstance();

    final encrypted =
        _securityService.encryptData(rawTemplate);

    final template = BiometricTemplate(
      userId: userId,
      encryptedTemplate: encrypted,
      createdAt: DateTime.now(),
    );

    await prefs.setString(
      'biometric_$userId',
      jsonEncode(template.toJson()),
    );
  }

  Future<BiometricTemplate?> getTemplate(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('biometric_$userId');

    if (data == null) return null;

    return BiometricTemplate.fromJson(jsonDecode(data));
  }
}