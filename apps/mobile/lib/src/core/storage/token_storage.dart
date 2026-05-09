import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistent secure storage for the auth tokens.
///
/// Backed by:
///   - iOS: Keychain
///   - Android: EncryptedSharedPreferences
class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessKey = 'auth.access_token';
  static const _accessExpiresKey = 'auth.access_expires_at';
  static const _refreshKey = 'auth.refresh_token';
  static const _refreshExpiresKey = 'auth.refresh_expires_at';

  Future<void> saveTokens({
    required String accessToken,
    required DateTime accessExpiresAt,
    required String refreshToken,
    required DateTime refreshExpiresAt,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(
      key: _accessExpiresKey,
      value: accessExpiresAt.toIso8601String(),
    );
    await _storage.write(key: _refreshKey, value: refreshToken);
    await _storage.write(
      key: _refreshExpiresKey,
      value: refreshExpiresAt.toIso8601String(),
    );
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessKey);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<DateTime?> readRefreshTokenExpiresAt() async {
    final raw = await _storage.read(key: _refreshExpiresKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _accessExpiresKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _refreshExpiresKey);
  }
}
