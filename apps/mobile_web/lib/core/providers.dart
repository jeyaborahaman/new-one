import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'l10n.dart';
import 'network/api_client.dart';
import 'network/socket_service.dart';
import 'models.dart';
import 'push_service.dart';

final tokenStoreProvider = Provider<TokenStore>((_) => TokenStore());
final socketProvider = Provider<SocketService>((ref) { final s = SocketService(); ref.onDispose(s.disconnect); return s; });

final apiProvider = Provider<ApiClient>((ref) {
  final store = ref.watch(tokenStoreProvider);
  return ApiClient(store, onSignedOut: () => ref.read(authProvider.notifier).forceSignedOut(), language: () => effectiveLanguage(ref.read(localeProvider)));
});

/// Small non-secret preferences (the chosen language). Same platform storage the tokens use, so no extra plugin.
final prefsStorageProvider = Provider<FlutterSecureStorage>((_) => const FlutterSecureStorage());

/// The user's language choice; null follows the device (falling back to English).
class LocaleController extends Notifier<Locale?> {
  static const _key = 'app_locale';
  @override
  Locale? build() => null;
  FlutterSecureStorage get _store => ref.read(prefsStorageProvider);

  /// Restores the saved choice at start-up.
  Future<void> load() async {
    try {
      final v = await _store.read(key: _key);
      if (v != null && supportedLanguages.contains(v)) state = Locale(v);
    } catch (_) { /* storage unavailable: keep following the device */ }
  }

  /// Saves the choice and tells the server, so push notifications arrive in this language.
  Future<void> set(Locale? locale) async {
    state = locale;
    try { locale == null ? await _store.delete(key: _key) : await _store.write(key: _key, value: locale.languageCode); } catch (_) {}
    await ref.read(authProvider.notifier).syncLanguage();
  }
}
final localeProvider = NotifierProvider<LocaleController, Locale?>(LocaleController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;
  void set(ThemeMode m) => state = m;
}
/// Decouples push handling from the router: the service asks for a route, the app widget performs it.
class RouteRequest extends Notifier<String?> {
  @override
  String? build() => null;
  void request(String route) => state = route;
  void clear() => state = null;
}
final routeRequestProvider = NotifierProvider<RouteRequest, String?>(RouteRequest.new);

class ForegroundBanner extends Notifier<({String title, String body})?> {
  @override
  ({String title, String body})? build() => null;
  void show(String title, String body) => state = (title: title, body: body);
}
final bannerProvider = NotifierProvider<ForegroundBanner, ({String title, String body})?>(ForegroundBanner.new);

final pushBackendProvider = Provider<PushBackend>((_) => FirebasePushBackend());
final pushServiceProvider = Provider<PushService>((ref) => PushService(
      ref.watch(apiProvider), ref.watch(pushBackendProvider),
      onOpenRoute: (r) => ref.read(routeRequestProvider.notifier).request(r),
      onForegroundMessage: (t, b) => ref.read(bannerProvider.notifier).show(t, b),
    ));

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
    ref.read(socketProvider).connect(() => _store.access, refresh: _api.refreshTokens);
    unawaited(syncLanguage());
    unawaited(ref.read(pushServiceProvider).start()); // optional; never blocks or fails sign-in
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

  /// Keeps the account's language (used for push texts) in step with the app. Best effort.
  Future<void> syncLanguage() async {
    final u = state.user;
    final lang = effectiveLanguage(ref.read(localeProvider));
    if (state.status != AuthStatus.signedIn || u == null || u.locale == lang) return;
    try { state = AuthState(AuthStatus.signedIn, User.fromJson(await _api.patch('/users/me', body: {'locale': lang}))); } catch (_) {}
  }

  Future<void> refreshUser() async { if (state.status == AuthStatus.signedIn) state = AuthState(AuthStatus.signedIn, User.fromJson(await _api.get('/users/me'))); }

  Future<void> logout() async {
    await ref.read(pushServiceProvider).stop(); // needs the access token, so it runs before we clear it
    final r = _store.refresh;
    if (r != null) { try { await _api.post('/auth/logout', body: {'refreshToken': r}); } catch (_) {} }
    forceSignedOut();
    await _store.clear();
  }

  /// Permanently deletes the account (Phase 2 API). Throws ApiException (e.g. wrong password).
  /// The caller closes its dialog first, then calls [signOutDeleted]: signing out navigates to the login screen.
  Future<void> deleteAccount({String? password}) => _api.delete('/users/me', body: {'confirm': 'DELETE', 'password': ?password});

  /// Local sign-out after the account was deleted (its sessions are already revoked on the server).
  Future<void> signOutDeleted() async { forceSignedOut(); await _store.clear(); }

  void forceSignedOut() { unawaited(ref.read(pushServiceProvider).stop()); ref.read(socketProvider).disconnect(); state = const AuthState(AuthStatus.signedOut); }
}
final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
