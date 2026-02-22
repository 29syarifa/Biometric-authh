import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  
  // Get available cameras
  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      
      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('No cameras found');
      }
      
      // Use front camera for face detection (index 1 usually)
      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );
      
      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      await _controller!.initialize();
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      rethrow;
    }
  }
  
  // Get the camera controller for preview
  CameraController? get controller => _controller;
  
  // Check if camera is ready
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  
  // Capture image
  Future<XFile> captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }
    
    try {
      final XFile image = await _controller!.takePicture();
      return image;
    } catch (e) {
      debugPrint('Image capture error: $e');
      rethrow;
    }
  }
  
  // Validate image quality
  Future<ImageQuality> validateImageQuality(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        return ImageQuality(
          isValid: false,
          reason: 'Unable to decode image',
        );
      }
      
      // Check brightness (average pixel luminance)
      final brightness = _calculateBrightness(image);
      if (brightness < 50) {
        return ImageQuality(
          isValid: false,
          reason: 'Image too dark. Please improve lighting.',
        );
      }
      if (brightness > 230) {
        return ImageQuality(
          isValid: false,
          reason: 'Image too bright. Reduce lighting.',
        );
      }
      
      // Check blur using Laplacian variance
      final blurScore = _calculateBlur(image);
      if (blurScore < 100) {
        return ImageQuality(
          isValid: false,
          reason: 'Image is blurry. Hold phone steady.',
        );
      }
      
      return ImageQuality(
        isValid: true,
        brightness: brightness,
        blurScore: blurScore,
      );
      
    } catch (e) {
      debugPrint('Quality validation error: $e');
      return ImageQuality(
        isValid: false,
        reason: 'Error analyzing image quality',
      );
    }
  }
  
  // Calculate average brightness (0-255)
  double _calculateBrightness(img.Image image) {
    int totalBrightness = 0;
    int pixelCount = image.width * image.height;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        // Calculate luminance
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        final brightness = (0.299 * r + 0.587 * g + 0.114 * b).round();
        totalBrightness += brightness;
      }
    }
    
    return totalBrightness / pixelCount;
  }
  
  // Calculate blur using Laplacian variance
  double _calculateBlur(img.Image image) {
    // Convert to grayscale first
    final gray = img.grayscale(image);
    
    // Apply Laplacian kernel (edge detection)
    // Higher variance = sharper image
    List<double> values = [];
    
    for (int y = 1; y < gray.height - 1; y++) {
      for (int x = 1; x < gray.width - 1; x++) {
        final center = gray.getPixel(x, y).r;
        final top = gray.getPixel(x, y - 1).r;
        final bottom = gray.getPixel(x, y + 1).r;
        final left = gray.getPixel(x - 1, y).r;
        final right = gray.getPixel(x + 1, y).r;
        
        final laplacian = (4 * center - top - bottom - left - right).abs();
        values.add(laplacian.toDouble());
      }
    }
    
    // Calculate variance
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
    
    return variance;
  }
  
  // Dispose camera resources
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}

// Model for image quality results
class ImageQuality {
  final bool isValid;
  final String? reason;
  final double? brightness;
  final double? blurScore;
  
  ImageQuality({
    required this.isValid,
    this.reason,
    this.brightness,
    this.blurScore,
  });
}