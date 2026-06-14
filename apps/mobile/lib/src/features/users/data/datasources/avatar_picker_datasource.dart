import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

/// The outcome of an avatar-picker invocation.
///
/// Three terminal states:
///   - [AvatarPickerSuccess] — bytes ready for upload.
///   - [AvatarPickerCancelled] — user dismissed the picker; caller no-ops.
///   - [AvatarPickerPermissionDenied] — OS permission not granted; caller
///       surfaces a banner and an "Open Settings" affordance when [isPermanent].
sealed class AvatarPickerResult {
  const AvatarPickerResult();
}

final class AvatarPickerSuccess extends AvatarPickerResult {
  AvatarPickerSuccess({required this.bytes});

  /// Raw JPEG bytes of the compressed image (≤512×512 px, Q85).
  final Uint8List bytes;
}

final class AvatarPickerCancelled extends AvatarPickerResult {
  const AvatarPickerCancelled();
}

final class AvatarPickerPermissionDenied extends AvatarPickerResult {
  const AvatarPickerPermissionDenied({required this.isPermanent});

  /// True when [PermissionStatus.permanentlyDenied] — caller should show the
  /// "Open Settings" deep-link; false for a soft (first-time) denial.
  final bool isPermanent;
}

// ---------------------------------------------------------------------------
// Datasource
// ---------------------------------------------------------------------------

/// Platform-facing primitive that bridges [ImagePicker] + [permission_handler]
/// for avatar selection.
///
/// Each method checks the appropriate OS permission first, then opens the
/// native picker with inline compression (≤512×512 px, imageQuality 85).
///
/// **iOS native-config reminder** (gitignored `ios/` — apply after
/// `flutter create`):
///   - `NSCameraUsageDescription` — required for [pickFromCamera].
///   - `NSPhotoLibraryUsageDescription` — required for [pickFromLibrary].
///
/// **Android native-config reminder** (gitignored `android/` — apply after
/// `flutter create`):
///   - `<uses-permission android:name="android.permission.CAMERA"/>` — required
///      for [pickFromCamera]. Photo library access is granted by the
///      image_picker plugin's manifest merger automatically on API 33+.
///
/// No crop/rotate UI. No `flutter_image_compress` (deferred to Q2).
abstract class AvatarPickerDatasource {
  /// Opens the device camera to capture a new photo.
  ///
  /// Checks [Permission.camera] before invoking the native picker.
  /// Returns [AvatarPickerSuccess], [AvatarPickerCancelled], or
  /// [AvatarPickerPermissionDenied]. Never throws.
  Future<AvatarPickerResult> pickFromCamera();

  /// Opens the photo library so the user can choose an existing image.
  ///
  /// Checks [Permission.photos] before invoking the native picker.
  /// Returns [AvatarPickerSuccess], [AvatarPickerCancelled], or
  /// [AvatarPickerPermissionDenied]. Never throws.
  Future<AvatarPickerResult> pickFromLibrary();
}

class AvatarPickerDatasourceImpl implements AvatarPickerDatasource {
  AvatarPickerDatasourceImpl({ImagePicker? imagePicker})
    : _picker = imagePicker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<AvatarPickerResult> pickFromCamera() async {
    final denied = await _checkPermission(Permission.camera);
    if (denied != null) return denied;
    return _pick(ImageSource.camera);
  }

  @override
  Future<AvatarPickerResult> pickFromLibrary() async {
    final denied = await _checkPermission(Permission.photos);
    if (denied != null) return denied;
    return _pick(ImageSource.gallery);
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  /// Opens the native picker for [source]. Callers must check permission first.
  ///
  /// Compress inline: ≤512×512 px, Q85. Returns [AvatarPickerCancelled] when
  /// the user dismisses the picker without selecting (null XFile).
  Future<AvatarPickerResult> _pick(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (file == null) return const AvatarPickerCancelled();

    final bytes = await file.readAsBytes();
    return AvatarPickerSuccess(bytes: bytes);
  }

  /// Returns null if [permission] is granted (caller may proceed).
  /// Returns [AvatarPickerPermissionDenied] when denied or permanently denied.
  Future<AvatarPickerPermissionDenied?> _checkPermission(
    Permission permission,
  ) async {
    final status = await permission.status;

    if (status.isPermanentlyDenied) {
      return const AvatarPickerPermissionDenied(isPermanent: true);
    }

    if (status.isDenied) {
      // First-time prompt — request now and re-evaluate.
      final requested = await permission.request();
      if (requested.isDenied || requested.isPermanentlyDenied) {
        return AvatarPickerPermissionDenied(
          isPermanent: requested.isPermanentlyDenied,
        );
      }
    }

    // Granted or restricted — proceed.
    return null;
  }
}
