import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/biometric_data_manager.dart';
import '../services/model_evaluator.dart';
import '../models/biometric_template.dart';
import 'enrollment_screen.dart';
import 'verification_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final _dataManager = BiometricDataManager();
  final _evaluator = ModelEvaluatorService();

  String? _userId;
  bool _isEnrolled = false;
  BiometricTemplate? _template;
  bool _isLoading = true;
  bool _isEvaluating = false;
  EvaluationReport? _evalReport;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = await _authService.getCurrentUser();
    _userId = user?['email'];

    if (_userId != null) {
      _isEnrolled = await _dataManager.isEnrolled(_userId!);
      _template = await _dataManager.getTemplate(_userId!);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _navigateToEnrollment() async {
    if (_userId == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnrollmentScreen(userId: _userId!),
      ),
    );
    if (result == true) {
      _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face enrollment updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteEnrollment() async {
    if (_userId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Face Data'),
        content: const Text(
          'This will permanently delete your enrolled face data. '
          'You will need to re-enroll to use Face ID.\n\nContinue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dataManager.deleteEnrollment(_userId!);
      _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face data deleted.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _testVerification() async {
    if (_userId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerificationScreen(
          userId: _userId!,
          fromLogin: false,
        ),
      ),
    );
  }

  Future<void> _runEvaluation() async {
    if (_userId == null || _isEvaluating) return;
    setState(() {
      _isEvaluating = true;
      _evalReport = null;
    });
    try {
      final report = await _evaluator.evaluate(userId: _userId!);
      if (!mounted) return;
      setState(() {
        _evalReport = report;
        _isEvaluating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isEvaluating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Evaluation error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  List<Widget> _buildMetricsWidget(EvaluationReport r) {
    if (!r.success) {
      return [
        const SizedBox(height: 12),
        const Text(
          'Need at least 2 enrolled face images to evaluate.',
          style: TextStyle(color: Colors.orange),
        ),
      ];
    }

    Widget metricRow(String label, String value, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color, fontSize: 13),
                ),
              ),
            ],
          ),
        );

    String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

    return [
      const SizedBox(height: 16),
      const Divider(),
      const SizedBox(height: 8),
      const Text(
        'Evaluation Results',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      const SizedBox(height: 8),
      metricRow('Genuine pairs tested', '${r.totalGenuineTrials}', Colors.blue),
      metricRow(
          'Impostor trials', '${r.totalImpostorTrials}', Colors.blueGrey),
      const Divider(height: 20),
      metricRow('Mean genuine similarity',
          r.meanGenuineSimilarity.toStringAsFixed(3), Colors.green),
      metricRow('Mean impostor similarity',
          r.meanImpostorSimilarity.toStringAsFixed(3), Colors.red),
      const Divider(height: 20),
      metricRow('TAR  (True Accept Rate)', pct(r.tar),
          r.tar >= 0.8 ? Colors.green : Colors.orange),
      metricRow('FAR  (False Accept Rate)', pct(r.far),
          r.far <= 0.05 ? Colors.green : Colors.red),
      metricRow('FRR  (False Reject Rate)', pct(r.frr),
          r.frr <= 0.10 ? Colors.green : Colors.orange),
      metricRow('EER  (Equal Error Rate)', pct(r.eer),
          r.eer <= 0.10 ? Colors.green : Colors.orange),
      metricRow('Accuracy', pct(r.accuracy),
          r.accuracy >= 0.90 ? Colors.green : Colors.orange),
      const SizedBox(height: 8),
      Text(
        'Threshold: ${r.threshold.toStringAsFixed(2)} | '
        'TP=${r.truePositives} FN=${r.falseNegatives} '
        'FP=${r.falsePositives} TN=${r.trueNegatives}',
        style: const TextStyle(fontSize: 11, color: Colors.black45),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Face Recognition Section ─────────────────────
                _SectionHeader(title: 'Face Recognition'),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _isEnrolled
                              ? Colors.green.shade100
                              : Colors.grey.shade200,
                          child: Icon(
                            _isEnrolled ? Icons.face : Icons.face_outlined,
                            color: _isEnrolled ? Colors.green : Colors.grey,
                          ),
                        ),
                        title: const Text('Face Enrollment'),
                        subtitle: Text(
                          _isEnrolled
                              ? 'Enrolled on ${_template?.createdAt.toLocal().toString().substring(0, 10) ?? "–"}'
                              : 'Not enrolled',
                        ),
                        trailing: Chip(
                          label: Text(
                            _isEnrolled ? 'Active' : 'None',
                            style: TextStyle(
                              color: _isEnrolled ? Colors.green : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: _isEnrolled
                              ? Colors.green.shade50
                              : Colors.grey.shade100,
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _navigateToEnrollment,
                                icon: const Icon(Icons.camera_alt),
                                label: Text(
                                  _isEnrolled ? 'Re-Enroll' : 'Enroll Face',
                                ),
                              ),
                            ),
                            if (_isEnrolled) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _testVerification,
                                  icon: const Icon(Icons.verified_user),
                                  label: const Text('Test'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_isEnrolled)
                        ListTile(
                          leading: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          title: const Text(
                            'Delete Face Data',
                            style: TextStyle(color: Colors.red),
                          ),
                          subtitle: const Text(
                            'Removes all enrolled face embeddings',
                          ),
                          onTap: _deleteEnrollment,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Model Evaluation Section ──────────────────────
                _SectionHeader(title: 'Model Evaluation'),
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Run a leave-one-out cross-validation on your enrolled face '
                          'embeddings to measure recognition performance (FAR, FRR, TAR, '
                          'Accuracy, EER).',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isEnrolled && !_isEvaluating
                                ? _runEvaluation
                                : null,
                            icon: _isEvaluating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.science),
                            label: Text(_isEvaluating
                                ? 'Running evaluation…'
                                : 'Run Self-Test'),
                          ),
                        ),
                        if (_evalReport != null) ..._buildMetricsWidget(_evalReport!),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Security Info Section ─────────────────────────
                _SectionHeader(title: 'Security Information'),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: const [
                      ListTile(
                        leading: Icon(Icons.shield, color: Colors.blue),
                        title: Text('AES-256-CBC Encryption'),
                        subtitle: Text(
                          'Face embeddings encrypted before storage',
                        ),
                      ),
                      Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.lock, color: Colors.green),
                        title: Text('On-Device Storage'),
                        subtitle: Text(
                          'Biometric data never leaves your device',
                        ),
                      ),
                      Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.key, color: Colors.orange),
                        title: Text('SHA-256 Password Hashing'),
                        subtitle: Text(
                          'Passwords stored as SHA-256 digest, never plain text',
                        ),
                      ),
                      Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.memory, color: Colors.purple),
                        title: Text('640-dim Face Embeddings'),
                        subtitle: Text(
                          'LBP 512-dim (texture) + Sobel 128-dim (edges), L2-normalized',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
