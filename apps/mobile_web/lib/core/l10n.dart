import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;
import '../l10n/app_localizations.dart';
export '../l10n/app_localizations.dart';

/// Languages the app ships. English is the fallback for anything else.
const supportedLanguages = ['en', 'ar', 'ur'];
const fallbackLanguage = 'en';
/// Each language named in its own script (shown in the language picker, never translated).
const languageEndonyms = {'en': 'English', 'ar': 'العربية', 'ur': 'اردو'};

/// The language the app will actually use: the saved choice, else the first supported device language, else English.
String effectiveLanguage(Locale? chosen, [List<Locale>? device]) {
  if (chosen != null && supportedLanguages.contains(chosen.languageCode)) return chosen.languageCode;
  for (final l in device ?? PlatformDispatcher.instance.locales) {
    if (supportedLanguages.contains(l.languageCode)) return l.languageCode;
  }
  return fallbackLanguage;
}

/// MaterialApp's resolution with an English fallback (the default would pick the first supported locale).
Locale resolveLocale(List<Locale>? device, Iterable<Locale> supported) => Locale(effectiveLanguage(null, device ?? const []));

/// Strings for code without a BuildContext (API errors, uploads).
AppLocalizations stringsFor(String language) => lookupAppLocalizations(Locale(supportedLanguages.contains(language) ? language : fallbackLanguage));

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String get _lang => Localizations.localeOf(this).toLanguageTag();

  /// "now", "5m", "3h", "2d", then a localized date.
  String timeAgo(DateTime t) {
    final l = l10n; final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return l.timeNow;
    if (d.inMinutes < 60) return l.timeMinutes(d.inMinutes);
    if (d.inHours < 24) return l.timeHours(d.inHours);
    if (d.inDays < 7) return l.timeDays(d.inDays);
    return intl.DateFormat.yMd(_lang).format(t);
  }
  /// 1.2K / 3.4M style counts in the current locale.
  String compact(num n) => intl.NumberFormat.compact(locale: _lang).format(n);
  String number(num n) => intl.NumberFormat.decimalPattern(_lang).format(n);
  String signedNumber(num n) => '${n > 0 ? '+' : ''}${number(n)}';
  String percent(double fraction) => intl.NumberFormat.percentPattern(_lang).format(fraction);
  String decimal1(double n) => intl.NumberFormat('0.0', _lang).format(n);
  /// 24-hour clock, as the design shows it.
  String clock(DateTime t) => intl.DateFormat.Hm(_lang).format(t);
  String dayMonthClock(DateTime t) => '${intl.DateFormat.Md(_lang).format(t)} ${clock(t)}';
}

/// Wraps text in a Unicode first-strong isolate so @handles, #tags and phone numbers keep their own direction
/// inside right-to-left sentences (otherwise "@name" renders as "name@").
String isolate(String s) => '\u2068$s\u2069';

/// Direction of user-written content (posts, comments, messages), independent of the UI language.
/// Null when the text has no strong characters (emoji, numbers): the surrounding direction applies.
final _letter = RegExp(r'\p{L}', unicode: true); // intl counts emoji surrogates as LTR, so test for real letters
TextDirection? contentDirection(String text) {
  if (!_letter.hasMatch(text)) return null;
  return intl.Bidi.estimateDirectionOfText(text) == intl.TextDirection.RTL ? TextDirection.rtl : TextDirection.ltr;
}
