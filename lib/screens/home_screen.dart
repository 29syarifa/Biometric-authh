import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _biometricService = BiometricService();
  
  Map<String, String>? _userData;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final data = await _authService.getCurrentUser();
    final biometricStatus = await _authService.isBiometricEnabled();
    
    setState(() {
      _userData = data;
      _biometricEnabled = biometricStatus;
    });
  }

  Future<void> _toggleBiometric() async {
    if (_biometricEnabled) {
      // Disable biometric
      await _authService.disableBiometric();
      setState(() => _biometricEnabled = false);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric login disabled'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      // Enable biometric - verify first
      final canUse = await _biometricService.isBiometricAvailable();
      
      if (!canUse) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication not available on this device'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final authenticated = await _biometricService.authenticate();
      
      if (authenticated) {
        await _authService.enableBiometric();
        setState(() => _biometricEnabled = true);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric login enabled!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _userData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Theme.of(context).primaryColor,
                            child: Text(
                              _userData!['username']![0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _userData!['username']!,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _userData!['email']!,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Security Settings',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Biometric Login'),
                            subtitle: Text(
                              _biometricEnabled
                                  ? 'Use fingerprint to login'
                                  : 'Enable fingerprint authentication',
                            ),
                            value: _biometricEnabled,
                            onChanged: (value) => _toggleBiometric(),
                            secondary: Icon(
                              Icons.fingerprint,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'About This App',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const ListTile(
                            leading: Icon(Icons.security, color: Colors.blue),
                            title: Text('Secure Authentication'),
                            subtitle: Text('Your biometric data stays on your device'),
                          ),
                          const ListTile(
                            leading: Icon(Icons.speed, color: Colors.green),
                            title: Text('Fast Login'),
                            subtitle: Text('Login instantly with fingerprint'),
                          ),
                          const ListTile(
                            leading: Icon(Icons.privacy_tip, color: Colors.orange),
                            title: Text('Privacy First'),
                            subtitle: Text('No biometric data is sent to servers'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}