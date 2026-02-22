import 'package:flutter/material.dart';
import '../services/camera_services.dart';
import '../services/face_detection_service.dart';
import '../widgets/camera_preview_widget.dart';

class EnrollmentScreen extends StatefulWidget {
  const EnrollmentScreen({Key? key}) : super(key: key);
  
  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  final CameraService _cameraService = CameraService();
  final FaceDetectionService _faceDetectionService = FaceDetectionService();
  
  bool _isInitialized = false;
  bool _isProcessing = false;
  String _message = 'Position your face in the oval';
  
  List<String> _capturedImages = [];
  final int _requiredImages = 5;
  
  // Track captured angles to ensure variety
  Set<FaceAngle> _capturedAngles = {};
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }
  
  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initialize();
      setState(() {
        _isInitialized = true;
      });
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
      // 1. Capture image
      final imageFile = await _cameraService.captureImage();
      
      // 2. Validate image quality
      final quality = await _cameraService.validateImageQuality(imageFile);
      if (!quality.isValid) {
        setState(() {
          _message = quality.reason!;
          _isProcessing = false;
        });
        return;
      }
      
      // 3. Detect face
      final detection = await _faceDetectionService.detectFaces(imageFile);
      if (!detection.success) {
        setState(() {
          _message = detection.message;
          _isProcessing = false;
        });
        return;
      }
      
      // 4. Check face angle for variety
      final angle = _faceDetectionService.getFaceAngle(detection.face!);
      
      // 5. Save image
      _capturedImages.add(imageFile.path);
      _capturedAngles.add(angle);
      
      setState(() {
        _isProcessing = false;
        
        if (_capturedImages.length >= _requiredImages) {
          _message = 'Enrollment complete!';
          _completeEnrollment();
        } else {
          _message = _getNextInstruction();
        }
      });
      
    } catch (e) {
      _showError('Error capturing image: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  String _getNextInstruction() {
    final remaining = _requiredImages - _capturedImages.length;
    
    if (!_capturedAngles.contains(FaceAngle.center)) {
      return 'Look straight at the camera ($remaining remaining)';
    } else if (!_capturedAngles.contains(FaceAngle.left)) {
      return 'Turn your head slightly left ($remaining remaining)';
    } else if (!_capturedAngles.contains(FaceAngle.right)) {
      return 'Turn your head slightly right ($remaining remaining)';
    } else {
      return 'Capture $remaining more image${remaining > 1 ? 's' : ''}';
    }
  }
  
  void _completeEnrollment() {
    // TODO: Pass captured images to Developer B's ML service
    // For now, just navigate back
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context, _capturedImages);
    });
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
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
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Progress indicator
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Images: ${_capturedImages.length}/$_requiredImages',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _capturedImages.length / _requiredImages,
                        backgroundColor: Colors.grey[800],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ],
                  ),
                ),
                
                // Camera preview
                Expanded(
                  child: CameraPreviewWidget(
                    cameraService: _cameraService,
                    message: _message,
                    onCapturePressed: _isProcessing ? null : _captureImage,
                  ),
                ),
                
                // Thumbnail gallery
                if (_capturedImages.isNotEmpty)
                  Container(
                    height: 100,
                    color: Colors.black,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _capturedImages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            width: 80,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.blue,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 40,
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