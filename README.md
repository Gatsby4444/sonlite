# SonLite

Application Android de lecteur de musique locale avec téléchargeur audio intégré.

## Fonctionnalités

- **Téléchargement audio** — colle une URL et l'audio est téléchargé en haute qualité
- **Lecteur local** — lit les fichiers audio stockés sur l'appareil
- **Gestion de bibliothèque** — organise tes morceaux, albums et artistes
- **Éditeur audio** — coupe et divise tes fichiers audio (trim / split)
- **Lecture en arrière-plan** — contrôles depuis la notification et les écouteurs
- **Métadonnées** — affiche titre, artiste, durée et pochette d'album

## Téléchargement

👉 [Dernière version (APK)](../../releases/latest)

> Installation manuelle requise : activer **"Sources inconnues"** dans les paramètres Android.

## Compatibilité

| Critère | Valeur |
|---|---|
| Android minimum | 7.0 (API 24) |
| Architecture | arm64-v8a (appareils 64-bit) |
| Testé sur | Redmi Note 10 — Android 13 |

## Stack technique

| Composant | Technologie |
|---|---|
| UI | Flutter 3.x |
| State management | Riverpod |
| Navigation | go_router |
| Base de données | Drift (SQLite) |
| Lecture audio | just_audio + audio_service |
| Téléchargement | youtubedl-android (yt-dlp) |
| Traitement audio | FFmpeg (via youtubedl-android) |

## Build

### Prérequis
- Flutter SDK ≥ 3.11
- Android SDK (compileSdk 36, minSdk 24)
- NDK (version gérée par Flutter)

### Générer l'APK release
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release
```
L'APK est généré dans `build/app/outputs/flutter-apk/app-release.apk`.

## Licence

Ce projet est distribué sous licence [MIT](LICENSE).
