import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeyabo/core/l10n.dart';
import 'package:jeyabo/core/models.dart';
import 'package:jeyabo/core/network/api_client.dart';
import 'package:jeyabo/core/providers.dart';
import 'package:jeyabo/core/theme/theme.dart';
import 'package:jeyabo/features/profile/profile_screens.dart';
import 'support.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _me = 1, _other = 7;
User _meUser({bool hasPassword = true}) => User(id: _me, username: 'me', displayName: 'Me Myself', hasPassword: hasPassword);

/// Like the device keychain/keystore: clearing takes a moment (frames run meanwhile).
class _SlowStorage extends MemStorage {
  @override
  Future<void> delete({required String key, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await super.delete(key: key);
  }
}

class _SignedIn extends AuthController {
  _SignedIn(this.u); final User u;
  @override
  AuthState build() => AuthState(AuthStatus.signedIn, u);
}

/// Records every request as (method, path, body) and answers from [routes] ("METHOD /path"), else 200 {}.
class Api {
  Api([this.routes = const {}]) { client = fakeApi((o) { sent.add((o.method, o.path, o.data)); return routes['${o.method} ${o.path}']?.call(o) ?? (status: 200, body: {}); }); }
  final Map<String, ({int status, Object body}) Function(RequestOptions)> routes;
  final sent = <(String, String, Object?)>[];
  late final ApiClient client;
  Object? bodyOf(String method, String path) => sent.lastWhere((r) => r.$1 == method && r.$2 == path).$3;
  bool called(String method, String path) => sent.any((r) => r.$1 == method && r.$2 == path);
}

Widget _host(Api api, Widget home, {User? me, Locale? locale}) => ProviderScope(
      overrides: [apiProvider.overrideWithValue(api.client), tokenStoreProvider.overrideWithValue(api.client.tokens), authProvider.overrideWith(() => _SignedIn(me ?? _meUser()))],
      child: MaterialApp(theme: buildTheme(Brightness.light), locale: locale, localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: home),
    );

final _otherProfile = {'id': _other, 'username': 'ann', 'display_name': 'Ann Lee', 'followers_count': 3, 'following_count': 1};

/// Profile pushed over a placeholder page, so "go back after blocking" can be observed.
Widget _profileOverHome() => Builder(builder: (c) => Scaffold(body: Center(child: TextButton(
      onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => const UserProfileScreen(id: _other))), child: const Text('open profile')))));

Future<void> _openProfile(WidgetTester t, Api api) async {
  await t.pumpWidget(_host(api, _profileOverHome()));
  await t.tap(find.text('open profile'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('report: a reason is required; the report is sent with reason and details', (t) async {
    final api = Api({'GET /users/$_other': (_) => (status: 200, body: _otherProfile), 'POST /reports': (_) => (status: 201, body: {'id': 1})});
    await _openProfile(t, api);
    await t.tap(find.byTooltip('More options'));
    await t.pumpAndSettle();
    await t.tap(find.text('Report'));
    await t.pumpAndSettle();
    expect(find.text('Report Ann Lee'), findsOneWidget);
    final send = find.widgetWithText(FilledButton, 'Send report');
    expect(t.widget<FilledButton>(send).onPressed, isNull); // no reason yet
    await t.tap(find.text('Harassment or bullying'));
    await t.enterText(find.byType(TextField), 'abusive DMs');
    await t.pump();
    await t.tap(send);
    await t.pumpAndSettle();
    expect(api.bodyOf('POST', '/reports'), {'target_type': 'user', 'target_id': _other, 'reason': 'harassment', 'details': 'abusive DMs'});
    expect(find.text('Thanks for telling us. Our team will review it.'), findsOneWidget);
    expect(find.byType(UserProfileScreen), findsOneWidget); // reporting does not leave the profile
  });

  testWidgets('report: a server refusal (already reported) is shown in the dialog', (t) async {
    final api = Api({'GET /users/$_other': (_) => (status: 200, body: _otherProfile), 'POST /reports': (_) => (status: 409, body: {'error': {'code': 'CONFLICT', 'message': 'You already reported this'}})});
    await _openProfile(t, api);
    await t.tap(find.byTooltip('More options')); await t.pumpAndSettle();
    await t.tap(find.text('Report')); await t.pumpAndSettle();
    await t.tap(find.text('Spam')); await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'Send report')); await t.pumpAndSettle();
    expect(find.text('You already reported this'), findsOneWidget);
    expect(find.text('Report Ann Lee'), findsOneWidget); // still open, can cancel
  });

  testWidgets('block: confirm, call the API, then leave the hidden profile; cancel does nothing', (t) async {
    final api = Api({'GET /users/$_other': (_) => (status: 200, body: _otherProfile), 'POST /users/$_other/block': (_) => (status: 204, body: '')});
    await _openProfile(t, api);
    await t.tap(find.byTooltip('More options')); await t.pumpAndSettle();
    await t.tap(find.text('Block')); await t.pumpAndSettle();
    expect(find.text('Block Ann Lee?'), findsOneWidget);
    await t.tap(find.text('Cancel')); await t.pumpAndSettle();
    expect(api.called('POST', '/users/$_other/block'), isFalse);
    await t.tap(find.byTooltip('More options')); await t.pumpAndSettle();
    await t.tap(find.text('Block')); await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Block')); await t.pumpAndSettle();
    expect(api.called('POST', '/users/$_other/block'), isTrue);
    expect(find.byType(UserProfileScreen), findsNothing);
    expect(find.text('Ann Lee is blocked'), findsOneWidget);
  });

  testWidgets('no safety menu on your own profile', (t) async {
    final api = Api({'GET /users/$_me': (_) => (status: 200, body: {'id': _me, 'username': 'me', 'display_name': 'Me Myself'})});
    await t.pumpWidget(_host(api, const UserProfileScreen(id: _me)));
    await t.pumpAndSettle();
    expect(find.byTooltip('More options'), findsNothing);
  });

  testWidgets('blocked accounts: listed from the API and can be unblocked', (t) async {
    final api = Api({
      'GET /users/me/blocks': (_) => (status: 200, body: {'data': [{'id': _other, 'username': 'ann', 'display_name': 'Ann Lee'}]}),
      'DELETE /users/$_other/block': (_) => (status: 204, body: ''),
      'GET /luckydraw/campaigns': (_) => (status: 404, body: {'error': {'code': 'NOT_FOUND', 'message': 'Route not found'}}),
    });
    await t.pumpWidget(_host(api, const MyProfileScreen()));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Blocked accounts'), 200);
    await t.tap(find.text('Blocked accounts'));
    await t.pumpAndSettle();
    expect(find.text('Ann Lee'), findsOneWidget);
    await t.tap(find.widgetWithText(OutlinedButton, 'Unblock'));
    await t.pumpAndSettle();
    expect(api.called('DELETE', '/users/$_other/block'), isTrue);
    expect(find.text("You haven't blocked anyone."), findsOneWidget);
  });

  group('delete account', () {
    Future<void> openDialog(WidgetTester t, Api api, {User? me, Locale? locale}) async {
      await t.pumpWidget(_host(api, const Scaffold(body: MyProfileScreen()), me: me, locale: locale)); // the app shows the login Scaffold after sign-out
      await t.pumpAndSettle();
      final del = find.widgetWithText(TextButton, locale?.languageCode == 'ar' ? 'حذف الحساب' : 'Delete account');
      await t.scrollUntilVisible(del, 200);
      await t.tap(del);
      await t.pumpAndSettle();
    }
    final lucky = {'GET /luckydraw/campaigns': (RequestOptions _) => (status: 404, body: <String, Object>{'error': {'code': 'NOT_FOUND', 'message': 'x'}})};

    testWidgets('password account: needs the password and DELETE typed, then signs out', (t) async {
      final api = Api({...lucky, 'DELETE /users/me': (_) => (status: 204, body: '')});
      await openDialog(t, api);
      expect(find.text('Delete your account?'), findsOneWidget);
      final go = find.widgetWithText(FilledButton, 'Delete forever');
      expect(t.widget<FilledButton>(go).onPressed, isNull);
      await t.enterText(find.widgetWithText(TextField, 'Type \u2068DELETE\u2069 to confirm'), 'DELETE');
      await t.pump();
      expect(t.widget<FilledButton>(go).onPressed, isNull); // password still missing
      await t.enterText(find.widgetWithText(TextField, 'Password'), 'password123');
      await t.pump();
      await t.tap(go);
      await t.pumpAndSettle();
      expect(api.bodyOf('DELETE', '/users/me'), {'confirm': 'DELETE', 'password': 'password123'});
      final container = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
      expect(container.read(authProvider).status, AuthStatus.signedOut);
      expect(find.text('Your account has been deleted.'), findsOneWidget);
    });

    testWidgets('wrong password: the server message is shown and you stay signed in', (t) async {
      final api = Api({...lucky, 'DELETE /users/me': (_) => (status: 401, body: {'error': {'code': 'UNAUTHORIZED', 'message': 'Invalid credentials'}})});
      await openDialog(t, api);
      await t.enterText(find.widgetWithText(TextField, 'Password'), 'nope');
      await t.enterText(find.widgetWithText(TextField, 'Type \u2068DELETE\u2069 to confirm'), 'DELETE');
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Delete forever'));
      await t.pumpAndSettle();
      expect(find.text('Invalid credentials'), findsOneWidget);
      final container = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
      expect(container.read(authProvider).status, AuthStatus.signedIn);
    });

    testWidgets('phone/Google account: no password field; Arabic dialog is right-to-left', (t) async {
      final api = Api({...lucky, 'DELETE /users/me': (_) => (status: 204, body: '')});
      await openDialog(t, api, me: _meUser(hasPassword: false), locale: const Locale('ar'));
      expect(find.text('حذف حسابك؟'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'كلمة المرور'), findsNothing);
      expect(Directionality.of(t.element(find.text('حذف حسابك؟'))), TextDirection.rtl);
      await t.enterText(find.byType(TextField), 'DELETE');
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'حذف نهائي'));
      await t.pumpAndSettle();
      expect(api.bodyOf('DELETE', '/users/me'), {'confirm': 'DELETE'});
    });
  });

  testWidgets('delete account under the app router lands on the login screen (never a blank screen)', (t) async {
    final api = Api({'DELETE /users/me': (_) => (status: 204, body: ''), 'GET /luckydraw/campaigns': (_) => (status: 404, body: {'error': {'code': 'NOT_FOUND', 'message': 'x'}})});
    final container = ProviderContainer(overrides: [apiProvider.overrideWithValue(api.client), tokenStoreProvider.overrideWithValue(TokenStore(_SlowStorage())), authProvider.overrideWith(() => _SignedIn(_meUser(hasPassword: false)))]);
    addTearDown(container.dispose);
    final refresh = ValueNotifier(0);
    container.listen(authProvider, (_, _) => refresh.value++);
    // Same shape as the app: signing out redirects to /login.
    final router = GoRouter(refreshListenable: refresh, initialLocation: '/me',
        redirect: (_, s) => container.read(authProvider).status == AuthStatus.signedOut && s.uri.path != '/login' ? '/login' : null,
        routes: [GoRoute(path: '/me', builder: (_, _) => const Scaffold(body: MyProfileScreen())), GoRoute(path: '/login', builder: (_, _) => const Scaffold(body: Text('login page')))]);
    await t.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router, theme: buildTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales)));
    await t.pumpAndSettle();
    final del = find.widgetWithText(TextButton, 'Delete account');
    await t.scrollUntilVisible(del, 200);
    await t.tap(del); await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'DELETE'); await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'Delete forever'));
    await t.pumpAndSettle();
    expect(find.text('login page'), findsOneWidget);
    expect(find.text('Your account has been deleted.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('User.hasPassword reads the API flag (missing = true, the safe default)', () {
    expect(User.fromJson({'id': 1, 'username': 'a', 'has_password': false}).hasPassword, isFalse);
    expect(User.fromJson({'id': 1, 'username': 'a'}).hasPassword, isTrue);
  });
}
