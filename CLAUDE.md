# SonLite — Instructions pour Claude Code

## Graphe de connaissance du projet

Un graphe complet du projet est généré dans `graphify-out/` (558 nœuds, 662 edges, 39 communautés).
Avant toute modification, consulte `graphify-out/graph.json` ou `graphify-out/GRAPH_REPORT.md` pour identifier les fichiers concernés.

### Carte des communautés (fichiers cibles par domaine)

| Communauté | Fichiers principaux |
|---|---|
| **Audio Playback Engine** | `lib/core/services/audio_handler.dart`, providers player |
| **Unified Player UI** | `lib/features/player/unified_player_sheet.dart`, widgets player |
| **Playlist Management** | `lib/features/playlists/playlists_screen.dart`, `playlists_dao.dart`, `playlist_repository.dart` |
| **Database Schema & ORM** | `lib/core/database/app_database.dart`, `tracks_dao.dart`, `playlists_dao.dart` |
| **Navigation & Shell** | `lib/core/router/app_router.dart` (AppShell + GoRouter) |
| **Library Screen & Track UI** | `lib/features/library/library_screen.dart`, `track_repository.dart` |
| **Track Import & Library** | `lib/core/services/import_service.dart`, `image_service.dart` |
| **YouTube Downloader** | `lib/features/downloader/downloader_screen.dart`, `youtube_service.dart` |
| **Audio Editor** | `lib/features/editor/editor_screen.dart`, `modify_screen.dart`, `ffmpeg_service.dart` |
| **Auth & API Service** | `lib/core/services/api_service.dart`, `auth_providers.dart` |
| **Theme & State Providers** | `lib/core/providers/theme_provider.dart`, `player_expansion_provider.dart` |
| **Android Native Layer** | `android/app/src/main/kotlin/.../MainActivity.kt` |
| **Platform Channels** | MethodChannel `com.sonlite/ffmpeg` et `com.sonlite/ytdlp` |

### God nodes (abstractions centrales à ne pas casser)
1. `flutter_riverpod` — state management de tout le projet
2. `pubspec.yaml` — dépendances et version
3. `flutter/material.dart` — UI de base
4. `dart:io` — accès fichiers (audio, thumbnails)
5. `drift` — ORM base de données SQLite

### Mettre à jour le graphe
Quand des fichiers sont ajoutés ou modifiés significativement :
```
/graphify D:\projets\sonlite --update
```

## Conventions du projet

- Flutter + Riverpod (riverpod_annotation + code generation via build_runner)
- Drift pour SQLite (schemaVersion=3, migrations manuelles dans `app_database.dart`)
- GoRouter + ShellRoute avec PageView pour la navigation principale
- just_audio + audio_service pour la lecture audio en arrière-plan
- Version actuelle : 1.0.12+1 (Android uniquement)
- Après tout changement de provider `@riverpod` ou table Drift : relancer `dart run build_runner build`
