import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import '../services/camera_services.dart';

class CameraPreviewWidget extends StatefulWidget {
  final CameraService cameraService;
  final VoidCallback? onCapturePressed;
  final String? message;

  const CameraPreviewWidget({
    super.key,
    required this.cameraService,
    this.onCapturePressed,
    this.message,
  });

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  @override
  Widget build(BuildContext context) {
    if (!widget.cameraService.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final controller = widget.cameraService.controller!;
    final previewSize = controller.value.previewSize;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Camera Preview ──────────────────────────────────────
        // On mobile: sensor reports landscape dims → swap to portrait.
        // On web: webcam already reports correct dims → no swap needed.
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.center,
            child: SizedBox(
              width: kIsWeb
                  ? (previewSize?.width ?? 640)
                  : (previewSize?.height ?? 1280),
              height: kIsWeb
                  ? (previewSize?.height ?? 480)
                  : (previewSize?.width ?? 720),
              child: CameraPreview(controller),
            ),
          ),
        ),

        // ── Face Oval Overlay ───────────────────────────────────
        Center(
          child: Container(
            width: 240,
            height: 310,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 3,
              ),
              borderRadius: BorderRadius.circular(150),
            ),
          ),
        ),

        // ── Instruction Message ─────────────────────────────────
        if (widget.message != null)
          Positioned(
            top: 24,
            left: 20,
            right: 20,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.message!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

        // ── Capture Button ──────────────────────────────────────
        if (widget.onCapturePressed != null)
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: widget.onCapturePressed,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.blue, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 34,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
          ),

        // ── Disabled overlay when processing ───────────────────
        if (widget.onCapturePressed == null)
          Container(
            color: Colors.black.withValues(alpha: 0.35),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }
}