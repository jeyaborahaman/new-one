import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeyabo/core/l10n.dart';
import 'package:jeyabo/core/network/api_client.dart';
import 'package:jeyabo/core/providers.dart';
import 'package:jeyabo/core/theme/theme.dart';
import 'package:jeyabo/features/auth/auth_screens.dart';
import 'support.dart';

Map<String, dynamic> _arb(String lang) => jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;
/// Declared placeholders a message actually uses: "{name}" or, for plural/select, "{name,".
Set<String> _used(String s, Iterable<String> declared) => declared.where((p) => s.contains('{$p}') || s.contains('{$p,')).toSet();

Widget _app(Widget child, {Locale? locale, ApiClient? api}) {
  final a = api ?? fakeApi((o) => (status: 200, body: {}));
  return ProviderScope(
    overrides: [apiProvider.overrideWithValue(a), tokenStoreProvider.overrideWithValue(a.tokens)],
    child: MaterialApp(theme: buildTheme(Brightness.light, language: locale?.languageCode ?? 'en'), locale: locale, home: child,
        localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales,
        localeListResolutionCallback: (d, s) => resolveLocale(d, s)),
  );
}

void main() {
  group('ARB files', () {
    final en = _arb('en');
    final keys = en.keys.where((k) => !k.startsWith('@')).toSet();
    for (final lang in ['ar', 'ur']) {
      test('$lang has exactly the English keys and the same placeholders', () {
        final other = _arb(lang);
        expect(other.keys.where((k) => !k.startsWith('@')).toSet(), keys);
        for (final k in keys.where((k) => k != '@@locale')) {
          final declared = ((en['@$k'] as Map?)?['placeholders'] as Map?)?.keys.cast<String>() ?? const <String>[];
          expect(_used(other[k] as String, declared), _used(en[k] as String, declared), reason: '$lang/$k');
          expect((other[k] as String).trim(), isNotEmpty, reason: '$lang/$k');
        }
      });
    }
  });

  group('language resolution', () {
    test('saved choice wins, then the first supported device language, then English', () {
      expect(effectiveLanguage(const Locale('ur'), const [Locale('ar')]), 'ur');
      expect(effectiveLanguage(null, const [Locale('fr'), Locale('ar', 'SA')]), 'ar');
      expect(effectiveLanguage(null, const [Locale('fr'), Locale('de')]), 'en');
      expect(effectiveLanguage(const Locale('fr'), const []), 'en');
      expect(resolveLocale(const [Locale('de')], AppLocalizations.supportedLocales), const Locale('en')); // not the first supported (ar)
    });

    test('the choice is saved and restored on the next start', () async {
      final storage = MemStorage();
      final c1 = ProviderContainer(overrides: [prefsStorageProvider.overrideWithValue(storage)]);
      await c1.read(localeProvider.notifier).set(const Locale('ar'));
      expect(storage.m['app_locale'], 'ar');
      final c2 = ProviderContainer(overrides: [prefsStorageProvider.overrideWithValue(storage)]);
      await c2.read(localeProvider.notifier).load();
      expect(c2.read(localeProvider), const Locale('ar'));
      await c2.read(localeProvider.notifier).set(null); // back to the device language
      expect(storage.m.containsKey('app_locale'), isFalse);
      c1.dispose(); c2.dispose();
    });
  });

  group('rendering', () {
    testWidgets('Arabic and Urdu lay out right-to-left with translated text', (t) async {
      for (final (lang, title) in [('ar', 'مرحبًا بعودتك'), ('ur', 'خوش آمدید')]) {
        await t.pumpWidget(_app(const LoginScreen(), locale: Locale(lang)));
        await t.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        expect(Directionality.of(t.element(find.byType(LoginScreen))), TextDirection.rtl);
        expect(t.takeException(), isNull);
      }
      await t.pumpWidget(_app(const LoginScreen(), locale: const Locale('en')));
      await t.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(Directionality.of(t.element(find.byType(LoginScreen))), TextDirection.ltr);
    });

    testWidgets('an unsupported device language falls back to English', (t) async {
      t.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
      addTearDown(t.platformDispatcher.clearLocalesTestValue);
      await t.pumpWidget(_app(const LoginScreen()));
      await t.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('validation messages are localized', (t) async {
      await t.pumpWidget(_app(const RegisterScreen(), locale: const Locale('ar')));
      final btn = find.widgetWithText(FilledButton, 'إنشاء حساب');
      await t.ensureVisible(btn);
      await t.tap(btn);
      await t.pump();
      expect(find.text('أدخل بريدًا إلكترونيًا صالحًا'), findsOneWidget);
      expect(find.text('8 أحرف على الأقل'), findsWidgets);
    });

    testWidgets('dates, relative times and numbers follow the language', (t) async {
      late BuildContext en, ar, ur;
      Widget grab(void Function(BuildContext) f) => Builder(builder: (c) { f(c); return const SizedBox(); });
      await t.pumpWidget(_app(grab((c) => en = c), locale: const Locale('en'))); await t.pump();
      expect(en.timeAgo(DateTime.now()), 'now');
      expect(en.timeAgo(DateTime.now().subtract(const Duration(minutes: 5))), '5m');
      expect(en.compact(1200), '1.2K');
      expect(en.number(12345), '12,345');
      expect(en.l10n.pollVotes(1), '1 vote');
      expect(en.l10n.followersCount(2500000), '2.5M followers');
      await t.pumpWidget(_app(grab((c) => ar = c), locale: const Locale('ar'))); await t.pump();
      expect(ar.timeAgo(DateTime.now()), 'الآن');
      expect(ar.l10n.pollVotes(2), 'صوتان'); // Arabic dual
      expect(ar.l10n.pollVotes(3), contains('أصوات')); // Arabic "few"
      expect(ar.l10n.sentMedia('voice'), 'أرسل رسالة صوتية');
      await t.pumpWidget(_app(grab((c) => ur = c), locale: const Locale('ur'))); await t.pump();
      expect(ur.l10n.hashtagPosts(1), contains('پوسٹ'));
      expect(ur.timeAgo(DateTime.now().subtract(const Duration(hours: 3))), contains('گھنٹے'));
    });
  });

  test('bidi helpers: handles keep LTR inside RTL text; content direction follows the text', () {
    expect(isolate('@ann'), '\u2068@ann\u2069');
    expect(contentDirection('مرحبا بالعالم'), TextDirection.rtl);
    expect(contentDirection('یہ اردو ہے'), TextDirection.rtl);
    expect(contentDirection('Hello world'), TextDirection.ltr);
    expect(contentDirection('😀 123'), isNull); // no strong characters: use the surrounding direction
  });

  test('theme adds Arabic-script fallbacks without touching the Latin fonts', () {
    final en = buildTheme(Brightness.light), ur = buildTheme(Brightness.light, language: 'ur');
    expect(ur.textTheme.bodyMedium!.fontFamily, en.textTheme.bodyMedium!.fontFamily);
    expect(ur.textTheme.bodyMedium!.fontSize, en.textTheme.bodyMedium!.fontSize);
    expect(ur.textTheme.bodyMedium!.fontFamilyFallback!.first, 'NotoNastaliqUrdu');
    expect(en.textTheme.headlineMedium!.fontFamilyFallback!.first, 'NotoNaskhArabic');
  });

  test('API calls carry Accept-Language and client-side errors are localized', () async {
    String? sent;
    final api = fakeApi((o) { sent = o.headers['Accept-Language']; return (status: 200, body: {}); }, language: () => 'ur');
    await api.get('/x');
    expect(sent, 'ur');
    final offline = ApiClient(TokenStore(MemStorage()), dio: Dio()..httpClientAdapter = _Failing(), language: () => 'ar');
    await expectLater(offline.get('/x'), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'تعذّر الوصول إلى الخادم. تحقّق من اتصالك.')));
  });
}

class _Failing implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, s, c) async => throw DioException.connectionError(requestOptions: o, reason: 'down');
  @override
  void close({bool force = false}) {}
}
