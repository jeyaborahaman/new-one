import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeyabo/core/theme/theme.dart';
import 'package:jeyabo/core/theme/tokens.dart';

double _lum(Color c) {
  double f(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}
double contrast(Color a, Color b) { final x = _lum(a), y = _lum(b); return (max(x, y) + 0.05) / (min(x, y) + 0.05); }

void main() {
  for (final entry in {'light': JeyaboTokens.light, 'dark': JeyaboTokens.dark}.entries) {
    final t = entry.value;
    test('${entry.key}: text pairs meet WCAG AA (4.5:1)', () {
      final pairs = {
        'ink/bg': (t.ink, t.bg), 'ink/surface': (t.ink, t.surface), 'ink/raised': (t.ink, t.surfaceRaised), 'ink/brandSoft': (t.ink, t.brandSoft),
        'muted/bg': (t.inkMuted, t.bg), 'muted/surface': (t.inkMuted, t.surface), 'onBrand/brand': (t.onBrand, t.brand),
        'onAccent/accent': (t.onAccent, t.accent), 'onGold/gold': (t.onGold, t.gold), 'onDanger/danger': (t.onDanger, t.danger),
        'danger/bg': (t.danger, t.bg), 'brand/bg': (t.brand, t.bg),
      };
      for (final p in pairs.entries) { expect(contrast(p.value.$1, p.value.$2), greaterThanOrEqualTo(4.5), reason: p.key); }
    });
    test('${entry.key}: control borders and focus meet 3:1', () {
      expect(contrast(t.borderStrong, t.surface), greaterThanOrEqualTo(3.0));
      expect(contrast(t.brand, t.surface), greaterThanOrEqualTo(3.0));
    });
  }

  test('theme builds for both brightnesses with tokens attached', () {
    for (final b in Brightness.values) { final th = buildTheme(b); expect(th.extension<JeyaboTokens>(), isNotNull); expect(th.colorScheme.secondaryContainer, th.extension<JeyaboTokens>()!.brandSoft); }
  });
}
