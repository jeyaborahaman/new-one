import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class JAvatar extends StatelessWidget {
  const JAvatar(this.initials, {super.key, this.size = 40});
  final String initials; final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size, alignment: Alignment.center,
        decoration: BoxDecoration(color: context.tk.brandSoft, shape: BoxShape.circle),
        child: Text(initials, style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w700, color: context.tk.ink)),
      );
}

/// Story ring: brand = unseen, muted = seen, accent + label = live (never colour alone).
class StoryRing extends StatelessWidget {
  const StoryRing({super.key, required this.initials, this.seen = false, this.size = 60, this.label});
  final String initials; final bool seen; final double size; final String? label;
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      label: '${label ?? ''} ${seen ? 'seen' : 'new'} story',
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: seen ? t.borderStrong : t.brand, width: 2.5)),
        child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(shape: BoxShape.circle, color: t.bg), child: JAvatar(initials, size: size - 14)),
      ),
    );
  }
}

/// Glassmorphism panel: only over media, top bars and bottom nav. Never nest glass in glass.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = Rd.lg, this.padding});
  final Widget child; final double radius; final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(padding: padding, decoration: BoxDecoration(color: t.glass, borderRadius: BorderRadius.circular(radius), border: Border.all(color: t.glassBorder)), child: child),
      ),
    );
  }
}

class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.height = 16, this.width, this.radius = Rd.sm});
  final double height; final double? width; final double radius;
  @override
  Widget build(BuildContext context) => Container(height: height, width: width, decoration: BoxDecoration(color: context.tk.surfaceRaised, borderRadius: BorderRadius.circular(radius)));
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon; final String title; final String? message; final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Sp.s6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: context.tk.inkMuted),
            const SizedBox(height: Sp.s3),
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            if (message != null) Padding(padding: const EdgeInsets.only(top: Sp.s2), child: Text(message!, style: TextStyle(color: context.tk.inkMuted), textAlign: TextAlign.center)),
            if (action != null) Padding(padding: const EdgeInsets.only(top: Sp.s4), child: action),
          ]),
        ),
      );
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});
  final String message; final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => EmptyState(icon: Icons.cloud_off_rounded, title: 'Something went wrong', message: message, action: FilledButton(onPressed: onRetry, child: const Text('Try again')));
}

void toast(BuildContext context, String message) => ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message)));

const reactionEmoji = {'like': '👍', 'love': '❤️', 'wow': '😮', 'laugh': '😂', 'sad': '😢'};
