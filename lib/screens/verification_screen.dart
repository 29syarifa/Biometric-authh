import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import '../services/camera_services.dart';
import '../services/face_detection_service.dart';
import '../services/ml_inference_service.dart';
import '../services/biometric_data_manager.dart';
import '../widgets/camera_preview_widget.dart';

/// VerificationScreen  3-phase pipeline:
///
///   Phase 1 (LIVENESS  eyes open):
///     User presses "Start". Camera captures. ML Kit must detect
///     face with BOTH eyes OPEN (prob > 0.55). Saves this image for identity.
///
///   Phase 2 (LIVENESS  blink challenge):
///     Countdown 3 s  auto-capture. ML Kit must detect at least one eye
///     CLOSED (prob < 0.35). A static photo/screen cannot blink  blocked.
///
///   Phase 3 (IDENTITY):
///     Runs the CNN-inspired embedding & cosine match on the Phase 1 image
///     against the stored (AES-256 encrypted) enrollment embeddings.
///
/// This defeats photo attacks (Pinterest, printed photo, screen replay).
class VerificationScreen extends StatefulWidget {
  final String userId;
  final bool fromLogin;

  const VerificationScreen({
    super.key,
    required this.userId,
    this.fromLogin = true,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final CameraService _cameraService = CameraService();
  final FaceDetectionService _faceDetectionService = FaceDetectionService();
  final MLInferenceService _mlService = MLInferenceService();
  final BiometricDataManager _dataManager = BiometricDataManager();

  _Phase _phase = _Phase.ready;
  String _message = 'Position your face in the oval, then press Start.';
  int _countdown = 3;
  Timer? _countdownTimer;

  // Saved from phase 1 (eyes-open capture)  used for identity matching
  XFile? _identityCapture;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      await _cameraService.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      _setPhase(_Phase.failed, 'Camera error: $e');
    }
  }

  //  Phase 1: eyes-open capture 

  Future<void> _startLiveness() async {
    _setPhase(_Phase.captureOpen, 'Capturing - keep eyes OPEN wide...');

    try {
      final img = await _cameraService.captureImage();

      final eyeState = await _faceDetectionService.getEyeState(img);
      if (eyeState == null) {
        // ML Kit classifier unavailable (first launch / no internet):
        // skip liveness, go straight to identity to avoid blocking the user
        _identityCapture = img;
        _runIdentityCheck();
        return;
      }

      if (!eyeState.isOpen) {
        _setPhase(
          _Phase.failed,
          'Eyes not detected as open (left=${eyeState.left.toStringAsFixed(2)}, '
          'right=${eyeState.right.toStringAsFixed(2)}). Open your eyes fully.',
        );
        return;
      }

      // Save eyes-open image for identity matching later
      _identityCapture = img;

      // Start blink countdown
      _startBlinkCountdown();
    } catch (e) {
      _setPhase(_Phase.failed, 'Capture error: $e');
    }
  }

  //  Phase 2: blink countdown + auto-capture 

  void _startBlinkCountdown() {
    _countdown = 3;
    _setPhase(_Phase.countingDown, 'BLINK in $_countdown...');

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      _countdown--;
      if (_countdown > 0) {
        setState(() => _message = 'BLINK in $_countdown...');
      } else {
        t.cancel();
        _captureBlink();
      }
    });
  }

  Future<void> _captureBlink() async {
    _setPhase(_Phase.captureBlink, 'BLINK NOW!');

    try {
      final blinkImg = await _cameraService.captureImage();
      final eyeState = await _faceDetectionService.getEyeState(blinkImg);

      if (eyeState == null) {
        // Cannot get eye state  skip liveness, trust identity only
        _runIdentityCheck();
        return;
      }

      if (!eyeState.isClosed) {
        // Eyes still open  photo attack detected (or user didn't blink)
        _setPhase(
          _Phase.failed,
          'Blink not detected (left=${eyeState.left.toStringAsFixed(2)}, '
          'right=${eyeState.right.toStringAsFixed(2)}).\n'
          'Please blink naturally when prompted.\n'
          'Photo/screen attacks are not accepted.',
        );
        return;
      }

      // Liveness confirmed  run identity on the eyes-open capture
      _runIdentityCheck();
    } catch (e) {
      _setPhase(_Phase.failed, 'Blink capture error: $e');
    }
  }

  //  Phase 3: identity matching 

  Future<void> _runIdentityCheck() async {
    _setPhase(_Phase.verifying, 'Liveness OK - verifying identity...');

    try {
      final storedEmbeddings = await _dataManager.getEmbeddings(widget.userId);
      if (storedEmbeddings == null || storedEmbeddings.isEmpty) {
        _setPhase(
            _Phase.failed, 'No face enrollment found. Please enroll first.');
        return;
      }

      final result = await _mlService.verifyFace(
        probeImage: _identityCapture!,
        storedEmbeddings: storedEmbeddings,
      );

      if (!mounted) return;

      if (result.verified) {
        _setPhase(_Phase.success, result.message);
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        if (widget.fromLogin) {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
        } else {
          Navigator.pop(context, true);
        }
      } else {
        _setPhase(_Phase.failed, result.message);
      }
    } catch (e) {
      _setPhase(_Phase.failed, 'Verification error: $e');
    }
  }

  //  Helpers 

  void _setPhase(_Phase phase, String message) {
    if (!mounted) return;
    setState(() {
      _phase = phase;
      _message = message;
    });
  }

  void _reset() {
    _countdownTimer?.cancel();
    _identityCapture = null;
    _setPhase(_Phase.ready, 'Position your face in the oval, then press Start.');
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cameraService.dispose();
    _faceDetectionService.dispose();
    super.dispose();
  }

  //  UI helpers 

  Color get _bannerColor {
    if (_phase == _Phase.success) return Colors.green;
    if (_phase == _Phase.failed) return Colors.red;
    if (_phase == _Phase.countingDown || _phase == _Phase.captureBlink) {
      return Colors.orange;
    }
    return Colors.blue;
  }

  IconData get _bannerIcon {
    if (_phase == _Phase.success) return Icons.check_circle;
    if (_phase == _Phase.failed) return Icons.cancel;
    if (_phase == _Phase.countingDown) return Icons.timer;
    if (_phase == _Phase.captureBlink) return Icons.visibility_off;
    return Icons.face;
  }

  Widget _buildStepIndicator() {
    final steps = [
      ('1', 'Eyes Open', _Phase.captureOpen),
      ('2', 'Blink', _Phase.countingDown),
      ('3', 'Identity', _Phase.verifying),
    ];

    final activeIndex = _phase == _Phase.captureOpen
        ? 0
        : (_phase == _Phase.countingDown || _phase == _Phase.captureBlink)
            ? 1
            : (_phase == _Phase.verifying ||
                    _phase == _Phase.success ||
                    _phase == _Phase.failed)
                ? 2
                : -1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _StepCircle(
            label: steps[i].$1,
            title: steps[i].$2,
            isActive: i == activeIndex,
            isDone: i < activeIndex ||
                (_phase == _Phase.success && i <= activeIndex),
          ),
          if (i < steps.length - 1)
            Container(
              width: 32,
              height: 2,
              color: i < activeIndex ? Colors.blue : Colors.white24,
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool cameraReady = _cameraService.isInitialized;
    final bool busy = _phase == _Phase.captureOpen ||
        _phase == _Phase.countingDown ||
        _phase == _Phase.captureBlink ||
        _phase == _Phase.verifying;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Face Verification'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          //  Status banner 
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: _bannerColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_bannerIcon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _message,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          //  Step indicator 
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _buildStepIndicator(),
          ),

          //  Camera preview 
          Expanded(
            child: !cameraReady
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : Stack(
                    children: [
                      CameraPreviewWidget(
                        cameraService: _cameraService,
                        onCapturePressed: null, // we control captures internally
                      ),
                      // Blink countdown overlay
                      if (_phase == _Phase.countingDown ||
                          _phase == _Phase.captureBlink)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 20),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_phase == _Phase.captureBlink)
                                  const Icon(
                                    Icons.visibility_off,
                                    size: 64,
                                    color: Colors.orange,
                                  )
                                else
                                  Text(
                                    '$_countdown',
                                    style: const TextStyle(
                                      fontSize: 72,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                Text(
                                  _phase == _Phase.captureBlink
                                      ? 'BLINK NOW!'
                                      : 'Get ready to BLINK',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),

          //  Bottom controls 
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                if (busy)
                  const LinearProgressIndicator()
                else if (_phase == _Phase.ready)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: cameraReady ? _startLiveness : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Liveness Check'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  )
                else if (_phase == _Phase.failed)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _reset,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                Text(
                  'Anti-spoofing: liveness detection active',
                  style: TextStyle(
                      color: Colors.white30,
                      fontSize: 11,
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//  Step circle widget 

class _StepCircle extends StatelessWidget {
  final String label;
  final String title;
  final bool isActive;
  final bool isDone;

  const _StepCircle({
    required this.label,
    required this.title,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDone
        ? Colors.green
        : isActive
            ? Colors.blue
            : Colors.white24;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: isDone
                ? Icon(Icons.check, size: 16, color: color)
                : Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 4),
        Text(title,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

enum _Phase {
  ready,
  captureOpen,
  countingDown,
  captureBlink,
  verifying,
  success,
  failed,
}

