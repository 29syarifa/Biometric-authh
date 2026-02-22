import 'package:flutter/material.dart';
import '../services/camera_services.dart';
import '../services/face_detection_service.dart';
import '../services/ml_inference_service.dart';
import '../services/biometric_data_manager.dart';
import '../widgets/camera_preview_widget.dart';

class EnrollmentScreen extends StatefulWidget {
  final String userId;
  const EnrollmentScreen({super.key, required this.userId});

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  final CameraService _cameraService = CameraService();
  final FaceDetectionService _faceDetectionService = FaceDetectionService();
  final MLInferenceService _mlService = MLInferenceService();
  final BiometricDataManager _dataManager = BiometricDataManager();

  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isSaving = false;
  String _message = 'Look straight at the camera';

  final List<String> _capturedImages = [];
  final int _requiredImages = 5;
  final Set<FaceAngle> _capturedAngles = {};

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initialize();
      setState(() => _isInitialized = true);
    } catch (e) {
      _showError('Failed to initialize camera: $e');
    }
  }

  Future<void> _captureImage() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _message = 'Processing...';
    });

    try {
      // 1. Capture
      final imageFile = await _cameraService.captureImage();

      // 2. Image quality check
      final quality = await _cameraService.validateImageQuality(imageFile);
      if (!quality.isValid) {
        setState(() {
          _message = quality.reason!;
          _isProcessing = false;
        });
        return;
      }

      // 3. Face detection
      final detection = await _faceDetectionService.detectFaces(imageFile);
      if (!detection.success) {
        setState(() {
          _message = detection.message;
          _isProcessing = false;
        });
        return;
      }

      // 4. Track angle variety
      final angle = _faceDetectionService.getFaceAngle(detection.face!);
      _capturedImages.add(imageFile.path);
      _capturedAngles.add(angle);

      setState(() {
        _isProcessing = false;
        if (_capturedImages.length >= _requiredImages) {
          _message = 'All images captured! Saving...';
          _completeEnrollment();
        } else {
          _message = _getNextInstruction();
        }
      });
    } catch (e) {
      _showError('Capture error: $e');
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _completeEnrollment() async {
    setState(() => _isSaving = true);

    try {
      // Extract 128-dim embeddings from all captured images via ML pipeline
      final embeddings = await _mlService.enrollFaces(_capturedImages);

      if (embeddings.isEmpty) {
        _showError('Could not extract face features. Please try again.');
        setState(() {
          _isSaving = false;
          _capturedImages.clear();
          _capturedAngles.clear();
          _message = 'Look straight at the camera';
        });
        return;
      }

      // Encrypt embeddings with AES-256 and store on device
      await _dataManager.saveEmbeddings(widget.userId, embeddings);

      if (!mounted) return;
      setState(() => _isSaving = false);

      // Show success dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Enrolled!'),
            ],
          ),
          content: Text(
            'Face enrollment complete.\n'
            '${embeddings.length} face templates encrypted & stored.\n'
            'You can now use Face ID to log in.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true); // return success
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showError('Enrollment failed: $e');
      setState(() => _isSaving = false);
    }
  }

  String _getNextInstruction() {
    final remaining = _requiredImages - _capturedImages.length;
    if (!_capturedAngles.contains(FaceAngle.center)) {
      return 'Look straight at camera ($remaining left)';
    } else if (!_capturedAngles.contains(FaceAngle.left)) {
      return 'Turn head slightly left ($remaining left)';
    } else if (!_capturedAngles.contains(FaceAngle.right)) {
      return 'Turn head slightly right ($remaining left)';
    } else {
      return 'Capture $remaining more image${remaining > 1 ? 's' : ''}';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _cameraService.dispose();
    _faceDetectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Face Enrollment'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: !_isInitialized
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Starting camera...',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Progress header
                Container(
                  color: Colors.grey[900],
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Images: ${_capturedImages.length} / $_requiredImages',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${(_capturedImages.length / _requiredImages * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _capturedImages.length / _requiredImages,
                          minHeight: 6,
                          backgroundColor: Colors.grey[700],
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),

                // Camera preview
                Expanded(
                  child: _isSaving
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              CircularProgressIndicator(color: Colors.blue),
                              SizedBox(height: 20),
                              Text(
                                'Extracting features & encrypting...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'AES-256-CBC encryption in progress',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : CameraPreviewWidget(
                          cameraService: _cameraService,
                          message: _message,
                          onCapturePressed:
                              (_isProcessing || _isSaving) ? null : _captureImage,
                        ),
                ),

                // Captured thumbnails row
                if (_capturedImages.isNotEmpty)
                  Container(
                    height: 80,
                    color: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _capturedImages.length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 60,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade800,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

