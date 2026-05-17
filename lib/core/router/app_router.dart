import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/login_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/player/player_screen.dart';
import '../../features/player/widgets/mini_player.dart';
import '../../features/playlists/playlists_screen.dart';
import '../../features/downloader/downloader_screen.dart';
import '../../features/editor/editor_screen.dart';
import '../../features/editor/modify_screen.dart';
import '../../features/settings/settings_screen.dart';

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
        path: '/player',
        builder: (context, state) => const PlayerScreen(),
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

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    int currentIndex = 0;
    if (location.startsWith('/playlists')) currentIndex = 1;
    if (location.startsWith('/download')) currentIndex = 2;

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: child),
          const MiniPlayer(),
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
