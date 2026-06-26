/** Outbound port for binary-object storage (selfies at v1, future event photos / avatars). */
export interface FileStorage {
  putObject(input: { key: string; body: Buffer; contentType: string }): Promise<void>;

  deleteObject(input: { key: string }): Promise<void>;

  /**
   * Generate a presigned URL that allows an authenticated GET of the object at `key`.
   *
   * **Presigners do NOT verify key existence.** A presigned read URL for a missing key
   * produces a 404 when fetched by the client — the signature is valid but the object
   * is absent.
   *
   * Caller-supplied `expiresInSeconds` above the adapter cap throws.
   */
  getSignedUrl(input: { key: string; expiresInSeconds: number }): Promise<string>;

  /**
   * Generate a presigned URL that allows an authenticated PUT upload to `key`.
   *
   * **Presigners do NOT verify key existence.** The URL grants write access to the
   * specified key regardless of whether an object already exists there.
   *
   * **Content-Type is bound into the signature.** The client MUST send a matching
   * `Content-Type` header when making the upload request — S3 rejects requests
   * with a mismatched or absent `Content-Type` with a 403 SignatureDoesNotMatch error.
   *
   * Caller-supplied `expiresInSeconds` above the adapter cap throws.
   */
  getSignedUploadUrl(input: {
    key: string;
    contentType: string;
    expiresInSeconds: number;
  }): Promise<string>;

  /**
   * Return the stored object's size in bytes.
   *
   * Throws `AppError.notFound` if the object does not exist or cannot be
   * resolved by the underlying store.
   */
  getObjectSize(input: { key: string }): Promise<number>;
}
