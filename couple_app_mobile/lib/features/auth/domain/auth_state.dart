import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

enum AuthStatus { unknown, unauthenticated, biometricPending, authenticated }

@immutable
class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.userId,
    this.username,
    this.accessToken,
    this.errorMessage,
  });

  final AuthStatus status;
  final String? userId;
  final String? username;
  final String? accessToken;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? username,
    String? accessToken,
    String? errorMessage,
  }) =>
      AuthState(
        status:       status       ?? this.status,
        userId:       userId       ?? this.userId,
        username:     username     ?? this.username,
        accessToken:  accessToken  ?? this.accessToken,
        errorMessage: errorMessage,
      );
}
