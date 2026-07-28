import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'dart:io';
import 'package:image/image.dart' as img;

// Helper class for compute
class RotateParams {
  final Uint8List bytes;
  final int angle;
  RotateParams(this.bytes, this.angle);
}

// Global function for compute
Uint8List _rotateImageTask(RotateParams params) {
  final image = img.decodeImage(params.bytes);
  if (image != null) {
    final rotated = img.copyRotate(image, angle: params.angle);
    return Uint8List.fromList(img.encodeJpg(rotated, quality: 90));
  }
  return params.bytes;
}

class CustomCropScreen extends StatefulWidget {
  final File imageFile;

  const CustomCropScreen({super.key, required this.imageFile});

  @override
  State<CustomCropScreen> createState() => _CustomCropScreenState();
}

class _CustomCropScreenState extends State<CustomCropScreen> {
  final _cropController = CropController();
  late Uint8List _imageData;
  bool _isLoaded = false;
  bool _isProcessing = false;
  bool _isCropWidgetReady = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    if (mounted) {
      setState(() {
        _imageData = bytes;
        _isLoaded = true;
      });
    }
  }

  Future<void> _rotateImage(int angle) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _isCropWidgetReady = false; // Reset ready state for new image
    });

    try {
      // Use compute to prevent main thread blocking
      final rotatedBytes = await compute(
        _rotateImageTask,
        RotateParams(_imageData, angle),
      );
      if (mounted) {
        setState(() {
          _imageData = rotatedBytes;
        });
      }
    } catch (e) {
      debugPrint('Error rotating image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _handleDone() {
    if (_isProcessing || !_isCropWidgetReady) return;

    // Set processing to true to prevent double clicks
    setState(() => _isProcessing = true);
    _cropController.crop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1EA443)),
        ),
      );
    }

    final bool canInteract = !_isProcessing && _isCropWidgetReady;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Edit Photo',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1EA443),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_left),
            tooltip: 'Rotate Left',
            onPressed: !_isProcessing ? () => _rotateImage(-90) : null,
          ),
          IconButton(
            icon: const Icon(Icons.rotate_right),
            tooltip: 'Rotate Right',
            onPressed: !_isProcessing ? () => _rotateImage(90) : null,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Done',
            onPressed: canInteract ? _handleDone : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Crop(
                    key: ValueKey(_imageData), // Force rebuild on new data
                    controller: _cropController,
                    image: _imageData,
                    onCropped: (result) {
                      // Safety check to avoid Navigator lock errors
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          if (result is CropSuccess) {
                            Navigator.pop(context, result.croppedImage);
                          } else if (result is CropFailure) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Cropping failed: ${result.cause}',
                                ),
                              ),
                            );
                            setState(() => _isProcessing = false);
                          }
                        }
                      });
                    },
                    onStatusChanged: (status) {
                      if (mounted) {
                        setState(() {
                          _isCropWidgetReady = status == CropStatus.ready;
                        });
                      }
                    },
                    aspectRatio: 3 / 2,
                    withCircleUi: false,
                    baseColor: Colors.black,
                    maskColor: Colors.black.withAlpha(150),
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  child: Center(
                    child: Text(
                      _isProcessing
                          ? 'Processing...'
                          : (!_isCropWidgetReady
                                ? 'Loading image...'
                                : 'Adjust original frame or rotate if needed'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_isProcessing)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF1EA443)),
                      SizedBox(height: 20),
                      Text(
                        'Please wait...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
