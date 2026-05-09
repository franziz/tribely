import '../../domain/entities/auth_session.dart';
import 'user_model.dart';

class _IssuedTokenModel {
  const _IssuedTokenModel({required this.value, required this.expiresAt});

  factory _IssuedTokenModel.fromJson(Map<String, dynamic> json) =>
      _IssuedTokenModel(
        value: json['value'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );

  final String value;
  final DateTime expiresAt;
}

class AuthResponseModel {
  const AuthResponseModel({
    required this.user,
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    final access =
        _IssuedTokenModel.fromJson(json['accessToken'] as Map<String, dynamic>);
    final refresh = _IssuedTokenModel.fromJson(
      json['refreshToken'] as Map<String, dynamic>,
    );
    return AuthResponseModel(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: access.value,
      accessTokenExpiresAt: access.expiresAt,
      refreshToken: refresh.value,
      refreshTokenExpiresAt: refresh.expiresAt,
    );
  }

  final UserModel user;
  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;

  AuthSession toEntity() => AuthSession(
        user: user.toEntity(),
        accessToken: accessToken,
        accessTokenExpiresAt: accessTokenExpiresAt,
        refreshToken: refreshToken,
        refreshTokenExpiresAt: refreshTokenExpiresAt,
      );
}
