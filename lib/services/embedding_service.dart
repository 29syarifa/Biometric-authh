import 'package:image/image.dart' as img;
import 'dart:math';
import 'dart:typed_data';
import 'preprocessing_service.dart';

/// EmbeddingService -- 640-dimensional face feature extractor.
///
/// Two-channel architecture:
///   Channel 1 - LBP texture (512 dims)
///     Local Binary Pattern: per-pixel compare 8 neighbors -> 8-bit code
///     Per-cell histogram -> 4x4 grid x 32 bins = 512 dims
///     LBP is face-recognition specific (Ahonen et al. 2006)
///   Channel 2 - Sobel gradient (128 dims)
///     Sobel-X + Sobel-Y magnitude, 8x8 spatial pooling mean+stdev
///
///   Final: L2-normalised 640-dim unit vector for cosine similarity.
///
/// Why old 256-dim failed: mean/stdev of brightness is NOT face-specific.
/// Different faces with similar lighting easily exceed cos-sim 0.60.
/// LBP texture codes are orders-of-magnitude more person-specific.
class EmbeddingService {
  static const int _sobelGrid = 8;
  static const int _sobelCell = 8;
  static const int _lbpGrid   = 4;
  static const int _lbpCell   = 16;
  static const int _lbpBins   = 32;

  static const List<List<double>> _sobelX = [
    [-1.0, 0.0, 1.0],
    [-2.0, 0.0, 2.0],
    [-1.0, 0.0, 1.0],
  ];
  static const List<List<double>> _sobelY = [
    [-1.0, -2.0, -1.0],
    [ 0.0,  0.0,  0.0],
    [ 1.0,  2.0,  1.0],
  ];

  // 8 circular neighbors (clockwise from top-left)
  static const List<List<int>> _lbpNeighbors = [
    [-1, -1], [0, -1], [1, -1],
    [ 1,  0],
    [ 1,  1], [0,  1], [-1,  1],
    [-1,  0],
  ];

  final PreprocessingService _preprocessor = PreprocessingService();

  /// Raw image bytes -> 640-dim L2-normalised embedding.
  Future<List<double>> extractEmbedding(Uint8List imageBytes) async {
    final gray = _preprocessor.preprocessBytes(imageBytes);

    // Channel 1: LBP texture histogram -- 4x4 grid x 32 bins = 512 dims
    final lbpMap  = _computeLBPMap(gray);
    final lbpFeats = _lbpHistogram(lbpMap);

    // Channel 2: Sobel gradient -- 8x8 grid x 2 stats = 128 dims
    final gradMap    = _computeGradientMagnitude(gray);
    final sobelFeats = _spatialPooling(gradMap, _sobelGrid, _sobelCell);

    return _l2Normalize([...lbpFeats, ...sobelFeats]); // 640 dims
  }

  // LBP helpers

  List<List<int>> _computeLBPMap(img.Image src) {
    final h = src.height;
    final w = src.width;
    final out = List.generate(h, (_) => List.filled(w, 0));

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final center = src.getPixel(x, y).r;
        int code = 0;
        for (int k = 0; k < _lbpNeighbors.length; k++) {
          final nx = x + _lbpNeighbors[k][0];
          final ny = y + _lbpNeighbors[k][1];
          if (src.getPixel(nx, ny).r >= center) {
            code |= (1 << k);
          }
        }
        out[y][x] = code;
      }
    }
    return out;
  }

  List<double> _lbpHistogram(List<List<int>> lbpMap) {
    final result = <double>[];

    for (int gy = 0; gy < _lbpGrid; gy++) {
      for (int gx = 0; gx < _lbpGrid; gx++) {
        final hist = List<double>.filled(_lbpBins, 0.0);
        final startX = gx * _lbpCell;
        final startY = gy * _lbpCell;
        int count = 0;

        for (int py = startY; py < startY + _lbpCell; py++) {
          for (int px = startX; px < startX + _lbpCell; px++) {
            if (py < lbpMap.length && px < lbpMap[0].length) {
              final bin = (lbpMap[py][px] * _lbpBins) >> 8;
              hist[bin.clamp(0, _lbpBins - 1)] += 1.0;
              count++;
            }
          }
        }
        if (count > 0) {
          for (int b = 0; b < _lbpBins; b++) {
            hist[b] /= count;
          }
        }
        result.addAll(hist);
      }
    }
    return result; // 512 dims
  }

  // Sobel helpers

  List<List<double>> _computeGradientMagnitude(img.Image src) {
    final h = src.height;
    final w = src.width;
    final mag = List.generate(h, (_) => List.filled(w, 0.0));
    double maxMag = 0.0;

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        double gx = 0.0, gy = 0.0;
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pv = src.getPixel(x + kx, y + ky).r / 255.0;
            gx += pv * _sobelX[ky + 1][kx + 1];
            gy += pv * _sobelY[ky + 1][kx + 1];
          }
        }
        final m = sqrt(gx * gx + gy * gy);
        mag[y][x] = m;
        if (m > maxMag) maxMag = m;
      }
    }
    if (maxMag > 0.0) {
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          mag[y][x] /= maxMag;
        }
      }
    }
    return mag;
  }

  List<double> _spatialPooling(
    List<List<double>> map,
    int gridN,
    int cellSize,
  ) {
    final means  = <double>[];
    final stdevs = <double>[];

    for (int gy = 0; gy < gridN; gy++) {
      for (int gx = 0; gx < gridN; gx++) {
        final values = <double>[];
        for (int py = gy * cellSize; py < (gy + 1) * cellSize; py++) {
          for (int px = gx * cellSize; px < (gx + 1) * cellSize; px++) {
            if (py < map.length && px < map[0].length) {
              values.add(map[py][px]);
            }
          }
        }
        final n = values.length.toDouble();
        final mean = values.isEmpty
            ? 0.0
            : values.reduce((a, b) => a + b) / n;
        means.add(mean);
        final variance = values.isEmpty
            ? 0.0
            : values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / n;
        stdevs.add(sqrt(variance));
      }
    }
    return [...means, ...stdevs];
  }

  List<double> _l2Normalize(List<double> v) {
    final norm = sqrt(v.map((x) => x * x).reduce((a, b) => a + b));
    if (norm == 0.0) return v;
    return v.map((x) => x / norm).toList();
  }

  // Public matching API

  /// Cosine similarity between two unit vectors, range [-1, 1].
  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dot = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot.clamp(-1.0, 1.0);
  }

  /// AVERAGE cosine similarity across all enrolled embeddings.
  /// Average (not max) prevents a single lucky match accepting an impostor.
  double matchAgainstEnrollments(
    List<double> probe,
    List<List<double>> gallery,
  ) {
    if (gallery.isEmpty) return 0.0;
    final scores = gallery.map((e) => cosineSimilarity(probe, e));
    return scores.reduce((a, b) => a + b) / gallery.length;
  }
}