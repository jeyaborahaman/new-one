import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../core/theme/theme.dart';
import 'router.dart';

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class JeyaboApp extends ConsumerStatefulWidget { const JeyaboApp({super.key}); @override ConsumerState<JeyaboApp> createState() => _State(); }
class _State extends ConsumerState<JeyaboApp> {
  @override
  void initState() { super.initState(); Future.microtask(() => ref.read(authProvider.notifier).restore()); }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    // A tapped notification asks for a screen; open it, then clear the request.
    ref.listen(routeRequestProvider, (_, route) {
      if (route == null) return;
      router.push(route);
      ref.read(routeRequestProvider.notifier).clear();
    });
    // A push that arrives while the app is open is shown as an in-app banner.
    ref.listen(bannerProvider, (_, b) {
      if (b == null) return;
      _messengerKey.currentState?..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(b.title.isEmpty ? b.body : '${b.title}: ${b.body}')));
    });
    return MaterialApp.router(
      title: 'Jeyabo', debugShowCheckedModeBanner: false, routerConfig: router, scaffoldMessengerKey: _messengerKey,
      theme: buildTheme(Brightness.light), darkTheme: buildTheme(Brightness.dark), themeMode: ref.watch(themeModeProvider),
    );
  }
}
