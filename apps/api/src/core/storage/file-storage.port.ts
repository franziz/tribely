/** Outbound port for binary-object storage (selfies at v1, future event photos / avatars). */
export interface FileStorage {
  putObject(input: { key: string; body: Buffer; contentType: string }): Promise<void>;

  deleteObject(input: { key: string }): Promise<void>;

  getSignedUrl(input: { key: string; expiresInSeconds: number }): Promise<string>;
}
