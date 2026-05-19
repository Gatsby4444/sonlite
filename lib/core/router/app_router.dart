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

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    int currentIndex = 0;
    if (location.startsWith('/playlists')) currentIndex = 1;
    if (location.startsWith('/download')) currentIndex = 2;

    final item = ref.watch(currentMediaItemProvider).valueOrNull;
    final hasPlayer = item != null;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: child),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: hasPlayer ? 72.0 : 0.0,
              ),
            ],
          ),
          const UnifiedPlayerSheet(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/library');
            case 1:
              context.go('/playlists');
            case 2:
              context.go('/download');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.library_music), label: 'Bibliothèque'),
          NavigationDestination(icon: Icon(Icons.queue_music), label: 'Playlists'),
          NavigationDestination(icon: Icon(Icons.download), label: 'Télécharger'),
        ],
      ),
    );
  }
}
