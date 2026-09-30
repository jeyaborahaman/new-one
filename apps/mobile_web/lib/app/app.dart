import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../core/theme/theme.dart';
import 'router.dart';

class JeyaboApp extends ConsumerStatefulWidget { const JeyaboApp({super.key}); @override ConsumerState<JeyaboApp> createState() => _State(); }
class _State extends ConsumerState<JeyaboApp> {
  @override
  void initState() { super.initState(); Future.microtask(() => ref.read(authProvider.notifier).restore()); }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Jeyabo', debugShowCheckedModeBanner: false, routerConfig: ref.watch(routerProvider),
        theme: buildTheme(Brightness.light), darkTheme: buildTheme(Brightness.dark), themeMode: ref.watch(themeModeProvider),
      );
}
