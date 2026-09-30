import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers.dart';
import '../core/theme/tokens.dart';
import '../core/widgets/common.dart';
import '../features/auth/auth_screens.dart';
import '../features/chat/chat_screens.dart';
import '../features/feed/composer_screen.dart';
import '../features/feed/feed_screen.dart';
import '../features/profile/profile_screens.dart';
import '../features/reels/reels_screen.dart';
import '../features/search/search_screen.dart';
import '../features/wallet/luckydraw_screen.dart';
import '../features/wallet/wallet_screens.dart';

const _publicPaths = {'/login', '/register', '/phone', '/forgot'};

/// Bridges Riverpod auth state to go_router so redirects re-run on sign in/out.
class _AuthRefresh extends ChangeNotifier { _AuthRefresh(Ref ref) { ref.listen(authProvider, (_, _) => notifyListeners()); } }

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  return GoRouter(
    refreshListenable: refresh,
    initialLocation: '/',
    redirect: (context, state) {
      final s = ref.read(authProvider).status;
      final loc = state.uri.path;
      if (s == AuthStatus.unknown) return loc == '/splash' ? null : '/splash';
      final signedIn = s == AuthStatus.signedIn;
      if (!signedIn && !_publicPaths.contains(loc)) return '/login';
      if (signedIn && (_publicPaths.contains(loc) || loc == '/splash')) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/phone', builder: (_, _) => const PhoneScreen()),
      GoRoute(path: '/forgot', builder: (_, _) => const ForgotScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const FeedScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/reels', builder: (_, _) => const ReelsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/create', builder: (_, _) => const ComposerScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/chats', builder: (_, _) => const ChatListScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/me', builder: (_, _) => const MyProfileScreen())]),
        ],
      ),
      GoRoute(path: '/chat/:id', builder: (_, s) => ChatThreadScreen(id: int.parse(s.pathParameters['id']!), title: s.uri.queryParameters['title'] ?? 'Chat')),
      GoRoute(path: '/user/:id', builder: (_, s) => UserProfileScreen(id: int.parse(s.pathParameters['id']!))),
      GoRoute(path: '/search', builder: (_, s) => SearchScreen(pickUser: s.uri.queryParameters['pick'] == '1')),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: '/wallet', builder: (_, _) => const WalletScreen()),
      GoRoute(path: '/leaderboard', builder: (_, _) => const LeaderboardScreen()),
      GoRoute(path: '/luckydraw', builder: (_, _) => const LuckyDrawScreen()),
    ],
  );
});

class _Shell extends ConsumerWidget {
  const _Shell(this.shell);
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    const dests = [
      (Icons.home_outlined, Icons.home_rounded, 'Home'), (Icons.play_circle_outline, Icons.play_circle_rounded, 'Reels'), (Icons.add_circle_outline, Icons.add_circle_rounded, 'Create'),
      (Icons.chat_bubble_outline, Icons.chat_bubble_rounded, 'Chats'), (Icons.person_outline, Icons.person_rounded, 'Profile'),
    ];
    final wide = MediaQuery.of(context).size.width >= 900;
    final body = shell;
    if (wide) {
      return Scaffold(body: Row(children: [
        NavigationRail(
          selectedIndex: shell.currentIndex, onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex), labelType: NavigationRailLabelType.all, backgroundColor: t.surface,
          leading: Padding(padding: const EdgeInsets.symmetric(vertical: Sp.s4), child: Text('Jeyabo', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: t.brand, fontWeight: FontWeight.w800))),
          destinations: [for (final d in dests) NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3))],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: body),
      ]));
    }
    return Scaffold(
      body: body, extendBody: shell.currentIndex == 1,
      bottomNavigationBar: Glass(
        radius: 0,
        child: NavigationBar(
          selectedIndex: shell.currentIndex, onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: [for (final d in dests) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3)],
        ),
      ),
    );
  }
}
