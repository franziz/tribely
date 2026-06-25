/// Wire-shape model for the POST /auth/selfie presign response.
///
/// The backend returns `{ uploadUrl, storageKey }`. This model is the boundary
/// mapper — it never crosses into domain. The use case maps it to a plain
/// record / passes the two strings directly.
class SelfieUploadPresignModel {
  const SelfieUploadPresignModel({
    required this.uploadUrl,
    required this.storageKey,
  });

  factory SelfieUploadPresignModel.fromJson(Map<String, dynamic> json) =>
      SelfieUploadPresignModel(
        uploadUrl: json['uploadUrl'] as String,
        storageKey: json['storageKey'] as String,
      );

  final String uploadUrl;
  final String storageKey;
}
