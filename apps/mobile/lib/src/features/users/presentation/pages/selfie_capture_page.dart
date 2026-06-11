import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/motion.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/loading_dots.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/usecases/request_selfie_upload_usecase.dart';
import '../../domain/usecases/submit_selfie_usecase.dart';
import '../string_assets/selfie_capture_copy.dart';
import '../widgets/camera_overlay_widget.dart';
import '../widgets/selfie_challenge_card.dart';

// ---------------------------------------------------------------------------
// Public entry point — replaces Brief D's SelfieCapturePageStub.
//
// Brief E ships the real implementation; Brief D's router wiring stays intact
// because this file exports SelfieCapturePageStub as a type alias so
// app_router.dart does not need updating.
// ---------------------------------------------------------------------------

/// Type alias so app_router.dart keeps referring to SelfieCapturePageStub
/// without needing a follow-up router change.
typedef SelfieCapturePageStub = SelfieCapturePage;

/// Screen 2 — Selfie capture.
///
/// Route: /selfie/capture
///
/// Camera lifecycle requires a [ConsumerStatefulWidget] to own the
/// [CameraController] so it is properly disposed on pop.
///
/// State matrix:
///   - [_CaptureState.checkingPermission] — initial, checking camera status
///   - [_CaptureState.permissionDenied]   — camera access denied
///   - [_CaptureState.initialising]       — camera starting up
///   - [_CaptureState.mlKitUnavailable]  — ML-Kit init failed (graceful)
///   - [_CaptureState.ready]              — camera live, guidance active
///   - [_CaptureState.frozen]             — frame captured, uploading
///   - [_CaptureState.uploading]          — use-cases in flight
///   - [_CaptureState.error]              — upload failed, retry banner shown
///
/// On success: context.go('/settings/verification').
class SelfieCapturePage extends ConsumerStatefulWidget {
  const SelfieCapturePage({super.key});

  @override
  ConsumerState<SelfieCapturePage> createState() => _SelfieCapturePageState();
}

// ---------------------------------------------------------------------------
// Page state enum
// ---------------------------------------------------------------------------

enum _CaptureState {
  checkingPermission,
  permissionDenied,
  initialising,
  mlKitUnavailable,
  ready,
  frozen,
  uploading,
  error,
}

// ---------------------------------------------------------------------------
// ML-Kit guidance state
// ---------------------------------------------------------------------------

enum _GuidanceState {
  centerFace,
  onePerson,
  betterLight,
  holdSteady,
  closer,
  back,
  pass,
}

extension _GuidanceCopy on _GuidanceState {
  String get label => switch (this) {
        _GuidanceState.centerFace => kGuidanceCenterFace,
        _GuidanceState.onePerson => kGuidanceOnePerson,
        _GuidanceState.betterLight => kGuidanceBetterLight,
        _GuidanceState.holdSteady => kGuidanceHoldSteady,
        _GuidanceState.closer => kGuidanceCloser,
        _GuidanceState.back => kGuidanceBack,
        _GuidanceState.pass => kGuidancePass,
      };
}

// ---------------------------------------------------------------------------
// State widget
// ---------------------------------------------------------------------------

class _SelfieCapturePageState extends ConsumerState<SelfieCapturePage> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;

  _CaptureState _state = _CaptureState.checkingPermission;
  _GuidanceState _guidance = _GuidanceState.centerFace;

  /// Non-null when state == error. Holds the human-readable banner message.
  String? _errorMessage;

  /// Captured JPEG bytes — non-null in [_CaptureState.frozen] onward.
  List<int>? _capturedJpegBytes;

  /// Pre-sign result — populated after [RequestSelfieUploadUseCase] succeeds.
  ({String uploadUrl, String storageKey})? _presign;

  bool _mlKitAvailable = true;

  // Guidance is derived from the ML-Kit stream — we throttle it to avoid
  // flickering from frame-to-frame noise.
  Timer? _guidanceDebounce;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _guidanceDebounce?.cancel();
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Init sequence
  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    // Check camera permission status. If we arrived from consent, it should be
    // granted, but the user may have revoked it in Settings between screens.
    final status = await Permission.camera.status;
    if (!mounted) return;

    if (status.isDenied || status.isPermanentlyDenied) {
      setState(() => _state = _CaptureState.permissionDenied);
      return;
    }

    setState(() => _state = _CaptureState.initialising);

    // Initialise ML-Kit face detector — failure is graceful (capture always
    // enabled, moderators handle quality).
    try {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.fast,
          enableClassification: true,
        ),
      );
    } catch (_) {
      _mlKitAvailable = false;
    }

    // Get front camera.
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      // Start ML-Kit stream processing only when detector is available.
      if (_mlKitAvailable && _faceDetector != null) {
        await _cameraController!.startImageStream(_onCameraFrame);
      }

      setState(
        () => _state = _mlKitAvailable
            ? _CaptureState.ready
            : _CaptureState.mlKitUnavailable,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _CaptureState.error;
        _errorMessage = kCaptureServerErrorBanner;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // ML-Kit camera stream processing
  // ---------------------------------------------------------------------------

  bool _processingFrame = false;

  void _onCameraFrame(CameraImage image) {
    if (_processingFrame) return;
    if (_state != _CaptureState.ready) return;
    _processingFrame = true;
    _processFrame(image).whenComplete(() => _processingFrame = false);
  }

  Future<void> _processFrame(CameraImage image) async {
    final detector = _faceDetector;
    if (detector == null) return;

    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null) return;

      final faces = await detector.processImage(inputImage);
      if (!mounted) return;

      final guidance = _deriveGuidance(faces);

      _guidanceDebounce?.cancel();
      _guidanceDebounce = Timer(TribelyMotion.short, () {
        if (mounted && _state == _CaptureState.ready) {
          setState(() => _guidance = guidance);
        }
      });
    } catch (_) {
      // Silently drop frame analysis errors — detector failure degrades to
      // the mlKitUnavailable capture-always-active mode.
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final controller = _cameraController;
    if (controller == null) return null;
    final camera = controller.description;

    final rotation = InputImageRotationValue.fromRawValue(
          camera.sensorOrientation,
        ) ??
        InputImageRotation.rotation0deg;

    if (image.planes.isEmpty) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.yuv420,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  _GuidanceState _deriveGuidance(List<Face> faces) {
    if (faces.isEmpty) return _GuidanceState.centerFace;
    if (faces.length > 1) return _GuidanceState.onePerson;

    final face = faces.first;

    // Bounding-box size heuristic for closer/back guidance.
    // The face bounding box is relative to the image size. We want the face
    // to occupy roughly 30–70% of the width.
    final controller = _cameraController;
    if (controller != null && controller.value.isInitialized) {
      final imageWidth = controller.value.previewSize?.width ?? 1;
      final faceWidthRatio = face.boundingBox.width / imageWidth;
      if (faceWidthRatio < 0.25) return _GuidanceState.closer;
      if (faceWidthRatio > 0.75) return _GuidanceState.back;
    }

    // Euler Y angle — if the face is tilted too far sideways, prompt center.
    final eulerY = face.headEulerAngleY;
    if (eulerY != null && eulerY.abs() > 20) return _GuidanceState.centerFace;

    // Euler Z angle — rotation.
    final eulerZ = face.headEulerAngleZ;
    if (eulerZ != null && eulerZ.abs() > 20) return _GuidanceState.centerFace;

    return _GuidanceState.pass;
  }

  // ---------------------------------------------------------------------------
  // Capture + submit flow
  // ---------------------------------------------------------------------------

  Future<void> _onCapture() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    // Stop stream before taking picture.
    if (_mlKitAvailable) {
      try {
        await controller.stopImageStream();
      } catch (_) {
        // Ignore — stream may already be stopped.
      }
    }

    setState(() {
      _state = _CaptureState.frozen;
      _guidance = _GuidanceState.holdSteady;
    });

    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      _capturedJpegBytes = bytes;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _CaptureState.error;
        _errorMessage = kCaptureServerErrorBanner;
      });
      return;
    }

    // Step 1: request presign.
    setState(() => _state = _CaptureState.uploading);

    final requestUseCase = sl<RequestSelfieUploadUseCase>();
    final presignResult = await requestUseCase(const NoParams());

    if (!mounted) return;

    final presignFailure = presignResult.fold(
      (failure) => failure,
      (presign) {
        _presign = presign;
        return null;
      },
    );

    if (presignFailure != null) {
      _handleSubmitFailure(presignFailure);
      return;
    }

    // Step 2: upload JPEG + submit.
    final submitUseCase = sl<SubmitSelfieUseCase>();
    final presign = _presign!;
    final submitParams = SubmitSelfieParams(
      uploadUrl: presign.uploadUrl,
      storageKey: presign.storageKey,
      jpegBytes: _capturedJpegBytes!,
    );
    final submitResult = await submitUseCase(submitParams);

    if (!mounted) return;

    submitResult.fold(
      _handleSubmitFailure,
      (_) {
        // Success — navigate to verification settings where pending state renders.
        context.go('/settings/verification');
      },
    );
  }

  void _handleSubmitFailure(Failure failure) {
    if (!mounted) return;
    final message = switch (failure) {
      NetworkFailure() => kCaptureOfflineBanner,
      SelfieIntakeDisabledFailure() =>
        'Verification is temporarily unavailable. Please try again later.',
      _ => kCaptureServerErrorBanner,
    };
    setState(() {
      _state = _CaptureState.error;
      _errorMessage = message;
    });
  }

  Future<void> _onRetry() async {
    setState(() {
      _state = _CaptureState.checkingPermission;
      _errorMessage = null;
      _capturedJpegBytes = null;
      _presign = null;
    });
    await _init();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: switch (_state) {
          _CaptureState.permissionDenied =>
            _buildPermissionDenied(context, ink: ink),
          _CaptureState.checkingPermission ||
          _CaptureState.initialising =>
            _buildInitialising(),
          _CaptureState.ready ||
          _CaptureState.mlKitUnavailable ||
          _CaptureState.frozen ||
          _CaptureState.uploading ||
          _CaptureState.error =>
            _buildCapture(context, dark: dark),
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Initialising / loading state
  // ---------------------------------------------------------------------------

  Widget _buildInitialising() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  // ---------------------------------------------------------------------------
  // Permission denied state
  // ---------------------------------------------------------------------------

  Widget _buildPermissionDenied(BuildContext context, {required Color ink}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 56),
          const SizedBox(height: 24),
          Text(
            kPermissionDeniedHeadline,
            style: TribelyType.headline(Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            kPermissionDeniedBody,
            style: TribelyType.bodyM(Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: kPermissionDeniedCtaLabel,
            onPressed: () async {
              await openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Camera capture UI (ready / frozen / uploading / error / mlKitUnavailable)
  // ---------------------------------------------------------------------------

  Widget _buildCapture(BuildContext context, {required bool dark}) {
    final controller = _cameraController;
    final isUploading = _state == _CaptureState.uploading ||
        _state == _CaptureState.frozen;

    final captureEnabled = (_state == _CaptureState.ready &&
            _guidance == _GuidanceState.pass) ||
        _state == _CaptureState.mlKitUnavailable;

    final feedback = switch (_guidance) {
      _GuidanceState.pass => OverlayFeedback.pass,
      _GuidanceState.centerFace ||
      _GuidanceState.onePerson ||
      _GuidanceState.betterLight ||
      _GuidanceState.closer ||
      _GuidanceState.back =>
        OverlayFeedback.block,
      _ => OverlayFeedback.idle,
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview — full viewport.
        if (controller != null && controller.value.isInitialized)
          CameraPreview(controller)
        else
          const ColoredBox(color: Colors.black),

        // Overlay — oval cutout + scrim.
        if (_state != _CaptureState.permissionDenied)
          CameraOverlayWidget(
            feedback: isUploading ? OverlayFeedback.idle : feedback,
          ),

        // Guidance text — centred above overlay, animated.
        if (_state == _CaptureState.ready ||
            _state == _CaptureState.mlKitUnavailable)
          Positioned(
            top: 24,
            left: 24,
            right: 24,
            child: Semantics(
              liveRegion: true,
              child: AnimatedSwitcher(
                duration: TribelyMotion.short,
                child: Text(
                  key: ValueKey(_guidance),
                  _state == _CaptureState.mlKitUnavailable
                      ? kGuidanceHoldSteady
                      : _guidance.label,
                  style: TribelyType.bodyM(Colors.white).copyWith(
                    // Clamp textScaleFactor at 1.3 per a11y spec.
                    fontSize: 15 *
                        MediaQuery.textScalerOf(context)
                            .scale(1)
                            .clamp(0, 1.3),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

        // Upload loading overlay.
        if (isUploading)
          ColoredBox(
            color: Colors.black.withValues(alpha: 0.5),
            child: const Center(
              child: LoadingDots(color: Colors.white),
            ),
          ),

        // Error banner — displayed above the capture controls.
        if (_state == _CaptureState.error && _errorMessage != null)
          Positioned(
            bottom: 160,
            left: 16,
            right: 16,
            child: BannerMessage(
              message: _errorMessage!,
              action: BannerAction(
                label: kCaptureRetryAction,
                onTap: _onRetry,
              ),
            ),
          ),

        // Bottom area — challenge card + capture button.
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Challenge card — dismissible tip.
                  if (_state == _CaptureState.ready ||
                      _state == _CaptureState.mlKitUnavailable)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: DismissableSelfieChallengeCard(),
                    ),

                  // Capture button — 72dp, circular, white.
                  Semantics(
                    button: true,
                    label: kCaptureButtonSemanticLabel,
                    enabled: captureEnabled && !isUploading,
                    child: GestureDetector(
                      onTap: captureEnabled && !isUploading ? _onCapture : null,
                      child: AnimatedOpacity(
                        opacity: captureEnabled ? 1.0 : 0.4,
                        duration: TribelyMotion.short,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: captureEnabled
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.3),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 3,
                            ),
                          ),
                          child: isUploading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
