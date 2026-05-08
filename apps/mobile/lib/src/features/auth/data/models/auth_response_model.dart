import '../../domain/entities/auth_session.dart';
import 'user_model.dart';

class AuthTokensModel {
  const AuthTokensModel({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
  });

  factory AuthTokensModel.fromJson(Map<String, dynamic> json) =>
      AuthTokensModel(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        accessTokenExpiresAt:
            DateTime.parse(json['accessTokenExpiresAt'] as String),
      );

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
}

class AuthResponseModel {
  const AuthResponseModel({required this.user, required this.tokens});

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) =>
      AuthResponseModel(
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
        tokens:
            AuthTokensModel.fromJson(json['tokens'] as Map<String, dynamic>),
      );

  final UserModel user;
  final AuthTokensModel tokens;

  AuthSession toEntity() => AuthSession(
        user: user.toEntity(),
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        accessTokenExpiresAt: tokens.accessTokenExpiresAt,
      );
}
