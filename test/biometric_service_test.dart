import 'package:flutter_test/flutter_test.dart';
import 'package:biometric_auth/services/biometric_service.dart';
import 'package:local_auth/local_auth.dart';

void main() {
  group('BiometricService Tests', () {
    late BiometricService biometricService;

    setUp(() {
      biometricService = BiometricService();
    });

    test('BiometricService should be instantiated', () {
      expect(biometricService, isNotNull);
    });

    test('isBiometricAvailable should return a boolean', () async {
      // This test will check if the method runs without errors
      // Actual result depends on device capabilities
      final result = await biometricService.isBiometricAvailable();
      expect(result, isA<bool>());
    });

    test('getAvailableBiometrics should return a list', () async {
      final result = await biometricService.getAvailableBiometrics();
      expect(result, isA<List>());
    });

    test('getBiometricTypeName should return correct names', () {
      expect(
        biometricService.getBiometricTypeName(BiometricType.fingerprint),
        equals('Fingerprint'),
      );
      expect(
        biometricService.getBiometricTypeName(BiometricType.face),
        equals('Face ID'),
      );
    });
  });
}
