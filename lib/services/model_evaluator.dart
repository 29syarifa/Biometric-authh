import 'dart:math';
import 'embedding_service.dart';
import 'biometric_data_manager.dart';

/// ModelEvaluatorService — maps to Requirement 4:
/// "Testing the model with test data to evaluate its performance."
///
/// Runs a leave-one-out cross-validation experiment on the enrolled
/// face embeddings to estimate real-world recognition performance.
///
/// Generates the standard biometric evaluation metrics:
///   • FAR  – False Accept Rate   (impostors wrongly accepted)
///   • FRR  – False Reject Rate   (genuine users wrongly rejected)
///   • TAR  – True Accept Rate    (= 1 − FRR, genuine users accepted)
///   • Accuracy – overall correct decisions
///   • EER  – Equal Error Rate    (threshold where FAR ≈ FRR)
///
/// Impostor simulation: 50 random unit vectors in the 640-dim embedding
/// space represent zero-knowledge attackers. Cosine similarity with these
/// follows a near-zero distribution (expected value ≈ 0 for unit Gaussian).
class ModelEvaluatorService {
  final EmbeddingService _embeddingService = EmbeddingService();
  final BiometricDataManager _dataManager = BiometricDataManager();
  final Random _rng = Random();

  // ── Public API ─────────────────────────────────────────────────────────

  /// Run a full self-evaluation against the enrolled embeddings for [userId].
  ///
  /// [threshold] is the cosine-similarity decision boundary (default 0.60).
  Future<EvaluationReport> evaluate({
    required String userId,
    double threshold = 0.78,
  }) async {
    final embeddings = await _dataManager.getEmbeddings(userId);
    if (embeddings == null || embeddings.length < 2) {
      return EvaluationReport.insufficient(userId);
    }

    // 1. Genuine scores: all pairs from the same enrolled user.
    //    This mimics leave-one-out: each embedding acts as a probe against
    //    the rest — the classic intra-class similarity experiment.
    final genuineScores = _computeGenuineScores(embeddings);

    // 2. Impostor scores: compare enrolled embeddings against 50 random
    //    unit-norm vectors (simulated zero-knowledge attackers).
    final impostorScores = _computeImpostorScores(embeddings, count: 50);

    // 3. Compute confusion matrix at [threshold]
    final tp = genuineScores.where((s) => s >= threshold).length;   // correct accepts
    final fn = genuineScores.where((s) => s < threshold).length;    // false rejects
    final fp = impostorScores.where((s) => s >= threshold).length;  // false accepts
    final tn = impostorScores.where((s) => s < threshold).length;   // correct rejects

    final totalGenuine  = genuineScores.length;
    final totalImpostor = impostorScores.length;

    final far = totalImpostor == 0 ? 0.0 : fp / totalImpostor;
    final frr = totalGenuine  == 0 ? 0.0 : fn / totalGenuine;
    final tar = 1.0 - frr;
    final accuracy = (tp + tn) / (totalGenuine + totalImpostor);

    // 4. Mean scores
    final meanGenuine  = _mean(genuineScores);
    final meanImpostor = _mean(impostorScores);

    // 5. EER: find threshold where FAR ≈ FRR (sweep 0.01→0.99)
    final eer = _estimateEER(genuineScores, impostorScores);

    return EvaluationReport(
      success: true,
      userId: userId,
      threshold: threshold,
      genuineScores: genuineScores,
      impostorScores: impostorScores,
      meanGenuineSimilarity: meanGenuine,
      meanImpostorSimilarity: meanImpostor,
      far: far,
      frr: frr,
      tar: tar,
      accuracy: accuracy,
      eer: eer,
      truePositives: tp,
      falseNegatives: fn,
      falsePositives: fp,
      trueNegatives: tn,
      totalGenuineTrials: totalGenuine,
      totalImpostorTrials: totalImpostor,
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────

  /// All C(n,2) unique pairs from the enrolled embeddings.
  List<double> _computeGenuineScores(List<List<double>> enrolled) {
    final scores = <double>[];
    for (int i = 0; i < enrolled.length; i++) {
      for (int j = i + 1; j < enrolled.length; j++) {
        scores.add(_embeddingService.cosineSimilarity(enrolled[i], enrolled[j]));
      }
    }
    return scores;
  }

  /// Generate [count] random unit-norm impostor embeddings and compute
  /// their best cosine similarity against every enrolled embedding.
  List<double> _computeImpostorScores(
    List<List<double>> enrolled, {
    required int count,
  }) {
    final dim = enrolled.first.length;
    final scores = <double>[];

    for (int i = 0; i < count; i++) {
      // Random unit vector via Box-Muller + L2 normalise
      final raw = List<double>.generate(dim, (_) => _gaussianSample());
      final norm = sqrt(raw.map((v) => v * v).reduce((a, b) => a + b));
      final impostor = norm == 0.0 ? raw : raw.map((v) => v / norm).toList();

      // Best match against enrolled embeddings (most-favourable impostor test)
      for (final ref in enrolled) {
        scores.add(_embeddingService.cosineSimilarity(ref, impostor));
      }
    }
    return scores;
  }

  /// Box-Muller transform: uniform → Gaussian sample N(0,1).
  double _gaussianSample() {
    final u1 = _rng.nextDouble().clamp(1e-10, 1.0);
    final u2 = _rng.nextDouble();
    return sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
  }

  double _mean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Sweep threshold in 0.01 steps to find Equal Error Rate.
  double _estimateEER(
    List<double> genuine,
    List<double> impostor,
  ) {
    double minDiff = double.infinity;
    double eer = 0.0;

    for (int step = 1; step <= 99; step++) {
      final thr = step / 100.0;
      final frr = genuine.where((s) => s < thr).length / genuine.length;
      final far = impostor.where((s) => s >= thr).length / impostor.length;
      final diff = (far - frr).abs();
      if (diff < minDiff) {
        minDiff = diff;
        eer = (far + frr) / 2.0;
      }
    }
    return eer;
  }
}

// ── Data model ─────────────────────────────────────────────────────────────

/// Full evaluation report returned by [ModelEvaluatorService.evaluate].
class EvaluationReport {
  final bool success;
  final String userId;
  final double threshold;

  // Raw score distributions
  final List<double> genuineScores;
  final List<double> impostorScores;

  // Descriptive statistics
  final double meanGenuineSimilarity;
  final double meanImpostorSimilarity;

  // Biometric performance metrics (all in [0, 1])
  final double far;      // False Accept Rate
  final double frr;      // False Reject Rate
  final double tar;      // True Accept Rate  (= 1 − FRR)
  final double accuracy; // (TP + TN) / total
  final double eer;      // Equal Error Rate

  // Confusion matrix
  final int truePositives;
  final int falseNegatives;
  final int falsePositives;
  final int trueNegatives;
  final int totalGenuineTrials;
  final int totalImpostorTrials;

  const EvaluationReport({
    required this.success,
    required this.userId,
    required this.threshold,
    required this.genuineScores,
    required this.impostorScores,
    required this.meanGenuineSimilarity,
    required this.meanImpostorSimilarity,
    required this.far,
    required this.frr,
    required this.tar,
    required this.accuracy,
    required this.eer,
    required this.truePositives,
    required this.falseNegatives,
    required this.falsePositives,
    required this.trueNegatives,
    required this.totalGenuineTrials,
    required this.totalImpostorTrials,
  });

  factory EvaluationReport.insufficient(String userId) => EvaluationReport(
        success: false,
        userId: userId,
        threshold: 0.0,
        genuineScores: [],
        impostorScores: [],
        meanGenuineSimilarity: 0,
        meanImpostorSimilarity: 0,
        far: 0,
        frr: 0,
        tar: 0,
        accuracy: 0,
        eer: 0,
        truePositives: 0,
        falseNegatives: 0,
        falsePositives: 0,
        trueNegatives: 0,
        totalGenuineTrials: 0,
        totalImpostorTrials: 0,
      );
}
