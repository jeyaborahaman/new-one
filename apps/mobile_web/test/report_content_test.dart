import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeyabo/core/l10n.dart';
import 'package:jeyabo/core/models.dart';
import 'package:jeyabo/core/network/api_client.dart';
import 'package:jeyabo/core/providers.dart';
import 'package:jeyabo/core/theme/theme.dart';
import 'package:jeyabo/features/feed/comments_sheet.dart';
import 'package:jeyabo/features/feed/post_card.dart';
import 'support.dart';

const _me = 1, _other = 7;

class _SignedIn extends AuthController {
  @override
  AuthState build() => AuthState(AuthStatus.signedIn, User(id: _me, username: 'me', displayName: 'Me'));
}

typedef _Reply = ({int status, Object body});

/// Records requests; answers from [routes] ("METHOD /path"), else 200 {}.
class _Api {
  _Api([this.routes = const {}]) { client = fakeApi((o) { sent.add((o.method, o.path, o.data)); return routes['${o.method} ${o.path}']?.call(o) ?? (status: 200, body: {}); }); }
  final Map<String, _Reply Function(RequestOptions)> routes;
  final sent = <(String, String, Object?)>[];
  late final ApiClient client;
  Object? bodyOf(String m, String p) => sent.lastWhere((r) => r.$1 == m && r.$2 == p).$3;
  bool called(String m, String p) => sent.any((r) => r.$1 == m && r.$2 == p);
}

Post _post({int id = 42, int author = _other}) => Post.fromJson({
      'id': id, 'type': 'text', 'body': 'hello world', 'created_at': 1790727815000,
      'author': {'id': author, 'username': 'ann', 'display_name': 'Ann Lee', 'level': 2},
    });

Widget _host(_Api api, Widget child, {Locale? locale}) => ProviderScope(
      overrides: [apiProvider.overrideWithValue(api.client), tokenStoreProvider.overrideWithValue(api.client.tokens), authProvider.overrideWith(_SignedIn.new)],
      child: MaterialApp(theme: buildTheme(Brightness.light), locale: locale, localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales, home: Scaffold(body: SingleChildScrollView(child: child))),
    );

Future<void> _openPostReport(WidgetTester t) async {
  await t.tap(find.byTooltip('More options'));
  await t.pumpAndSettle();
  await t.tap(find.text('Report'));
  await t.pumpAndSettle();
}

void main() {
  group('report post', () {
    testWidgets('only on other people\'s posts', (t) async {
      final api = _Api();
      await t.pumpWidget(_host(api, Column(children: [PostCard(_post(id: 1)), PostCard(_post(id: 2, author: _me))])));
      expect(find.byTooltip('More options'), findsOneWidget);
    });

    testWidgets('sends the post id, reason and details; shows the thank-you message', (t) async {
      final api = _Api({'POST /reports': (_) => (status: 201, body: {'id': 3})});
      await t.pumpWidget(_host(api, PostCard(_post())));
      await _openPostReport(t);
      expect(find.text('Report post'), findsOneWidget);
      expect(find.text('Why are you reporting this post?'), findsOneWidget);
      await t.tap(find.text('Hate speech'));
      await t.enterText(find.byType(TextField), 'slurs in the caption');
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Send report'));
      await t.pumpAndSettle();
      expect(api.bodyOf('POST', '/reports'), {'target_type': 'post', 'target_id': 42, 'reason': 'hate', 'details': 'slurs in the caption'});
      expect(find.text('Thanks for telling us. Our team will review it.'), findsOneWidget);
      expect(find.text('Report post'), findsNothing); // dialog closed
    });

    testWidgets('validation: no reason, no request; details are optional and blank details are not sent', (t) async {
      final api = _Api({'POST /reports': (_) => (status: 201, body: {'id': 3})});
      await t.pumpWidget(_host(api, PostCard(_post())));
      await _openPostReport(t);
      final send = find.widgetWithText(FilledButton, 'Send report');
      expect(t.widget<FilledButton>(send).onPressed, isNull);
      await t.tap(send); await t.pump();
      expect(api.called('POST', '/reports'), isFalse);
      await t.enterText(find.byType(TextField), '   ');
      await t.tap(find.text('Spam')); await t.pump();
      await t.tap(send); await t.pumpAndSettle();
      expect(api.bodyOf('POST', '/reports'), {'target_type': 'post', 'target_id': 42, 'reason': 'spam'});
      expect(find.byType(TextField), findsNothing); // dialog closed after a successful send
    });

    testWidgets('errors: the server message stays in the dialog (already reported, post removed, offline)', (t) async {
      for (final (status, message) in [(409, 'You already reported this'), (404, 'Post not found')]) {
        final api = _Api({'POST /reports': (_) => (status: status, body: {'error': {'code': 'X', 'message': message}})});
        await t.pumpWidget(_host(api, PostCard(_post())));
        await _openPostReport(t);
        await t.tap(find.text('Spam')); await t.pump();
        await t.tap(find.widgetWithText(FilledButton, 'Send report')); await t.pumpAndSettle();
        expect(find.text(message), findsOneWidget);
        expect(find.text('Report post'), findsOneWidget); // still open: the user can retry or cancel
        await t.tap(find.text('Cancel')); await t.pumpAndSettle();
        expect(find.text('Report post'), findsNothing);
        expect(find.text('Thanks for telling us. Our team will review it.'), findsNothing);
      }
    });
  });

  group('report comment', () {
    final comments = {'data': [
      {'id': 5, 'post_id': 42, 'author_id': _other, 'body': 'rude remark', 'depth': 0, 'created_at': 1790727815000, 'author': {'id': _other, 'display_name': 'Ann Lee'}},
      {'id': 6, 'post_id': 42, 'author_id': _me, 'body': 'my reply', 'depth': 0, 'created_at': 1790727815000, 'author': {'id': _me, 'display_name': 'Me'}},
    ], 'next_cursor': null};

    testWidgets('only on other people\'s comments; sends the comment id and reason', (t) async {
      final api = _Api({'GET /posts/42/comments': (_) => (status: 200, body: comments), 'POST /reports': (_) => (status: 201, body: {'id': 9})});
      await t.pumpWidget(_host(api, CommentsSheet(post: _post())));
      await t.pumpAndSettle();
      expect(find.byTooltip('More options'), findsOneWidget); // not on "my reply"
      await _openPostReport(t);
      expect(find.text('Report comment'), findsOneWidget);
      expect(find.text('Why are you reporting this comment?'), findsOneWidget);
      await t.tap(find.text('Harassment or bullying')); await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Send report')); await t.pumpAndSettle();
      expect(api.bodyOf('POST', '/reports'), {'target_type': 'comment', 'target_id': 5, 'reason': 'harassment'});
      expect(find.text('Thanks for telling us. Our team will review it.'), findsOneWidget);
    });

    testWidgets('a deleted comment: the error is shown and nothing breaks', (t) async {
      final api = _Api({'GET /posts/42/comments': (_) => (status: 200, body: comments), 'POST /reports': (_) => (status: 404, body: {'error': {'code': 'NOT_FOUND', 'message': 'Comment not found'}})});
      await t.pumpWidget(_host(api, CommentsSheet(post: _post())));
      await t.pumpAndSettle();
      await _openPostReport(t);
      await t.tap(find.text('Spam')); await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Send report')); await t.pumpAndSettle();
      expect(find.text('Comment not found'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('Arabic: translated and right-to-left', (t) async {
      final api = _Api({'GET /posts/42/comments': (_) => (status: 200, body: comments)});
      await t.pumpWidget(_host(api, CommentsSheet(post: _post()), locale: const Locale('ar')));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('خيارات أخرى')); await t.pumpAndSettle();
      await t.tap(find.text('إبلاغ')); await t.pumpAndSettle();
      expect(find.text('الإبلاغ عن التعليق'), findsOneWidget);
      expect(find.text('مضايقة أو تنمّر'), findsOneWidget);
      expect(Directionality.of(t.element(find.text('الإبلاغ عن التعليق'))), TextDirection.rtl);
    });
  });
}
