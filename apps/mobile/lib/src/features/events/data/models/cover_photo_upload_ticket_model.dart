/// Wire-shape model for the POST /events/cover-photo presign response.
///
/// The backend returns `{ uploadUrl, storageKey }`. This model is the boundary
/// mapper — it never crosses into domain. The repository extracts the two
/// fields and orchestrates the upload directly.
class CoverPhotoUploadTicketModel {
  const CoverPhotoUploadTicketModel({
    required this.uploadUrl,
    required this.storageKey,
  });

  factory CoverPhotoUploadTicketModel.fromJson(Map<String, dynamic> json) =>
      CoverPhotoUploadTicketModel(
        uploadUrl: json['uploadUrl'] as String,
        storageKey: json['storageKey'] as String,
      );

  final String uploadUrl;
  final String storageKey;
}
