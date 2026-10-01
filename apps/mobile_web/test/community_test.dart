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
import 'package:jeyabo/features/communities/community_screens.dart';
import 'package:jeyabo/features/feed/post_card.dart';
import 'support.dart';

const _me = 1;

class _SignedIn extends AuthController {
  @override
  AuthState build() => AuthState(AuthStatus.signedIn, User(id: _me, username: 'me', displayName: 'Me'));
}

typedef _Reply = ({int status, Object body});

class _Api {
  _Api(this.handle) { client = fakeApi((o) { sent.add((o.method, o.path, o.data, o.queryParameters)); return handle(o) ?? (status: 200, body: {}); }); }
  final _Reply? Function(RequestOptions o) handle;
  final sent = <(String, String, Object?, Map<String, dynamic>)>[];
  late final ApiClient client;
  Iterable<(String, String, Object?, Map<String, dynamic>)> calls(String m, String p) => sent.where((r) => r.$1 == m && r.$2 == p);
}

Map<String, dynamic> _c(int id, String name, {String kind = 'group', String privacy = 'public', int members = 3, String? role, String? status, String? pageType, String? description}) =>
    {'id': id, 'kind': kind, 'privacy': privacy, 'name': name, 'members_count': members, 'my_role': role, 'my_status': status, 'page_type': pageType, 'description': description};
Map<String, dynamic> _post(int id, String body) => {'id': id, 'type': 'text', 'body': body, 'created_at': 1790727815000, 'reactions_count': 0, 'comments_count': 0, 'author': {'id': 9, 'username': 'ann', 'display_name': 'Ann Lee'}};

Future<void> _pump(WidgetTester t, _Api api, String initial, {Locale? locale}) async {
  final router = GoRouter(initialLocation: initial, routes: [
    GoRoute(path: '/groups', builder: (_, _) => const CommunityListScreen(kind: 'group')),
    GoRoute(path: '/pages', builder: (_, _) => const CommunityListScreen(kind: 'page')),
    GoRoute(path: '/community/:id', builder: (_, s) => CommunityDetailScreen(id: int.parse(s.pathParameters['id']!))),
    GoRoute(path: '/user/:id', builder: (_, s) => Scaffold(body: Text('user ${s.pathParameters['id']}'))),
  ]);
  await t.pumpWidget(ProviderScope(
    overrides: [apiProvider.overrideWithValue(api.client), tokenStoreProvider.overrideWithValue(api.client.tokens), authProvider.overrideWith(_SignedIn.new)],
    child: MaterialApp.router(routerConfig: router, theme: buildTheme(Brightness.light), locale: locale, localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales),
  ));
  await t.pumpAndSettle();
}

void main() {
  group('groups list', () {
    testWidgets('shows my groups first, then others (without duplicates); tapping opens the group', (t) async {
      final api = _Api((o) => switch (o.path) {
            '/communities/mine' => (status: 200, body: {'data': [_c(1, 'Runners', role: 'member', status: 'active'), _c(2, 'Book club', privacy: 'private', status: 'pending')]}),
            '/communities' => (status: 200, body: {'data': [_c(1, 'Runners', status: 'active'), _c(3, 'Chess', members: 1200)]}),
            '/communities/3' => (status: 200, body: _c(3, 'Chess', members: 1200)),
            '/communities/3/feed' => (status: 200, body: {'data': [], 'next_cursor': null}),
            _ => null,
          });
      await _pump(t, api, '/groups');
      expect(api.calls('GET', '/communities/mine').single.$4, {'kind': 'group'});
      expect(find.text('Your groups'), findsOneWidget);
      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('Runners'), findsOneWidget); // once: not repeated under Discover
      expect(find.text('Private · 3 members · Requested'), findsOneWidget); // pending request is labelled
      expect(find.text('Public · 1.2K members'), findsOneWidget);
      await t.tap(find.text('Chess'));
      await t.pumpAndSettle();
      expect(find.byType(CommunityDetailScreen), findsOneWidget);
      final before = api.calls('GET', '/communities/mine').length;
      await t.pageBack(); await t.pumpAndSettle();
      expect(api.calls('GET', '/communities/mine').length, before + 1); // list refreshed after visiting (membership may have changed)
    });

    testWidgets('search: debounced, sends the query and kind; empty result explained', (t) async {
      final api = _Api((o) => switch (o.path) {
            '/communities/mine' => (status: 200, body: {'data': []}),
            '/communities' when o.queryParameters['q'] == 'run' => (status: 200, body: {'data': [_c(1, 'Runners')]}),
            '/communities' when o.queryParameters['q'] == 'zzz' => (status: 200, body: {'data': []}),
            '/communities' => (status: 200, body: {'data': []}),
            _ => null,
          });
      await _pump(t, api, '/groups');
      expect(find.text("You haven't joined any groups yet."), findsOneWidget);
      await t.enterText(find.byType(TextField), 'run');
      await t.pump(const Duration(milliseconds: 100));
      expect(api.calls('GET', '/communities').where((c) => c.$4['q'] != null), isEmpty); // still debouncing
      await t.pump(const Duration(milliseconds: 400)); await t.pumpAndSettle();
      expect(api.calls('GET', '/communities').last.$4, {'q': 'run', 'kind': 'group'});
      expect(find.text('Runners'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'zzz');
      await t.pump(const Duration(milliseconds: 400)); await t.pumpAndSettle();
      expect(find.text('No groups found'), findsOneWidget);
    });

    testWidgets('Arabic: translated and right-to-left', (t) async {
      final api = _Api((o) => switch (o.path) { '/communities/mine' || '/communities' => (status: 200, body: {'data': [_c(1, 'نادي القراءة', members: 2)]}), _ => null });
      await _pump(t, api, '/groups', locale: const Locale('ar'));
      expect(find.text('المجموعات'), findsOneWidget);
      expect(find.text('مجموعاتك'), findsOneWidget);
      expect(find.text('عامة · عضوان'), findsOneWidget); // Arabic dual
      expect(Directionality.of(t.element(find.text('مجموعاتك'))), TextDirection.rtl);
    });
  });

  group('create', () {
    testWidgets('group: name validated; private group created and opened', (t) async {
      final api = _Api((o) => switch ((o.method, o.path)) {
            ('GET', '/communities/mine') || ('GET', '/communities') => (status: 200, body: {'data': []}),
            ('POST', '/communities') => (status: 201, body: _c(10, 'Garden friends', privacy: 'private')),
            ('GET', '/communities/10') => (status: 200, body: _c(10, 'Garden friends', privacy: 'private', role: 'owner', status: 'active', members: 1)),
            ('GET', '/communities/10/feed') => (status: 200, body: {'data': [], 'next_cursor': null}),
            _ => null,
          });
      await _pump(t, api, '/groups');
      await t.tap(find.byTooltip('Create group')); await t.pumpAndSettle();
      final create = find.widgetWithText(FilledButton, 'Create');
      expect(t.widget<FilledButton>(create).onPressed, isNull);
      await t.enterText(find.widgetWithText(TextField, 'Group name'), 'G');
      await t.pump();
      expect(find.text('Use at least 2 characters'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'Group name'), 'Garden friends');
      await t.enterText(find.widgetWithText(TextField, 'Description (optional)'), 'We grow things');
      await t.tap(find.text('Private')); await t.pump();
      expect(find.text('Only members see posts. Admins approve new members.'), findsOneWidget);
      await t.tap(create); await t.pumpAndSettle();
      expect(api.calls('POST', '/communities').single.$3, {'kind': 'group', 'name': 'Garden friends', 'description': 'We grow things', 'privacy': 'private'});
      expect(find.byType(CommunityDetailScreen), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Owner'), findsOneWidget); // owners cannot leave
    });

    testWidgets('page: a type must be chosen; sent without privacy', (t) async {
      final api = _Api((o) => switch ((o.method, o.path)) {
            ('GET', '/communities/mine') || ('GET', '/communities') => (status: 200, body: {'data': []}),
            ('POST', '/communities') => (status: 201, body: _c(11, 'Cafe Noor', kind: 'page', pageType: 'business')),
            ('GET', '/communities/11') => (status: 200, body: _c(11, 'Cafe Noor', kind: 'page', pageType: 'business', role: 'owner', status: 'active', members: 1)),
            ('GET', '/communities/11/feed') => (status: 200, body: {'data': [], 'next_cursor': null}),
            _ => null,
          });
      await _pump(t, api, '/pages');
      await t.tap(find.byTooltip('Create page')); await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, 'Page name'), 'Cafe Noor');
      await t.pump();
      expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Create')).onPressed, isNull); // no type yet
      await t.tap(find.text('Business')); await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Create')); await t.pumpAndSettle();
      expect(api.calls('POST', '/communities').single.$3, {'kind': 'page', 'name': 'Cafe Noor', 'page_type': 'business'});
      expect(find.text('Business · 1 follower'), findsOneWidget);
    });

    testWidgets('a server error stays in the sheet', (t) async {
      final api = _Api((o) => switch ((o.method, o.path)) {
            ('GET', _) => (status: 200, body: {'data': []}),
            ('POST', '/communities') => (status: 400, body: {'error': {'code': 'BAD_REQUEST', 'message': 'Validation failed'}}),
            _ => null,
          });
      await _pump(t, api, '/groups');
      await t.tap(find.byTooltip('Create group')); await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, 'Group name'), 'Okay name');
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Create')); await t.pumpAndSettle();
      expect(find.text('Validation failed'), findsOneWidget);
      expect(find.text('Create group'), findsWidgets); // sheet still open
    });
  });

  group('details', () {
    testWidgets('public group: posts use the home feed card; join, then leave', (t) async {
      var status = 'none';
      final api = _Api((o) => switch ((o.method, o.path)) {
            ('GET', '/communities/5') => (status: 200, body: _c(5, 'Runners', description: 'Morning runs', status: status == 'none' ? null : status, role: status == 'none' ? null : 'member')),
            ('GET', '/communities/5/feed') => (status: 200, body: {'data': [_post(1, 'Run at 6?'), _post(2, 'Great pace today')], 'next_cursor': null}),
            ('POST', '/communities/5/join') => (() { status = 'active'; return (status: 201, body: {'status': 'active'}); })(),
            ('POST', '/communities/5/leave') => (() { status = 'none'; return (status: 204, body: ''); })(),
            ('PUT', '/posts/1/reaction') => (status: 200, body: {'kind': 'like', 'reactions_count': 1}),
            _ => null,
          });
      await _pump(t, api, '/community/5');
      expect(find.text('Morning runs'), findsOneWidget);
      expect(find.byType(PostCard), findsNWidgets(2));
      await t.tap(find.widgetWithText(FilledButton, 'Join')); await t.pumpAndSettle();
      expect(api.calls('POST', '/communities/5/join'), hasLength(1));
      await t.tap(find.widgetWithText(OutlinedButton, 'Leave')); await t.pumpAndSettle();
      expect(api.calls('POST', '/communities/5/leave'), hasLength(1));
      expect(find.widgetWithText(FilledButton, 'Join'), findsOneWidget);
      // Reacting on a group post updates this list (the home feed is not involved).
      await t.tap(find.text('0').first); await t.pumpAndSettle();
      expect(api.calls('PUT', '/posts/1/reaction').single.$3, {'kind': 'like'});
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('private group, not a member: locked, no feed request; joining sends a request', (t) async {
      var status = 'none';
      final api = _Api((o) => switch ((o.method, o.path)) {
            ('GET', '/communities/6') => (status: 200, body: _c(6, 'Book club', privacy: 'private', status: status == 'none' ? null : status)),
            ('POST', '/communities/6/join') => (() { status = 'pending'; return (status: 201, body: {'status': 'pending'}); })(),
            _ => null,
          });
      await _pump(t, api, '/community/6');
      expect(find.text('This group is private'), findsOneWidget);
      expect(api.calls('GET', '/communities/6/feed'), isEmpty);
      expect(t.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Members')).onPressed, isNull);
      await t.tap(find.widgetWithText(FilledButton, 'Join')); await t.pumpAndSettle();
      expect(find.text('Request sent. An admin will review it.'), findsOneWidget);
      expect(t.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Requested')).onPressed, isNull);
    });

    testWidgets('page: follow and unfollow', (t) async {
      var following = false;
      final api = _Api((o) => switch ((o.method, o.path)) {
            ('GET', '/communities/7') => (status: 200, body: _c(7, 'Cafe Noor', kind: 'page', pageType: 'business', members: following ? 2 : 1, status: following ? 'active' : null, role: following ? 'member' : null)),
            ('GET', '/communities/7/feed') => (status: 200, body: {'data': [], 'next_cursor': null}),
            ('POST', '/communities/7/join') => (() { following = true; return (status: 201, body: {'status': 'active'}); })(),
            ('POST', '/communities/7/leave') => (() { following = false; return (status: 204, body: ''); })(),
            _ => null,
          });
      await _pump(t, api, '/community/7');
      expect(find.text('No posts yet'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Follow')); await t.pumpAndSettle();
      expect(find.text('Business · 2 followers'), findsOneWidget);
      await t.tap(find.widgetWithText(OutlinedButton, 'Unfollow')); await t.pumpAndSettle();
      expect(api.calls('POST', '/communities/7/leave'), hasLength(1));
      expect(find.widgetWithText(FilledButton, 'Follow'), findsOneWidget);
    });

    testWidgets('members: roles shown; staff can approve a join request', (t) async {
      final api = _Api((o) => switch ((o.method, o.path)) {
            ('GET', '/communities/8') => (status: 200, body: _c(8, 'Book club', privacy: 'private', role: 'owner', status: 'active')),
            ('GET', '/communities/8/feed') => (status: 200, body: {'data': [], 'next_cursor': null}),
            ('GET', '/communities/8/members') => (status: 200, body: {'data': [
              {'id': 1, 'username': 'me', 'display_name': 'Me', 'role': 'owner', 'status': 'active'},
              {'id': 4, 'username': 'sam', 'display_name': 'Sam', 'role': 'member', 'status': 'pending'},
            ]}),
            ('PATCH', '/communities/8/members/4') => (status: 204, body: ''),
            _ => null,
          });
      await _pump(t, api, '/community/8');
      await t.tap(find.widgetWithText(OutlinedButton, 'Members')); await t.pumpAndSettle();
      expect(find.textContaining('Owner'), findsWidgets);
      expect(find.text('Wants to join'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Approve')); await t.pumpAndSettle();
      expect(api.calls('PATCH', '/communities/8/members/4').single.$3, {'action': 'approve'});
    });

    testWidgets('a failed join shows the server message', (t) async {
      final api = _Api((o) => switch ((o.method, o.path)) {
            ('GET', '/communities/9') => (status: 200, body: _c(9, 'Runners')),
            ('GET', '/communities/9/feed') => (status: 200, body: {'data': [], 'next_cursor': null}),
            ('POST', '/communities/9/join') => (status: 403, body: {'error': {'code': 'FORBIDDEN', 'message': 'You are banned from this community'}}),
            _ => null,
          });
      await _pump(t, api, '/community/9');
      await t.tap(find.widgetWithText(FilledButton, 'Join')); await t.pumpAndSettle();
      expect(find.text('You are banned from this community'), findsOneWidget);
    });
  });

  test('Community model flags', () {
    final c = Community.fromJson(_c(1, 'Book club', privacy: 'private', role: 'admin', status: 'active'));
    expect([c.isPrivate, c.isMember, c.isStaff, c.isOwner, c.isPage, c.initials], [true, true, true, false, false, 'BC']);
    expect(Community.fromJson(_c(2, 'x', status: 'pending', role: 'member')).isStaff, isFalse);
  });
}
