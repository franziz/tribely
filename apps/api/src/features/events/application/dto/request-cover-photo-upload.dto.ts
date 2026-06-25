export type RequestCoverPhotoUploadInput = {
  hostUserId: string;
  contentType: string;
};

export type RequestCoverPhotoUploadResult = {
  uploadUrl: string;
  storageKey: string;
};
