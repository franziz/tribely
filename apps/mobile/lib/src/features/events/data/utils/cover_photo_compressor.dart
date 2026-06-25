import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Downscales raw image bytes to cover-photo dimensions using the platform
/// image codec.
///
/// Output is always JPEG regardless of input format, so the presign
/// `contentType` for the PUT is always `image/jpeg` after calling this.
/// Callers must presign with `image/jpeg` — the S3 signature binds the
/// content-type sent on PUT.
///
/// Target dimensions follow the brief spec: 1600 × 900 minimum bounding box
/// at quality 80. The compressor preserves aspect ratio — neither dimension
/// will be scaled *below* the minimum, and the larger dimension scales
/// proportionally.
class CoverPhotoCompressor {
  const CoverPhotoCompressor();

  /// The MIME type produced by [compress]. Always `image/jpeg`.
  static const String outputMimeType = 'image/jpeg';

  /// Downscales [bytes] to ≥1600 × 900 px at Q80, encoding as JPEG.
  ///
  /// Returns the compressed bytes. Throws if the underlying platform codec
  /// fails (e.g. unsupported input format).
  Future<Uint8List> compress(Uint8List bytes) async {
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1600,
      minHeight: 900,
      quality: 80,
      format: CompressFormat.jpeg,
    );
    return result;
  }
}
