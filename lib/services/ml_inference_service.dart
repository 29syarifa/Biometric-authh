import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'embedding_service.dart';

/// MLInferenceService orchestrates the full ML pipeline:
/// Image → Preprocess → [Sobel Conv] → Extract 256-dim Embedding → Match
///
/// Requirement mapping:
///   Req 1 – Camera data retrieved by CameraService (caller)
///   Req 2 – Preprocessing (Gaussian blur, contrast stretch) in PreprocessingService
///   Req 3 – CNN-inspired Sobel convolution + spatial pooling in EmbeddingService
///   Req 5 – Integration: this service bridges all stages to the auth system
class MLInferenceService {
  /// Threshold raised to 0.78 after adding LBP channel.
  /// Old 0.60 was too low: different faces with similar lighting scored > 0.60.
  /// With 640-dim LBP+Sobel embeddings, genuine users consistently score > 0.80,
  /// while impostors typically score < 0.65.
  static const double verificationThreshold = 0.78;

  final EmbeddingService _embeddingService = EmbeddingService();

  /// Extract a face embedding from a captured XFile image.
  /// Returns null if processing fails.
  Future<List<double>?> extractEmbeddingFromFile(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final embedding = await _embeddingService.extractEmbedding(bytes);
      return embedding;
    } catch (e) {
      return null;
    }
  }

  /// Extract a face embedding from raw bytes.
  Future<List<double>?> extractEmbeddingFromBytes(Uint8List bytes) async {
    try {
      return await _embeddingService.extractEmbedding(bytes);
    } catch (e) {
      return null;
    }
  }

  /// Enroll a user: extract embeddings from multiple face images.
  /// Returns list of embeddings (one per captured image).
  Future<List<List<double>>> enrollFaces(List<String> imagePaths) async {
    final embeddings = <List<double>>[];

    for (final path in imagePaths) {
      try {
        final file = XFile(path);
        final embedding = await extractEmbeddingFromFile(file);
        if (embedding != null) {
          embeddings.add(embedding);
        }
      } catch (_) {
        // Skip failed images
      }
    }

    return embeddings;
  }

  /// Verify a face against stored enrollments.
  /// Returns a [VerificationResult] with score and decision.
  Future<VerificationResult> verifyFace({
    required XFile probeImage,
    required List<List<double>> storedEmbeddings,
  }) async {
    if (storedEmbeddings.isEmpty) {
      return VerificationResult(
        verified: false,
        similarity: 0.0,
        message: 'No enrolled face data found.',
      );
    }

    final probe = await extractEmbeddingFromFile(probeImage);
    if (probe == null) {
      return VerificationResult(
        verified: false,
        similarity: 0.0,
        message: 'Could not extract features from image.',
      );
    }

    final similarity = _embeddingService.matchAgainstEnrollments(
      probe,
      storedEmbeddings,
    );

    final verified = similarity >= verificationThreshold;

    return VerificationResult(
      verified: verified,
      similarity: similarity,
      message: verified
          ? 'Face verified! (${(similarity * 100).toStringAsFixed(1)}% match)'
          : 'Face not recognized. (${(similarity * 100).toStringAsFixed(1)}% match)',
    );
  }
}

class VerificationResult {
  final bool verified;
  final double similarity;
  final String message;

  VerificationResult({
    required this.verified,
    required this.similarity,
    required this.message,
  });
}
