import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/login_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/playlists/playlists_screen.dart';
import '../../features/downloader/downloader_screen.dart';
import '../../features/editor/editor_screen.dart';
import '../../features/editor/modify_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/player/unified_player_sheet.dart';
import '../../features/player/providers/player_providers.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/library',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/library',
            builder: (context, state) => const LibraryScreen(),
          ),
          GoRoute(
            path: '/playlists',
            builder: (context, state) => const PlaylistsScreen(),
          ),
          GoRoute(
            path: '/download',
            builder: (context, state) => const DownloaderScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/editor/:trackId',
        builder: (context, state) {
          final trackId = int.parse(state.pathParameters['trackId']!);
          return EditorScreen(trackId: trackId);
        },
      ),
      GoRoute(
        path: '/modify/:trackId',
        builder: (context, state) {
          final trackId = int.parse(state.pathParameters['trackId']!);
          return ModifyScreen(trackId: trackId);
        },
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}

// ─── Shell principal ──────────────────────────────────────────────────────────

class AppShell extends ConsumerStatefulWidget {
  // child est fourni par ShellRoute mais non utilisé ici (pages gérées par PageView)
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final PageController _pageCtrl;
  bool _animating = false;

  static const _routes = ['/library', '/playlists', '/download'];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  int _locationIndex(String location) {
    if (location.startsWith('/playlists')) return 1;
    if (location.startsWith('/download')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final targetIndex = _locationIndex(location);

    // Sync PageController si la route change depuis l'extérieur (ex: deep link)
    if (_pageCtrl.hasClients && !_animating) {
      final currentPage = _pageCtrl.page?.round() ?? 0;
      if (currentPage != targetIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_animating && _pageCtrl.hasClients) {
            _pageCtrl.jumpToPage(targetIndex);
          }
        });
      }
    }

    final item = ref.watch(currentMediaItemProvider).valueOrNull; // ignore: unused_local_variable
    final hasPlayer = item != null;

    return Stack(
      children: [
        Scaffold(
          body: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  // Quand l'utilisateur swipe, mettre à jour l'URL
                  onPageChanged: (i) {
                    if (_animating) return;
                    context.go(_routes[i]);
                  },
                  children: const [
                    LibraryScreen(),
                    PlaylistsScreen(),
                    DownloaderScreen(),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: hasPlayer ? 72.0 : 0.0,
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: targetIndex,
            onDestinationSelected: (i) {
              if (i == targetIndex) return;
              _animating = true;
              _pageCtrl
                  .animateToPage(
                    i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  )
                  .then((_) {
                _animating = false;
                if (mounted) context.go(_routes[i]);
              });
            },
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.library_music), label: 'Bibliothèque'),
              NavigationDestination(
                  icon: Icon(Icons.queue_music), label: 'Playlists'),
              NavigationDestination(
                  icon: Icon(Icons.download), label: 'Télécharger'),
            ],
          ),
        ),
        const UnifiedPlayerSheet(),
      ],
    );
  }
}
