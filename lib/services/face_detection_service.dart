import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';

class FaceDetectionService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.15,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  
  // Detect faces in an image file
  Future<FaceDetectionResult> detectFaces(XFile imageFile) async {
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final faces = await _faceDetector.processImage(inputImage);
      
      if (faces.isEmpty) {
        return FaceDetectionResult(
          success: false,
          message: 'No face detected. Please center your face.',
        );
      }
      
      if (faces.length > 1) {
        return FaceDetectionResult(
          success: false,
          message: 'Multiple faces detected. Only one person allowed.',
        );
      }
      
      final face = faces.first;
      
      // Validate face quality
      final validation = _validateFace(face);
      if (!validation.isValid) {
        return FaceDetectionResult(
          success: false,
          message: validation.reason!,
        );
      }
      
      return FaceDetectionResult(
        success: true,
        face: face,
        message: 'Face detected successfully!',
      );
      
    } catch (e) {
      return FaceDetectionResult(
        success: false,
        message: 'Error detecting face: $e',
      );
    }
  }
  
  // Validate face detection quality
  FaceValidation _validateFace(Face face) {
    // Check if face is large enough (at least 30% of frame)
    final boundingBox = face.boundingBox;
    final faceArea = boundingBox.width * boundingBox.height;
    
    // This is a heuristic - adjust based on image size
    if (faceArea < 50000) {
      return FaceValidation(
        isValid: false,
        reason: 'Face too small. Move closer to camera.',
      );
    }
    
    // Check head rotation (pose)
    final headEulerAngleY = face.headEulerAngleY; // Left/right turn
    final headEulerAngleZ = face.headEulerAngleZ; // Tilt
    
    if (headEulerAngleY != null && headEulerAngleY.abs() > 15) {
      return FaceValidation(
        isValid: false,
        reason: 'Face your head straight toward camera.',
      );
    }

    if (headEulerAngleZ != null && headEulerAngleZ.abs() > 15) {
      return FaceValidation(
        isValid: false,
        reason: 'Keep your head level, don\'t tilt.',
      );
    }

    // Check if eyes are open (for liveness)
    final leftEyeOpen = face.leftEyeOpenProbability;
    final rightEyeOpen = face.rightEyeOpenProbability;

    if (leftEyeOpen != null && leftEyeOpen < 0.5) {
      return FaceValidation(
        isValid: false,
        reason: 'Please open both eyes.',
      );
    }

    if (rightEyeOpen != null && rightEyeOpen < 0.5) {
      return FaceValidation(
        isValid: false,
        reason: 'Please open both eyes.',
      );
    }
    
    return FaceValidation(isValid: true);
  }
  
  // Get specific face angles for multi-angle capture
  FaceAngle getFaceAngle(Face face) {
    final headEulerAngleY = face.headEulerAngleY ?? 0;
    
    if (headEulerAngleY > 20) {
      return FaceAngle.left;
    } else if (headEulerAngleY < -20) {
      return FaceAngle.right;
    } else {
      return FaceAngle.center;
    }
  }

  /// Returns eye open probabilities for liveness detection.
  /// Returns null if face detection fails or classifier is unavailable.
  Future<EyeState?> getEyeState(XFile imageFile) async {
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) return null;
      final face = faces.first;
      final left = face.leftEyeOpenProbability;
      final right = face.rightEyeOpenProbability;
      if (left == null || right == null) return null;
      return EyeState(left: left, right: right);
    } catch (_) {
      return null;
    }
  }
  
  // Dispose detector
  void dispose() {
    _faceDetector.close();
  }
}

// Models
class FaceDetectionResult {
  final bool success;
  final Face? face;
  final String message;
  
  FaceDetectionResult({
    required this.success,
    this.face,
    required this.message,
  });
}

class FaceValidation {
  final bool isValid;
  final String? reason;
  
  FaceValidation({
    required this.isValid,
    this.reason,
  });
}

enum FaceAngle {
  left,
  center,
  right,
}

/// Holds the eye open probabilities from ML Kit (0.0 = closed, 1.0 = open).
class EyeState {
  final double left;
  final double right;
  const EyeState({required this.left, required this.right});

  /// Average eye openness
  double get avg => (left + right) / 2.0;

  /// True if both eyes appear open
  bool get isOpen => left > 0.55 && right > 0.55;

  /// True if at least one eye appears closed (blink)
  bool get isClosed => left < 0.35 || right < 0.35;
}