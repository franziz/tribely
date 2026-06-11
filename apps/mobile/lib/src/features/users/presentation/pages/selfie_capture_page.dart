import 'package:flutter/material.dart';

/// Selfie capture screen — Screen 2 of the selfie verification flow.
///
/// Route: /selfie/capture
///
/// This stub is a compile-time placeholder that satisfies Brief D's router
/// wiring requirement. Brief E replaces it with the full implementation:
/// CameraPreview, CameraOverlayWidget, ML-Kit face guidance, state matrix,
/// and the submit flow.
///
/// TODO(TRI-23-E): replace with the full SelfieCapturePageStub → SelfieCapturePage
/// implementation from Brief E.
class SelfieCapturePageStub extends StatelessWidget {
  const SelfieCapturePageStub({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
