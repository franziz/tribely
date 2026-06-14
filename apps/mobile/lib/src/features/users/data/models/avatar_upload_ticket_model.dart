/// Wire-shape model for the POST /users/me/avatar presign response.
///
/// The backend returns `{ uploadUrl, storageKey }`. This model is the boundary
/// mapper — it never crosses into domain. The repository extracts the two
/// fields and orchestrates the upload directly.
class AvatarUploadTicketModel {
  const AvatarUploadTicketModel({
    required this.uploadUrl,
    required this.storageKey,
  });

  factory AvatarUploadTicketModel.fromJson(Map<String, dynamic> json) =>
      AvatarUploadTicketModel(
        uploadUrl: json['uploadUrl'] as String,
        storageKey: json['storageKey'] as String,
      );

  final String uploadUrl;
  final String storageKey;
}
