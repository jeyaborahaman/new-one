import 'package:flutter/material.dart';

/// Design tokens from the Jeyabo design system (tokens.json), light and dark.
@immutable
class JeyaboTokens extends ThemeExtension<JeyaboTokens> {
  const JeyaboTokens({
    required this.bg, required this.surface, required this.surfaceRaised, required this.ink, required this.inkMuted,
    required this.border, required this.borderStrong, required this.brand, required this.onBrand, required this.brandSoft,
    required this.accent, required this.onAccent, required this.gold, required this.onGold, required this.danger,
    required this.onDanger, required this.glass, required this.glassBorder, required this.scrim,
  });

  final Color bg, surface, surfaceRaised, ink, inkMuted, border, borderStrong, brand, onBrand, brandSoft,
      accent, onAccent, gold, onGold, danger, onDanger, glass, glassBorder, scrim;

  static const light = JeyaboTokens(
    bg: Color(0xFFF5F7F4), surface: Color(0xFFFFFFFF), surfaceRaised: Color(0xFFEEF2EF), ink: Color(0xFF14201F),
    inkMuted: Color(0xFF4F5D5A), border: Color(0xFFD3DBD8), borderStrong: Color(0xFF74847F), brand: Color(0xFF0B7A6F),
    onBrand: Color(0xFFFFFFFF), brandSoft: Color(0xFFD7EFEB), accent: Color(0xFFC8452F), onAccent: Color(0xFFFFFFFF),
    gold: Color(0xFFF5B93A), onGold: Color(0xFF2A1C00), danger: Color(0xFFB3261E), onDanger: Color(0xFFFFFFFF),
    glass: Color(0xB8FFFFFF), glassBorder: Color(0x8CFFFFFF), scrim: Color(0x8C0D1413),
  );

  static const dark = JeyaboTokens(
    bg: Color(0xFF0D1413), surface: Color(0xFF162120), surfaceRaised: Color(0xFF1F2D2B), ink: Color(0xFFEAF2F0),
    inkMuted: Color(0xFFA3B4B0), border: Color(0xFF2A3A37), borderStrong: Color(0xFF70847F), brand: Color(0xFF3FD0BD),
    onBrand: Color(0xFF06231F), brandSoft: Color(0xFF10403A), accent: Color(0xFFFF8A70), onAccent: Color(0xFF2A0D06),
    gold: Color(0xFFF5B93A), onGold: Color(0xFF2A1C00), danger: Color(0xFFFF8B83), onDanger: Color(0xFF2B0806),
    glass: Color(0xA8162120), glassBorder: Color(0x1FFFFFFF), scrim: Color(0x99000000),
  );

  @override
  JeyaboTokens copyWith() => this;
  @override
  JeyaboTokens lerp(ThemeExtension<JeyaboTokens>? other, double t) => t < 0.5 ? this : (other as JeyaboTokens? ?? this);
}

extension TokensX on BuildContext {
  JeyaboTokens get tk => Theme.of(this).extension<JeyaboTokens>()!;
}

/// Spacing and radius scales.
class Sp { static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0, s6 = 24.0, s8 = 32.0; }
class Rd { static const sm = 8.0, md = 14.0, lg = 22.0, pill = 999.0; }
