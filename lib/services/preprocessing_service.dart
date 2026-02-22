import 'package:image/image.dart' as img;
import 'dart:typed_data';

/// PreprocessingService: Step 2 of the biometric pipeline.
/// "Preprocessing data to eliminate noise and irrelevant features."
///
/// Pipeline:
///   1. Resize to 64×64  (standardize spatial dimensions)
///   2. Grayscale         (remove color / irrelevant chrominance)
///   3. Gaussian blur     (LOW-PASS FILTER: eliminates sensor noise & JPEG artefacts)
///   4. Contrast stretch  (histogram normalisation: removes lighting variation)
class PreprocessingService {
  static const int targetSize = 64;

  /// Full pipeline: decode → resize → grayscale → Gaussian blur → normalize
  img.Image preprocessBytes(Uint8List rawBytes) {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) throw Exception('Cannot decode image');

    final resized = resizeImage(decoded);
    final gray = grayscaleImage(resized);
    final denoised = applyGaussianBlur(gray); // noise removal
    return normalizeContrast(denoised);
  }

  /// Resize to targetSize × targetSize (bilinear interpolation).
  img.Image resizeImage(img.Image src) {
    return img.copyResize(
      src,
      width: targetSize,
      height: targetSize,
      interpolation: img.Interpolation.linear,
    );
  }

  /// Grayscale: removes chrominance, retains luminance structure.
  img.Image grayscaleImage(img.Image src) {
    return img.grayscale(src);
  }

  /// Gaussian blur 3×3 – low-pass filter that suppresses sensor noise,
  /// JPEG artefacts, and fine-grained texture irrelevant to face identity.
  ///
  /// Kernel (normalized):
  ///   [1  2  1]
  ///   [2  4  2]  × 1/16
  ///   [1  2  1]
  img.Image applyGaussianBlur(img.Image src) {
    final w = src.width;
    final h = src.height;
    final out = img.Image(width: w, height: h);

    const kernel = [
      [1.0, 2.0, 1.0],
      [2.0, 4.0, 2.0],
      [1.0, 2.0, 1.0],
    ];
    const kernelSum = 16.0;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double sum = 0.0;
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final ny = (y + ky).clamp(0, h - 1);
            final nx = (x + kx).clamp(0, w - 1);
            sum += src.getPixel(nx, ny).r.toDouble() *
                kernel[ky + 1][kx + 1];
          }
        }
        final v = (sum / kernelSum).round().clamp(0, 255);
        out.setPixelRgba(x, y, v, v, v, 255);
      }
    }
    return out;
  }

  /// Histogram stretching: linearly scales pixel values to [0, 255].
  /// Makes embeddings invariant to overall lighting brightness.
  img.Image normalizeContrast(img.Image src) {
    int minV = 255, maxV = 0;
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final v = src.getPixel(x, y).r.toInt();
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
    }
    final range = maxV - minV;
    if (range == 0) return src;

    final out = img.Image(width: src.width, height: src.height);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final v = src.getPixel(x, y).r.toInt();
        final n = (((v - minV) / range) * 255).round().clamp(0, 255);
        out.setPixelRgba(x, y, n, n, n, 255);
      }
    }
    return out;
  }

  /// Crop face region based on bounding box (in pixel coords)
  img.Image cropFaceRegion(
    img.Image src, {
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    // Add 20% padding around face
    final padX = (width * 0.20).round();
    final padY = (height * 0.20).round();

    final x = ((left - padX).clamp(0, src.width - 1)).toInt();
    final y = ((top - padY).clamp(0, src.height - 1)).toInt();
    final w = ((width + padX * 2).clamp(1, src.width - x)).toInt();
    final h = ((height + padY * 2).clamp(1, src.height - y)).toInt();

    return img.copyCrop(src, x: x, y: y, width: w, height: h);
  }

  /// Convert preprocessed image to Float32 list (for ML input)
  /// Pixels normalized to [0.0, 1.0]
  List<double> toFloatList(img.Image processedGray) {
    final result = <double>[];
    for (int y = 0; y < processedGray.height; y++) {
      for (int x = 0; x < processedGray.width; x++) {
        final pixel = processedGray.getPixel(x, y);
        result.add(pixel.r / 255.0);
      }
    }
    return result;
  }
}