import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_services.dart';

class CameraPreviewWidget extends StatefulWidget {
  final CameraService cameraService;
  final VoidCallback? onCapturePressed;
  final String? message;
  
  const CameraPreviewWidget({
    Key? key,
    required this.cameraService,
    this.onCapturePressed,
    this.message,
  }) : super(key: key);
  
  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  @override
  Widget build(BuildContext context) {
    if (!widget.cameraService.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    final controller = widget.cameraService.controller!;
    final size = MediaQuery.of(context).size;
    
    // Calculate preview size maintaining aspect ratio
    final scale = size.aspectRatio * controller.value.aspectRatio;
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        Transform.scale(
          scale: scale < 1 ? 1 / scale : scale,
          child: Center(
            child: CameraPreview(controller),
          ),
        ),
        
        // Face outline overlay
        Center(
          child: Container(
            width: 250,
            height: 320,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 3,
              ),
              borderRadius: BorderRadius.circular(150),
            ),
          ),
        ),
        
        // Instruction message
        if (widget.message != null)
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.message!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        
        // Capture button
        if (widget.onCapturePressed != null)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: widget.onCapturePressed,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.blue,
                      width: 4,
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 35,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}