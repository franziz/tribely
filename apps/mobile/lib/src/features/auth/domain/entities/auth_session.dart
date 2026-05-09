import 'package:equatable/equatable.dart';

import 'user.dart';

/// AuthSession is the post-authentication state held by the app:
///   - the User
///   - the access token (short-lived JWT, sent in Authorization header)
///   - the refresh token (long-lived opaque secret, exchanged at /auth/refresh)
class AuthSession extends Equatable {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
  });

  final User user;
  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;

  bool get accessTokenExpired => DateTime.now().isAfter(accessTokenExpiresAt);
  bool get refreshTokenExpired => DateTime.now().isAfter(refreshTokenExpiresAt);

  @override
  List<Object?> get props => [
        user,
        accessToken,
        accessTokenExpiresAt,
        refreshToken,
        refreshTokenExpiresAt,
      ];
}
