import 'package:flutter/material.dart';
import '../services/biometric_service.dart';

class BiometricLoginScreen extends StatefulWidget {
  const BiometricLoginScreen({super.key});

  @override
  State<BiometricLoginScreen> createState() =>
      _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends State<BiometricLoginScreen> {
  final BiometricService _biometricService = BiometricService();
  String message = "Authenticate using biometrics";

  void _authenticate() async {
    bool canUse = await _biometricService.isBiometricAvailable();

    if (!canUse) {
      setState(() {
        message = "Biometric not available on this device";
      });
      return;
    }

    bool success = await _biometricService.authenticate();

    setState(() {
      message = success
          ? "Authentication Successful"
          : "Authentication Failed";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Biometric Login")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(message),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _authenticate,
              child: const Text("Scan Fingerprint"),
            ),
          ],
        ),
      ),
    );
  }
}