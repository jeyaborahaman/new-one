import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeyabo/core/providers.dart';
import 'package:jeyabo/core/network/api_client.dart';
import 'package:jeyabo/core/theme/theme.dart';
import 'package:jeyabo/features/auth/auth_screens.dart';
import 'support.dart';

Widget host(ApiClient api, Widget child, {Brightness b = Brightness.light}) => ProviderScope(
      overrides: [apiProvider.overrideWithValue(api), tokenStoreProvider.overrideWithValue(api.tokens)],
      child: MaterialApp(theme: buildTheme(b), home: child),
    );

void main() {
  testWidgets('empty login shows a helpful error and sends nothing', (t) async {
    final calls = <String>[];
    final api = fakeApi((o) { calls.add(o.path); return (status: 200, body: {}); });
    await t.pumpWidget(host(api, const LoginScreen()));
    await t.tap(find.text('Sign in'));
    await t.pump();
    expect(find.text('Enter your email or username and password'), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets('wrong password shows the server message inline', (t) async {
    final api = fakeApi((o) => (status: 401, body: {'error': {'code': 'UNAUTHORIZED', 'message': 'Invalid credentials'}}));
    await t.pumpWidget(host(api, const LoginScreen()));
    await t.enterText(find.widgetWithText(TextField, 'Email or username'), 'a@b.co');
    await t.enterText(find.widgetWithText(TextField, 'Password'), 'wrongpass');
    await t.tap(find.text('Sign in'));
    await t.pumpAndSettle();
    expect(find.text('Invalid credentials'), findsOneWidget);
  });

  testWidgets('2FA challenge switches the screen to a code entry', (t) async {
    final api = fakeApi((o) => o.path == '/auth/login' ? (status: 200, body: {'requires_2fa': true, 'challenge_token': 'tok'}) : (status: 401, body: {'error': {'message': 'Invalid code'}}));
    await t.pumpWidget(host(api, const LoginScreen()));
    await t.enterText(find.widgetWithText(TextField, 'Email or username'), 'a@b.co');
    await t.enterText(find.widgetWithText(TextField, 'Password'), 'password123');
    await t.tap(find.text('Sign in'));
    await t.pumpAndSettle();
    expect(find.text('Two-step check'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Code'), '000000');
    await t.tap(find.text('Verify'));
    await t.pumpAndSettle();
    expect(find.text('Invalid code'), findsOneWidget);
  });

  testWidgets('register validates fields before calling the API', (t) async {
    final calls = <String>[];
    final api = fakeApi((o) { calls.add(o.path); return (status: 201, body: {}); });
    await t.pumpWidget(host(api, const RegisterScreen()));
    final btn = find.widgetWithText(FilledButton, 'Create account');
    await t.ensureVisible(btn);
    await t.tap(btn);
    await t.pump();
    expect(find.text('Use 3-30 letters, numbers or _'), findsOneWidget);
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('At least 8 characters'), findsWidgets);
    expect(calls, isEmpty);
  });

  testWidgets('screens render in dark theme without overflow', (t) async {
    final api = fakeApi((o) => (status: 200, body: {}));
    await t.pumpWidget(host(api, const LoginScreen(), b: Brightness.dark));
    expect(tester(t), isNull);
  });
}

Object? tester(WidgetTester t) => t.takeException();
