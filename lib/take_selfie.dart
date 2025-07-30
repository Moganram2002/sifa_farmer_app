import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';

class TakeSelfieWebWidget extends StatefulWidget {
  final void Function(Uint8List imageBytes) onCropped;

  const TakeSelfieWebWidget({super.key, required this.onCropped});

  @override
  State<TakeSelfieWebWidget> createState() => _TakeSelfieWebWidgetState();
}

class _TakeSelfieWebWidgetState extends State<TakeSelfieWebWidget> {
  late CameraController _cameraController;
  late Future<void> _initializeControllerFuture;
  final CropController _cropController = CropController();

  Uint8List? _capturedImageBytes;
  bool _showCropper = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first, 
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _initializeControllerFuture = _cameraController.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print("Error initializing camera: $e");
    }
  }

  Future<void> _capturePhoto() async {
    try {
      await _initializeControllerFuture;
      final image = await _cameraController.takePicture();
      final bytes = await image.readAsBytes();

      setState(() {
        _capturedImageBytes = bytes;
        _showCropper = true;
      });
    } catch (e) {
      print("Error taking picture: $e");
    }
  }

  void _onCropped(Uint8List croppedBytes) {
    widget.onCropped(croppedBytes);
    setState(() {
      _capturedImageBytes = croppedBytes;
      _showCropper = false;
    });
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _showCropper && _capturedImageBytes != null
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Crop(
                  controller: _cropController,
                  image: _capturedImageBytes!,
                  onCropped: _onCropped,
                  initialSize: 0.8,
                  maskColor: Colors.black.withOpacity(0.4),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _cropController.crop(),
                child: const Text("Crop & Use", style: TextStyle(color: Color.fromARGB(255, 101, 156, 98))),
              ),
            ],
          )
        : FutureBuilder(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: _cameraController.value.aspectRatio,
                        child: CameraPreview(_cameraController),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _capturePhoto,
                      icon: const Icon(Icons.camera),
                      label: const Text("Capture Selfie",style: TextStyle(color: Color.fromARGB(255, 101, 156, 98))),
                    ),
                  ],
                );
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          );
  }
}
