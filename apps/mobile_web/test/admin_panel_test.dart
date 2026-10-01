import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeyabo/admin/admin_app.dart';
import 'package:jeyabo/admin/admin_session.dart';
import 'package:jeyabo/core/network/api_client.dart';
import 'support.dart';

typedef _Reply = ({int status, Object body});

const _modSession = {'id': 2, 'username': 'mia', 'display_name': 'Mia Mod', 'role': 'moderator', 'permissions': {'user_actions': false, 'audit_log': false}};
const _adminSession = {'id': 3, 'username': 'ali', 'display_name': 'Ali Admin', 'role': 'admin', 'permissions': {'user_actions': true, 'audit_log': true}};
const _ann = {'id': 7, 'username': 'ann', 'display_name': 'Ann Lee', 'role': 'user', 'status': 'active'};
const _bob = {'id': 8, 'username': 'bob', 'display_name': 'Bob Reporter', 'role': 'user', 'status': 'active'};

Map<String, dynamic> _summary({int newSince = 0, int latest = 40}) => {'open': 5, 'reviewing': 1, 'handled_24h': 9, 'suspended': 2, 'banned': 1, 'by_type': {'post': 3, 'comment': 2, 'user': 1}, 'latest_id': latest, 'new_since': newSince};

Map<String, dynamic> _report({int id = 40, String status = 'open', String type = 'post', Map? reviewer}) => {
  'id': id, 'status': status, 'target_type': type, 'target_id': 11, 'reason': 'spam', 'details': 'link farm', 'created_at': 1790727815000,
  'reporter': _bob, 'reviewer': reviewer, 'handler': null, 'resolution': null, 'note': null,
  'target': type == 'user' ? {'exists': true, 'removed': false, 'author': _ann} : {'exists': true, 'removed': false, 'excerpt': 'buy cheap followers', 'author': _ann},
  'content': type == 'user' ? {..._ann, 'created_at': 1790727815000, 'followers_count': 3} : {'id': 11, 'type': 'text', 'body': 'buy cheap followers', 'status': 'published', 'created_at': 1790727815000, 'author': _ann},
  'related': [{'id': 39, 'status': 'open', 'reason': 'other', 'reporter': _bob, 'created_at': 1790727815000}],
  'history': [{'id': 1, 'action': 'report.review', 'actor': _modSession, 'created_at': 1790727815000, 'meta': null}],
};

/// Fake server: answers from [routes] ("METHOD /path"), records every request.
class _Server {
  _Server(this.routes, {this.store}) {
    client = fakeApi((o) {
      sent.add(o);
      final h = routes['${o.method} ${o.path}'];
      return h == null ? (status: 404, body: {'error': {'code': 'NOT_FOUND', 'message': 'no route ${o.method} ${o.path}'}}) : h(o);
    }, store: store, onSignedOut: () => onSignedOut?.call());
  }
  final Map<String, _Reply Function(RequestOptions)> routes;
  final TokenStore? store;
  final sent = <RequestOptions>[];
  late final ApiClient client;
  void Function()? onSignedOut;
  RequestOptions last(String method, String path) => sent.lastWhere((o) => o.method == method && o.path == path);
  bool called(String method, String path) => sent.any((o) => o.method == method && o.path == path);
}

_Reply _ok(Object body) => (status: 200, body: body);
_Reply _page(List rows) => _ok({'data': rows, 'next_cursor': null});

Map<String, _Reply Function(RequestOptions)> _staffRoutes({Map session = _modSession, int newSince = 0}) => {
  'GET /admin/session': (_) => _ok(session),
  'GET /admin/moderation/summary': (_) => _ok(_summary(newSince: newSince)),
  'GET /admin/reports': (_) => _page([_report(), _report(id: 41, type: 'user')]),
  'GET /admin/reports/40': (_) => _ok(_report()),
};

/// Signed-in panel (tokens already stored) or the sign-in screen (no tokens).
Future<(_Server, MemStorage)> _pump(WidgetTester t, Map<String, _Reply Function(RequestOptions)> routes, {bool signedIn = true, Size size = const Size(1400, 900), Duration poll = const Duration(minutes: 5)}) async {
  t.view.physicalSize = size; t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final tokenStorage = MemStorage(); final prefs = MemStorage();
  if (signedIn) { tokenStorage.m['access'] = 'a'; tokenStorage.m['refresh'] = 'r' * 40; }
  final store = TokenStore(tokenStorage);
  final server = _Server(routes, store: store);
  final container = ProviderContainer(overrides: [
    adminStoreProvider.overrideWithValue(store), adminApiProvider.overrideWithValue(server.client),
    adminPrefsProvider.overrideWithValue(prefs), adminPollIntervalProvider.overrideWithValue(poll),
  ]);
  addTearDown(container.dispose);
  server.onSignedOut = () => container.read(adminAuthProvider.notifier).expired();
  await t.pumpWidget(UncontrolledProviderScope(container: container, child: const AdminApp()));
  await t.pumpAndSettle();
  return (server, prefs);
}

void main() {
  group('sign-in', () {
    testWidgets('a member account is refused: message shown, its session is ended', (t) async {
      final (s, _) = await _pump(t, {
        'POST /auth/login': (_) => _ok({'accessToken': 'a', 'refreshToken': 'r' * 40, 'user': _ann}),
        'GET /admin/session': (_) => (status: 403, body: {'error': {'code': 'FORBIDDEN', 'message': 'Insufficient role'}}),
        'POST /auth/logout': (_) => (status: 204, body: {}),
      }, signedIn: false);
      expect(find.text('Jeyabo Admin'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'E-mail or username'), 'ann');
      await t.enterText(find.widgetWithText(TextField, 'Password'), 'password123');
      await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await t.pumpAndSettle();
      expect(s.last('POST', '/auth/login').data, {'identifier': 'ann', 'password': 'password123'});
      expect(find.text(noAccessMessage), findsOneWidget);
      expect(s.called('POST', '/auth/logout'), isTrue);
      expect(s.store!.access, isNull);
    });

    testWidgets('wrong password: the server message stays on the form', (t) async {
      await _pump(t, {'POST /auth/login': (_) => (status: 401, body: {'error': {'code': 'UNAUTHORIZED', 'message': 'Invalid credentials'}})}, signedIn: false);
      await t.enterText(find.widgetWithText(TextField, 'E-mail or username'), 'mia');
      await t.enterText(find.widgetWithText(TextField, 'Password'), 'nope');
      await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await t.pumpAndSettle();
      expect(find.text('Invalid credentials'), findsOneWidget);
    });

    testWidgets('staff with 2FA: code step, then the dashboard', (t) async {
      final (s, _) = await _pump(t, {
        ..._staffRoutes(),
        'POST /auth/login': (_) => _ok({'requires_2fa': true, 'challenge_token': 'c' * 30}),
        'POST /auth/2fa/verify': (_) => _ok({'accessToken': 'a', 'refreshToken': 'r' * 40, 'user': _modSession}),
      }, signedIn: false);
      await t.enterText(find.widgetWithText(TextField, 'E-mail or username'), 'mia');
      await t.enterText(find.widgetWithText(TextField, 'Password'), 'password123');
      await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, 'Two-factor code'), '123456');
      await t.tap(find.widgetWithText(FilledButton, 'Verify'));
      await t.pumpAndSettle();
      expect(s.last('POST', '/auth/2fa/verify').data, {'challenge_token': 'c' * 30, 'code': '123456'});
      expect(find.text('Open reports'), findsOneWidget);
      expect(find.text('Mia Mod · moderator'), findsOneWidget);
    });

    testWidgets('sign out returns to the sign-in screen', (t) async {
      final (s, _) = await _pump(t, {..._staffRoutes(), 'POST /auth/logout': (_) => (status: 204, body: {})});
      await t.tap(find.byTooltip('Sign out'));
      await t.pumpAndSettle();
      expect(s.called('POST', '/auth/logout'), isTrue);
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    });
  });

  group('dashboard and navigation', () {
    testWidgets('counters; moderators have no audit log, admins do', (t) async {
      await _pump(t, _staffRoutes());
      expect(find.text('Dashboard'), findsWidgets);
      for (final label in ['Open reports', 'Under review', 'Handled (24 h)', 'Post reports', 'Comment reports', 'User reports', 'Suspended', 'Banned']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('9'), findsOneWidget); // handled in 24 h
      expect(find.text('Audit log'), findsNothing);
    });

    testWidgets('admins see the audit log', (t) async {
      await _pump(t, _staffRoutes(session: _adminSession));
      expect(find.text('Audit log'), findsOneWidget);
    });

    testWidgets('narrow window: sections are in a drawer', (t) async {
      await _pump(t, _staffRoutes(), size: const Size(700, 900));
      expect(find.byType(NavigationRail), findsNothing);
      await t.tap(find.byTooltip('Open navigation menu'));
      await t.pumpAndSettle();
      await t.tap(find.text('Users'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Users'), findsOneWidget);
    });
  });

  group('new report indicator', () {
    testWidgets('badge with the unseen count; opening the queue marks them seen', (t) async {
      final (s, prefs) = await _pump(t, _staffRoutes(newSince: 3));
      expect(s.last('GET', '/admin/moderation/summary').queryParameters['since_id'], 0);
      expect(find.text('3'), findsWidgets); // top bar bell + Reports in the sidebar
      expect(find.byTooltip('3 new reports'), findsOneWidget);
      expect(find.textContaining('3 new reports since you last opened the queue'), findsOneWidget);
      await t.tap(find.byTooltip('3 new reports'));
      await t.pumpAndSettle();
      expect(prefs.m['admin_seen_report'], '40');
      expect(find.byTooltip('No new reports'), findsOneWidget);
    });

    testWidgets('a report arriving while the panel is open: badge and a "View" notice', (t) async {
      var newSince = 0;
      final (s, _) = await _pump(t, {..._staffRoutes(), 'GET /admin/moderation/summary': (_) => _ok(_summary(newSince: newSince, latest: 40 + newSince))}, poll: const Duration(seconds: 30));
      expect(find.byTooltip('No new reports'), findsOneWidget);
      newSince = 2;
      await t.pump(const Duration(seconds: 30));
      await t.pumpAndSettle();
      expect(find.text('2 new reports'), findsOneWidget); // snack bar
      expect(find.byTooltip('2 new reports'), findsOneWidget);
      await t.tap(find.text('View'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Reports'), findsOneWidget);
      expect(s.called('GET', '/admin/reports'), isTrue);
    });

    testWidgets('remembers what was seen: the next session asks only for newer reports', (t) async {
      final tokenStorage = MemStorage()..m.addAll({'access': 'a', 'refresh': 'r' * 40});
      final prefs = MemStorage()..m['admin_seen_report'] = '37';
      final store = TokenStore(tokenStorage);
      final s = _Server(_staffRoutes(), store: store);
      t.view.physicalSize = const Size(1400, 900); t.view.devicePixelRatio = 1; addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(overrides: [adminStoreProvider.overrideWithValue(store), adminApiProvider.overrideWithValue(s.client), adminPrefsProvider.overrideWithValue(prefs)], child: const AdminApp()));
      await t.pumpAndSettle();
      expect(s.last('GET', '/admin/moderation/summary').queryParameters['since_id'], 37);
    });
  });

  group('reports queue', () {
    Future<_Server> openQueue(WidgetTester t, {Map session = _modSession}) async {
      final (s, _) = await _pump(t, _staffRoutes(session: session));
      await t.tap(find.text('Reports').first);
      await t.pumpAndSettle();
      return s;
    }

    testWidgets('lists post and user reports with reason, reporter and status; filters change the query', (t) async {
      final s = await openQueue(t);
      expect(find.text('buy cheap followers'), findsOneWidget);
      expect(find.text('Ann Lee @ann'), findsOneWidget); // the user report
      expect(find.textContaining('#40 · Spam · by Ann Lee · reported by Bob Reporter'), findsOneWidget);
      expect(s.last('GET', '/admin/reports').queryParameters, {'status': 'open'});
      await t.tap(find.text('Under review'));
      await t.pumpAndSettle();
      expect(s.last('GET', '/admin/reports').queryParameters, {'status': 'reviewing'});
      await t.tap(find.text('All types'));
      await t.pumpAndSettle();
      await t.tap(find.text('Comment reports').last);
      await t.pumpAndSettle();
      expect(s.last('GET', '/admin/reports').queryParameters, {'status': 'reviewing', 'target_type': 'comment'});
    });

    testWidgets('report details: content, reporter, related reports and history', (t) async {
      await openQueue(t);
      await t.tap(find.text('buy cheap followers'));
      await t.pumpAndSettle();
      expect(find.text('Report #40'), findsOneWidget);
      expect(find.text('buy cheap followers'), findsOneWidget);
      expect(find.text('link farm'), findsOneWidget);
      expect(find.text('Bob Reporter @bob'), findsOneWidget);
      expect(find.text('Other reports on this post (1)'), findsOneWidget);
      expect(find.text('#39 · Other'), findsOneWidget);
      expect(find.text('Took a report for review'), findsOneWidget);
    });

    testWidgets('mark under review, then resolve by removing the post (moderator: no account actions)', (t) async {
      var status = 'open';
      final (s, _) = await _pump(t, {
        ..._staffRoutes(),
        'GET /admin/reports/40': (_) => _ok(_report(status: status, reviewer: status == 'reviewing' ? _modSession : null)),
        'POST /admin/reports/40/review': (_) { status = 'reviewing'; return _ok({'id': 40, 'status': 'reviewing'}); },
        'POST /admin/reports/40/resolve': (_) { status = 'actioned'; return _ok({'id': 40, 'status': 'actioned', 'resolution': 'content_removed', 'closed_related': 1}); },
      });
      await t.tap(find.text('Reports').first); await t.pumpAndSettle();
      await t.tap(find.text('buy cheap followers')); await t.pumpAndSettle();
      await t.tap(find.text('Mark under review')); await t.pumpAndSettle();
      expect(s.called('POST', '/admin/reports/40/review'), isTrue);
      expect(find.text('You are reviewing this report.'), findsOneWidget);
      expect(find.text('Mark under review'), findsNothing);

      await t.tap(find.text('Resolve…')); await t.pumpAndSettle();
      expect(find.text('Remove this post'), findsOneWidget);
      expect(find.text('Ban'), findsNothing); // moderators cannot act on accounts
      expect(t.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isTrue);
      await t.enterText(find.widgetWithText(TextField, 'Note for the audit log (optional)'), 'commercial spam');
      await t.tap(find.widgetWithText(FilledButton, 'Resolve')); await t.pumpAndSettle();
      expect(s.last('POST', '/admin/reports/40/resolve').data, {'remove_content': true, 'user_action': 'none', 'note': 'commercial spam'});
      expect(find.text('Content removed'), findsOneWidget); // notice
      expect(find.text('This report is closed.'), findsOneWidget);

      // Back to the queue: it reloads and the counters refresh.
      final before = s.sent.where((o) => o.path == '/admin/moderation/summary').length;
      await t.tap(find.byTooltip('Back')); await t.pumpAndSettle();
      expect(s.sent.where((o) => o.path == '/admin/moderation/summary').length, before + 1);
    });

    testWidgets('admin resolves a user report by banning the account', (t) async {
      final (s, _) = await _pump(t, {
        ..._staffRoutes(session: _adminSession),
        'GET /admin/reports/41': (_) => _ok(_report(id: 41, type: 'user')),
        'POST /admin/reports/41/resolve': (_) => _ok({'id': 41, 'status': 'actioned', 'resolution': 'user_banned', 'closed_related': 0}),
      });
      await t.tap(find.text('Reports').first); await t.pumpAndSettle();
      await t.tap(find.text('Ann Lee @ann')); await t.pumpAndSettle();
      await t.tap(find.text('Resolve…')); await t.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNothing); // accounts are not "removed": suspend or ban
      await t.tap(find.text('Ban')); await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Resolve')); await t.pumpAndSettle();
      expect(s.last('POST', '/admin/reports/41/resolve').data, {'remove_content': false, 'user_action': 'ban'});
      expect(find.text('Account banned'), findsOneWidget);
    });

    testWidgets('reject with a note; errors from the server are shown', (t) async {
      var fail = true;
      final (s, _) = await _pump(t, {
        ..._staffRoutes(),
        'POST /admin/reports/40/reject': (_) => fail ? (status: 409, body: {'error': {'code': 'CONFLICT', 'message': 'This report is already closed'}}) : _ok({'id': 40, 'status': 'dismissed'}),
      });
      await t.tap(find.text('Reports').first); await t.pumpAndSettle();
      await t.tap(find.text('buy cheap followers')); await t.pumpAndSettle();
      await t.tap(find.widgetWithText(OutlinedButton, 'Reject')); await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, 'satire, allowed');
      await t.tap(find.widgetWithText(FilledButton, 'Reject report')); await t.pumpAndSettle();
      expect(find.text('This report is already closed'), findsOneWidget);
      fail = false;
      await t.tap(find.widgetWithText(OutlinedButton, 'Reject')); await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Reject report')); await t.pumpAndSettle();
      expect(s.last('POST', '/admin/reports/40/reject').data, <String, dynamic>{});
      expect(find.text('Report rejected'), findsOneWidget);
    });
  });

  group('users and audit log', () {
    final member = {..._ann, 'email': 'ann@x.dev', 'created_at': 1790727815000, 'open_reports': 2, 'is_verified': false};
    Map<String, dynamic> detail(String status) => {...member, 'status': status, 'stats': {'posts': 4, 'removed_posts': 1, 'reports': 2, 'upheld_reports': 1},
      'reports': [_report()], 'history': [{'id': 9, 'action': 'user.suspend', 'actor': _adminSession, 'created_at': 1790727815000, 'meta': {'reason': 'cooling off'}}]};

    testWidgets('search sends the query; admin suspends with a reason; history is listed', (t) async {
      var status = 'active';
      final (s, _) = await _pump(t, {
        ..._staffRoutes(session: _adminSession),
        'GET /admin/users': (_) => _page([member]),
        'GET /admin/users/7': (_) => _ok(detail(status)),
        'POST /admin/users/7/suspend': (_) { status = 'suspended'; return _ok({'id': 7, 'status': 'suspended'}); },
      });
      await t.tap(find.text('Users').first); await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '@ann');
      await t.pump(const Duration(milliseconds: 400)); await t.pumpAndSettle();
      expect(s.last('GET', '/admin/users').queryParameters, {'q': '@ann'});
      expect(find.text('2 open reports'), findsOneWidget);
      await t.tap(find.text('Ann Lee  @ann')); await t.pumpAndSettle();
      expect(find.text('ann@x.dev'), findsOneWidget);
      expect(find.text('4 (1 removed)'), findsOneWidget);
      expect(find.text('Suspended an account'), findsOneWidget);
      expect(find.textContaining('cooling off'), findsOneWidget);
      await t.tap(find.widgetWithText(OutlinedButton, 'Suspend')); await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, 'Reason (kept in the audit log)'), 'spam wave');
      await t.tap(find.widgetWithText(FilledButton, 'Suspend account')); await t.pumpAndSettle();
      expect(s.last('POST', '/admin/users/7/suspend').data, {'reason': 'spam wave'});
      expect(find.text('Account suspended'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Reinstate'), findsOneWidget);
    });

    testWidgets('moderators see history but no account actions', (t) async {
      await _pump(t, {..._staffRoutes(), 'GET /admin/users': (_) => _page([member]), 'GET /admin/users/7': (_) => _ok(detail('active'))});
      await t.tap(find.text('Users').first); await t.pumpAndSettle();
      await t.tap(find.text('Ann Lee  @ann')); await t.pumpAndSettle();
      expect(find.text('Moderation history'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Suspend'), findsNothing);
      expect(find.text('Ban'), findsNothing);
    });

    testWidgets('audit log: who did what; filter by kind; open the account', (t) async {
      final (s, _) = await _pump(t, {
        ..._staffRoutes(session: _adminSession),
        'GET /admin/audit': (_) => _page([
          {'id': 5, 'action': 'user.ban', 'target': 'user:7', 'actor': _adminSession, 'created_at': 1790727815000, 'meta': {'reason': 'threats'}},
          {'id': 4, 'action': 'report.resolve', 'target': 'report:40', 'actor': _modSession, 'created_at': 1790727815000, 'meta': {'resolution': 'content_removed'}},
        ]),
        'GET /admin/users/7': (_) => _ok(detail('banned')),
      });
      await t.tap(find.text('Audit log')); await t.pumpAndSettle();
      expect(find.text('Ali Admin — Banned an account'), findsOneWidget);
      expect(find.text('Mia Mod — Resolved a report'), findsOneWidget);
      expect(find.textContaining('Content removed'), findsOneWidget);
      await t.tap(find.text('Accounts')); await t.pumpAndSettle();
      expect(s.last('GET', '/admin/audit').queryParameters, {'action': 'user.', 'limit': 50});
      await t.tap(find.text('Ali Admin — Banned an account')); await t.pumpAndSettle();
      expect(find.text('Ann Lee  @ann'), findsOneWidget); // member page title
    });
  });

  testWidgets('session ended elsewhere: back to sign-in with a message', (t) async {
    final (s, _) = await _pump(t, {
      ..._staffRoutes(),
      'GET /admin/reports': (_) => (status: 401, body: {'error': {'code': 'UNAUTHORIZED', 'message': 'Invalid or expired token'}}),
      'POST /auth/refresh': (_) => (status: 401, body: {'error': {'code': 'UNAUTHORIZED', 'message': 'Invalid refresh token'}}),
    });
    await t.tap(find.text('Reports').first);
    await t.pumpAndSettle();
    expect(s.called('POST', '/auth/refresh'), isTrue);
    expect(find.text('Your session has ended. Please sign in again.'), findsOneWidget);
  });
}
