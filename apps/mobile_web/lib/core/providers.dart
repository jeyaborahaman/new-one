import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'network/api_client.dart';
import 'network/socket_service.dart';
import 'models.dart';

final tokenStoreProvider = Provider<TokenStore>((_) => TokenStore());
final socketProvider = Provider<SocketService>((ref) { final s = SocketService(); ref.onDispose(s.disconnect); return s; });

final apiProvider = Provider<ApiClient>((ref) {
  final store = ref.watch(tokenStoreProvider);
  return ApiClient(store, onSignedOut: () => ref.read(authProvider.notifier).forceSignedOut());
});

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;
  void set(ThemeMode m) => state = m;
}
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

enum AuthStatus { unknown, signedOut, signedIn }
class AuthState {
  const AuthState(this.status, [this.user]);
  final AuthStatus status; final User? user;
}

/// Result of a login attempt: either signed in, or a 2FA challenge to complete.
class LoginResult { LoginResult({this.challengeToken}); final String? challengeToken; bool get needs2fa => challengeToken != null; }

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState(AuthStatus.unknown);

  ApiClient get _api => ref.read(apiProvider);
  TokenStore get _store => ref.read(tokenStoreProvider);

  /// Restore a saved session on app start.
  Future<void> restore() async {
    await _store.load();
    if (_store.refresh == null) { state = const AuthState(AuthStatus.signedOut); return; }
    try { await _enter(User.fromJson(await _api.get('/users/me'))); } on ApiException catch (e) {
      // Only a rejected session signs the user out; a network failure keeps the tokens for the next start.
      state = const AuthState(AuthStatus.signedOut);
      if (e.status == 401) await _store.clear();
    }
  }

  Future<void> _enter(User u) async {
    state = AuthState(AuthStatus.signedIn, u);
    ref.read(socketProvider).connect(_store.access!);
  }

  Future<LoginResult> _finish(dynamic r) async {
    if (r['requires_2fa'] == true) return LoginResult(challengeToken: r['challenge_token']);
    await _store.save(r['accessToken'], r['refreshToken']);
    await _enter(User.fromJson(r['user']));
    return LoginResult();
  }

  Future<LoginResult> login(String identifier, String password) async => _finish(await _api.post('/auth/login', body: {'identifier': identifier, 'password': password}));
  Future<void> verify2fa(String challenge, String code) async => _finish(await _api.post('/auth/2fa/verify', body: {'challenge_token': challenge, 'code': code}));
  Future<void> register({required String email, required String username, required String password, String? displayName, String? referral}) async =>
      _finish(await _api.post('/auth/register', body: {'email': email, 'username': username, 'password': password, if (displayName != null && displayName.isNotEmpty) 'display_name': displayName, if (referral != null && referral.isNotEmpty) 'referral_code': referral}));
  Future<void> requestOtp(String phone) => _api.post('/auth/otp/request', body: {'phone': phone});
  Future<LoginResult> verifyOtp(String phone, String code) async => _finish(await _api.post('/auth/otp/verify', body: {'phone': phone, 'code': code}));
  Future<void> forgot(String email) => _api.post('/auth/password/forgot', body: {'email': email});
  Future<void> reset(String email, String code, String pw) => _api.post('/auth/password/reset', body: {'email': email, 'code': code, 'new_password': pw});

  Future<void> refreshUser() async { if (state.status == AuthStatus.signedIn) state = AuthState(AuthStatus.signedIn, User.fromJson(await _api.get('/users/me'))); }

  Future<void> logout() async {
    final r = _store.refresh;
    if (r != null) { try { await _api.post('/auth/logout', body: {'refreshToken': r}); } catch (_) {} }
    forceSignedOut();
    await _store.clear();
  }

  void forceSignedOut() { ref.read(socketProvider).disconnect(); state = const AuthState(AuthStatus.signedOut); }
}
final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
