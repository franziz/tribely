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
// Source enum
// ---------------------------------------------------------------------------

/// The image source the user chose on [AvatarSourceSheet].
enum AvatarSource { camera, library }

// ---------------------------------------------------------------------------
// Datasource
// ---------------------------------------------------------------------------

/// Platform-facing primitive that bridges [ImagePicker] + [permission_handler]
/// for avatar selection.
///
/// Responsibilities:
///   1. Check OS permission for the requested [source].
///   2. If denied/permanentlyDenied, return [AvatarPickerPermissionDenied].
///   3. Otherwise open the OS picker, compress the result
///      (maxWidth/maxHeight 512px, imageQuality 85) and return the bytes.
///   4. If the user cancels the OS picker (null return), return
///      [AvatarPickerCancelled].
///
/// **iOS native-config reminder** (gitignored `ios/` — apply after
/// `flutter create`):
///   - `NSCameraUsageDescription` — required for [AvatarSource.camera].
///   - `NSPhotoLibraryUsageDescription` — required for [AvatarSource.library].
///
/// **Android native-config reminder** (gitignored `android/` — apply after
/// `flutter create`):
///   - `<uses-permission android:name="android.permission.CAMERA"/>` — required
///      for [AvatarSource.camera]. Photo library access is granted by the
///      image_picker plugin's manifest merger automatically on API 33+.
///
/// No crop/rotate UI. No `flutter_image_compress` (deferred to Q2).
abstract class AvatarPickerDatasource {
  /// Pick an avatar image from [source] with permission check.
  ///
  /// Returns [AvatarPickerSuccess], [AvatarPickerCancelled], or
  /// [AvatarPickerPermissionDenied]. Never throws.
  Future<AvatarPickerResult> pick(AvatarSource source);
}

class AvatarPickerDatasourceImpl implements AvatarPickerDatasource {
  AvatarPickerDatasourceImpl({ImagePicker? imagePicker})
    : _picker = imagePicker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<AvatarPickerResult> pick(AvatarSource source) async {
    // 1. Check permission first — fail-fast before opening native picker.
    final permissionResult = await _checkPermission(source);
    if (permissionResult != null) return permissionResult;

    // 2. Open native picker. Compress inline: ≤512×512 px, Q85.
    final XFile? file = await _picker.pickImage(
      source: source == AvatarSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    // 3. User cancelled (picker returned null) — signal no-op to caller.
    if (file == null) return const AvatarPickerCancelled();

    // 4. Read compressed bytes and return.
    final bytes = await file.readAsBytes();
    return AvatarPickerSuccess(bytes: bytes);
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  /// Returns null if permission is granted (caller may proceed).
  /// Returns [AvatarPickerPermissionDenied] otherwise.
  Future<AvatarPickerPermissionDenied?> _checkPermission(
    AvatarSource source,
  ) async {
    final permission = switch (source) {
      AvatarSource.camera => Permission.camera,
      AvatarSource.library => Permission.photos,
    };

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
