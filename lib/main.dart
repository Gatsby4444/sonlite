import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/audio_handler.dart';
import 'core/services/startup_service.dart';
import 'features/player/providers/player_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final audioHandler = await AudioService.init(
    builder: () => SonLiteAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.sonlite.audio',
      androidNotificationChannelName: 'SonLite Audio',
      androidNotificationOngoing: true,
    ),
  );

  final savedColor = await loadPersistedColor();

  final container = ProviderContainer(
    overrides: [
      audioHandlerProvider.overrideWithValue(audioHandler),
      themeColorProvider
          .overrideWith((ref) => ThemeColorNotifier(savedColor)),
    ],
  );

  container.read(startupServiceProvider).run();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SonLiteApp(),
    ),
  );
}

class SonLiteApp extends ConsumerWidget {
  const SonLiteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final seedColor = ref.watch(themeColorProvider);

    return MaterialApp.router(
      title: 'SonLite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
