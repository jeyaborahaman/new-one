import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/l10n.dart';
import '../core/providers.dart';
import '../core/theme/theme.dart';
import 'router.dart';
import '../features/calls/call_controller.dart';
import '../features/calls/call_screens.dart';

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class JeyaboApp extends ConsumerStatefulWidget { const JeyaboApp({super.key}); @override ConsumerState<JeyaboApp> createState() => _State(); }
class _State extends ConsumerState<JeyaboApp> {
  @override
  void initState() {
    super.initState();
    // Language first, so the first screens and the session restore already use it.
    Future.microtask(() async { await ref.read(localeProvider.notifier).load(); await ref.read(authProvider.notifier).restore(); });
  }

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
    // An incoming ring opens the call screen wherever the user is (this also starts listening for call signals).
    ref.listen(callControllerProvider, (prev, next) {
      if (next?.phase == CallPhase.incoming && prev?.callId != next!.callId) router.push('/call');
    });
    final locale = ref.watch(localeProvider);
    final language = effectiveLanguage(locale);
    return MaterialApp.router(
      title: 'Jeyabo', debugShowCheckedModeBanner: false, routerConfig: router, scaffoldMessengerKey: _messengerKey,
      theme: buildTheme(Brightness.light, language: language), darkTheme: buildTheme(Brightness.dark, language: language), themeMode: ref.watch(themeModeProvider),
      // Material/Cupertino/Widgets localizations make pickers, dialogs and text direction follow the language (RTL for ar/ur).
      locale: locale, supportedLocales: AppLocalizations.supportedLocales, localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeListResolutionCallback: (device, supported) => resolveLocale(device, supported),
      // The minimized-call pill floats above every screen until the user returns to the call or it ends.
      builder: (context, child) => Stack(children: [child!, MinimizedCallBar(onOpen: () => router.push('/call'))]),
    );
  }
}
