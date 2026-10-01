import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/network/api_client.dart';

/// Staff sign-in for the admin panel. It uses the normal login API; only accounts the server accepts at
/// GET /admin/session (moderator and above) get in.

class StaffSession {
  StaffSession.fromJson(Map<String, dynamic> j)
      : id = j['id'], username = j['username'], displayName = j['display_name'] ?? j['username'], role = j['role'],
        canActOnUsers = j['permissions']?['user_actions'] == true, canSeeAudit = j['permissions']?['audit_log'] == true;
  final int id;
  final String username, displayName, role;
  /// Suspend, ban and reinstate accounts (admins).
  final bool canActOnUsers;
  /// The moderator audit log (admins).
  final bool canSeeAudit;
}

enum AdminStatus { loading, signedOut, signedIn }

class AdminAuth {
  const AdminAuth(this.status, {this.session, this.message});
  final AdminStatus status;
  final StaffSession? session;
  /// Why the user is on the sign-in screen (no access, session ended…), if not by choice.
  final String? message;
}

const noAccessMessage = 'This account does not have moderation access.';

final adminStoreProvider = Provider<TokenStore>((_) => TokenStore());
/// Small panel preferences (the newest report already seen).
final adminPrefsProvider = Provider<FlutterSecureStorage>((_) => const FlutterSecureStorage());
/// How often the panel checks for new reports.
final adminPollIntervalProvider = Provider<Duration>((_) => const Duration(seconds: 30));
final adminApiProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(adminStoreProvider), onSignedOut: () => ref.read(adminAuthProvider.notifier).expired()));

class AdminAuthController extends Notifier<AdminAuth> {
  @override
  AdminAuth build() => const AdminAuth(AdminStatus.loading);

  ApiClient get _api => ref.read(adminApiProvider);
  TokenStore get _store => ref.read(adminStoreProvider);

  Future<void> restore() async {
    await _store.load();
    if (_store.refresh == null) { state = const AdminAuth(AdminStatus.signedOut); return; }
    await _enter();
  }

  Future<void> _enter() async {
    try {
      final s = StaffSession.fromJson(await _api.get('/admin/session'));
      if (ref.mounted) state = AdminAuth(AdminStatus.signedIn, session: s);
    } on ApiException catch (e) {
      if (e.status == 403) { await _revoke(); if (ref.mounted) state = const AdminAuth(AdminStatus.signedOut, message: noAccessMessage); return; }
      if (e.status == 401) await _store.clear();
      if (ref.mounted) state = AdminAuth(AdminStatus.signedOut, message: e.status == 401 ? null : e.message);
    }
  }

  Future<String?> _finish(dynamic r) async {
    if (r['requires_2fa'] == true) return r['challenge_token'] as String;
    await _store.save(r['accessToken'], r['refreshToken']);
    await _enter();
    return null;
  }

  /// Signs in. Returns a 2FA challenge token when a code is needed. Throws ApiException (wrong password…).
  Future<String?> login(String identifier, String password) async => _finish(await _api.post('/auth/login', body: {'identifier': identifier, 'password': password}));
  Future<void> verify2fa(String challenge, String code) async { await _finish(await _api.post('/auth/2fa/verify', body: {'challenge_token': challenge, 'code': code})); }

  Future<void> _revoke() async {
    final r = _store.refresh;
    if (r != null) { try { await _api.post('/auth/logout', body: {'refreshToken': r}); } catch (_) {} }
    await _store.clear();
  }

  Future<void> logout() async { await _revoke(); if (ref.mounted) state = const AdminAuth(AdminStatus.signedOut); }

  /// The refresh token was rejected (signed out elsewhere, account suspended…).
  void expired() { if (state.status == AdminStatus.signedIn) state = const AdminAuth(AdminStatus.signedOut, message: 'Your session has ended. Please sign in again.'); }
}
final adminAuthProvider = NotifierProvider<AdminAuthController, AdminAuth>(AdminAuthController.new);
