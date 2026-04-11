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
    this.partnerId,
    this.partnerName,
    this.partnerPublicKey,
  });

  final AuthStatus status;
  final String? userId;
  final String? username;
  final String? accessToken;
  final String? errorMessage;

  // Partner bilgisi (2-kişilik uygulama için)
  final String? partnerId;
  final String? partnerName;
  final String? partnerPublicKey;

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? username,
    String? accessToken,
    String? errorMessage,
    String? partnerId,
    String? partnerName,
    String? partnerPublicKey,
  }) =>
      AuthState(
        status:           status           ?? this.status,
        userId:           userId           ?? this.userId,
        username:         username         ?? this.username,
        accessToken:      accessToken      ?? this.accessToken,
        errorMessage:     errorMessage,
        partnerId:        partnerId        ?? this.partnerId,
        partnerName:      partnerName      ?? this.partnerName,
        partnerPublicKey: partnerPublicKey ?? this.partnerPublicKey,
      );
}

