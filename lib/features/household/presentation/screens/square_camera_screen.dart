import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/app_colors.dart';

/// Full-screen camera with a live square viewfinder overlay.
/// Navigates back with the cropped square image path [String], or null if cancelled.
class SquareCameraScreen extends StatefulWidget {
  const SquareCameraScreen({super.key});

  @override
  State<SquareCameraScreen> createState() => _SquareCameraScreenState();
}

class _SquareCameraScreenState extends State<SquareCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isTakingPicture = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      if (mounted) setState(() => _isInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) Navigator.pop(context, null);
        return;
      }
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('[SquareCamera] Init error: $e');
      if (mounted) Navigator.pop(context, null);
    }
  }

  Future<void> _capture() async {
    if (!_isInitialized || _isTakingPicture || _controller == null) return;
    setState(() => _isTakingPicture = true);
    try {
      final xFile = await _controller!.takePicture();
      final bytes = await File(xFile.path).readAsBytes();
      final rawImage = img.decodeImage(bytes);
      if (rawImage == null) {
        if (mounted) Navigator.pop(context, null);
        return;
      }
      // Center-crop to square — matches what the square viewfinder shows.
      final side = min(rawImage.width, rawImage.height);
      final x = (rawImage.width - side) ~/ 2;
      final y = (rawImage.height - side) ~/ 2;
      final cropped = img.copyCrop(
        rawImage,
        x: x,
        y: y,
        width: side,
        height: side,
      );
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/square_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(outputPath).writeAsBytes(img.encodeJpg(cropped, quality: 95));
      if (mounted) Navigator.pop(context, outputPath);
    } catch (e) {
      debugPrint('[SquareCamera] Capture error: $e');
      if (mounted) setState(() => _isTakingPicture = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final screenH = mq.size.height;
    final safeTop = mq.padding.top;

    // Top bar height: status bar + 56dp nav bar
    const double kTopBarHeight = 56.0;
    final double squareTopOffset = safeTop + kTopBarHeight + 96.0;

    // Match the painter's sizing exactly
    final double squareSize = min(screenW - 32.0, screenH * 0.55);
    final double squareLeft = (screenW - squareSize) / 2;
    final double squareBottom = squareTopOffset + squareSize;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ───────────────────────────────────────────────
          if (_isInitialized && _controller != null)
            CameraPreview(_controller!)
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // ── Dark overlay with transparent square cutout ───────────────────
          if (_isInitialized)
            _SquareOverlay(squareTop: squareTopOffset, squareSize: squareSize),

          // ── Top bar (always in the dark zone above the square) ────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: kTopBarHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context, null),
                    ),
                    const Spacer(),
                    const Text(
                      'Scan Material',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // ── Instruction label just above the square ────────────────────────
          Positioned(
            top: squareTopOffset - 36,
            left: squareLeft,
            width: squareSize,
            child: const Text(
              'Center the material inside the box',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),

          // ── Tip card just below the square ────────────────────────────────
          Positioned(
            top: squareBottom + 14,
            left: 24,
            right: 24,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tips_and_updates_rounded,
                        color: AppColors.primaryGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Keeping the material inside the box helps the AI identify it accurately and gives you a better price estimate.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Capture button ─────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32, top: 16),
                child: Center(
                  child: GestureDetector(
                    onTap: _isTakingPicture ? null : _capture,
                    child: _CaptureButton(isLoading: _isTakingPicture),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overlay
// ---------------------------------------------------------------------------

class _SquareOverlay extends StatelessWidget {
  final double squareTop;
  final double squareSize;

  const _SquareOverlay({required this.squareTop, required this.squareSize});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(squareTop: squareTop, squareSize: squareSize),
      child: Container(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final double squareTop;
  final double squareSize;

  const _OverlayPainter({required this.squareTop, required this.squareSize});

  @override
  void paint(Canvas canvas, Size size) {
    final left = (size.width - squareSize) / 2;
    final top = squareTop;
    final right = left + squareSize;
    final bottom = top + squareSize;

    // Dark overlay everywhere except inside the square
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.60);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(Rect.fromLTRB(left, top, right, bottom))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, dimPaint);

    // Subtle white border around the square
    canvas.drawRect(
      Rect.fromLTRB(left, top, right, bottom),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Green corner accents
    const cornerLen = 28.0;
    final cornerPaint = Paint()
      ..color = AppColors.primaryGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(
      Offset(left, top + cornerLen),
      Offset(left, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLen, top),
      cornerPaint,
    );
    // Top-right
    canvas.drawLine(
      Offset(right - cornerLen, top),
      Offset(right, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right, top),
      Offset(right, top + cornerLen),
      cornerPaint,
    );
    // Bottom-left
    canvas.drawLine(
      Offset(left, bottom - cornerLen),
      Offset(left, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left + cornerLen, bottom),
      cornerPaint,
    );
    // Bottom-right
    canvas.drawLine(
      Offset(right - cornerLen, bottom),
      Offset(right, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - cornerLen),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) =>
      old.squareTop != squareTop || old.squareSize != squareSize;
}

// ---------------------------------------------------------------------------
// Capture button
// ---------------------------------------------------------------------------

class _CaptureButton extends StatelessWidget {
  final bool isLoading;

  const _CaptureButton({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer ring
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
        ),
        // Inner disc  — shrinks slightly while processing
        AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: isLoading ? 40 : 58,
          height: isLoading ? 40 : 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLoading ? Colors.grey[400] : Colors.white,
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
      ],
    );
  }
}
