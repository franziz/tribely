import 'package:equatable/equatable.dart';

import 'user.dart';

class AuthSession extends Equatable {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
  });

  final User user;
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;

  @override
  List<Object?> get props =>
      [user, accessToken, refreshToken, accessTokenExpiresAt];
}
