import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/biometric_template.dart';
import 'security_service.dart';

/// BiometricDataManager handles encrypted storage of face embeddings.
///
/// Storage layout (SharedPreferences):
///   biometric_enrolled_{userId}  → bool (is user enrolled)
///   biometric_template_{userId}  → JSON of BiometricTemplate
///
/// The template's encryptedTemplate field contains:
///   AES-256-CBC( JSON array of 128-dim embedding vectors )
class BiometricDataManager {
  final SecurityService _securityService = SecurityService();

  // ─── Save Embeddings ──────────────────────────────────────────
  /// Encrypt and persist a list of face embeddings for [userId].
  Future<void> saveEmbeddings(
    String userId,
    List<List<double>> embeddings,
  ) async {
    // Serialize embeddings → JSON text
    final embeddingsJson = jsonEncode(
      embeddings.map((e) => e.toList()).toList(),
    );

    // Encrypt with AES-256-CBC keyed by userId
    final encrypted = _securityService.encryptData(embeddingsJson, userId);

    // Wrap in BiometricTemplate
    final template = BiometricTemplate(
      userId: userId,
      encryptedTemplate: encrypted,
      createdAt: DateTime.now(),
      embeddingCount: embeddings.length,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'biometric_template_$userId',
      jsonEncode(template.toJson()),
    );
    await prefs.setBool('biometric_enrolled_$userId', true);
  }

  // ─── Load Embeddings ──────────────────────────────────────────
  /// Retrieve and decrypt face embeddings for [userId].
  /// Returns null if not enrolled.
  Future<List<List<double>>?> getEmbeddings(String userId) async {
    final template = await getTemplate(userId);
    if (template == null) return null;

    try {
      final decrypted = _securityService.decryptData(
        template.encryptedTemplate,
        userId,
      );
      final List<dynamic> decoded = jsonDecode(decrypted);
      return decoded
          .map((e) => (e as List<dynamic>).map((v) => (v as num).toDouble()).toList())
          .toList();
    } catch (e) {
      return null;
    }
  }

  // ─── Template (raw) ──────────────────────────────────────────
  Future<BiometricTemplate?> getTemplate(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('biometric_template_$userId');
    if (data == null) return null;
    return BiometricTemplate.fromJson(jsonDecode(data));
  }

  // ─── Enrollment Status ────────────────────────────────────────
  Future<bool> isEnrolled(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enrolled_$userId') ?? false;
  }

  // ─── Delete Enrollment ────────────────────────────────────────
  Future<void> deleteEnrollment(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('biometric_template_$userId');
    await prefs.remove('biometric_enrolled_$userId');
  }

  // ─── Legacy: save raw template string ────────────────────────
  Future<void> saveTemplate(String userId, String rawTemplate) async {
    final encrypted = _securityService.encryptData(rawTemplate, userId);
    final template = BiometricTemplate(
      userId: userId,
      encryptedTemplate: encrypted,
      createdAt: DateTime.now(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'biometric_$userId',
      jsonEncode(template.toJson()),
    );
  }
}