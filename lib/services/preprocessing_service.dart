import 'dart:typed_data';

class PreprocessingService {
  Uint8List resizeImage(Uint8List imageBytes) {
    // Simulated resize
    return imageBytes;
  }

  Uint8List normalizeImage(Uint8List imageBytes) {
    // Simulated normalization
    return imageBytes;
  }

  Uint8List alignImage(Uint8List imageBytes) {
    // Simulated alignment
    return imageBytes;
  }

  Uint8List preprocess(Uint8List imageBytes) {
    final resized = resizeImage(imageBytes);
    final normalized = normalizeImage(resized);
    return alignImage(normalized);
  }
}