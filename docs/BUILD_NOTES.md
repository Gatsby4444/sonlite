# SonLite — Notes de build Android

## État actuel

- **APK release** : `build/app/outputs/flutter-apk/app-release.apk` (253 MB)
- **compileSdk** : 36 (Android 16)
- **minSdk** : 24 (Android 7)
- **ABI** : `arm64-v8a` uniquement (appareils modernes 64 bits)

---

## Patches manuels appliqués (FRAGILES)

Ces modifications ont été faites directement dans le **cache pub global** (`C:\Users\USER\AppData\Local\Pub\Cache\`). Elles sont perdues si tu exécutes `flutter pub cache repair` ou que tu changes de machine.

### 1. `flutter_media_metadata` — compileSdk trop bas

**Fichier** : `.../flutter_media_metadata-1.0.0+1/android/build.gradle`

```diff
- compileSdkVersion 29
+ compileSdkVersion 36
```

**Cause** : Package abandonné, compileSdk 29 incompatible avec les dépendances AndroidX modernes qui utilisent `android:attr/lStar` (API 31+).

### 2. `flutter_media_metadata` — IOException non gérée

**Fichier** : `.../FlutterMediaMetadataPlugin.java` (ligne 42)

```diff
- retriever.release();
+ try { retriever.release(); } catch (IOException ignored) {}
```

**Cause** : En SDK 36, `MediaMetadataRetriever.release()` déclare maintenant `throws IOException`. Le code original ne le catch pas → erreur de compilation Java.

---

## Configuration Gradle nécessaire

### `android/app/build.gradle.kts`

```kotlin
compileSdk = 36   // forcé explicitement, flutter.compileSdkVersion retourne une valeur trop basse
```

### `android/gradle.properties`

```properties
kotlin.incremental=false
```

**Cause** : Bug du compilateur Kotlin incrémental sur Windows quand le cache pub (`C:\`) et le projet (`D:\`) sont sur des disques différents. Les chemins cross-drive cassent l'indexation des fichiers source.

---

## Problèmes à corriger pour stabiliser le build

### Priorité haute

#### Remplacer `flutter_media_metadata`

C'est la source de tous les problèmes de compilation. Le package est **abandonné** (dernière mise à jour 2022, compileSdk 29).

**Alternative recommandée** : [`metadata_god`](https://pub.dev/packages/metadata_god)
- Maintenu activement
- Supporte Android, iOS, Windows, Linux, macOS
- API similaire : `MetadataGod.readMetadata(file: path)`
- Pas de problème de SDK

**Migration** :
```yaml
# Remplacer dans pubspec.yaml
- flutter_media_metadata: ^1.0.0+1
+ metadata_god: ^0.3.4
```

Puis mettre à jour `ImportService` (le seul endroit qui l'utilise) pour appeler `MetadataGod.readMetadata()` à la place de `FlutterMediaMetadata.setFilePath()`.

#### Restaurer les patches si `flutter pub cache repair`

Si le cache pub est réparé/réinitialisé, les deux patches sur `flutter_media_metadata` doivent être réappliqués. Automatiser avec un script :

```powershell
# scripts/patch_pub_cache.ps1
$base = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\flutter_media_metadata-1.0.0+1\android"

# Patch 1 : compileSdk
(Get-Content "$base\build.gradle") -replace 'compileSdkVersion 29', 'compileSdkVersion 36' |
    Set-Content "$base\build.gradle"

# Patch 2 : IOException
$java = "$base\src\main\java\com\alexmercerind\flutter_media_metadata\FlutterMediaMetadataPlugin.java"
(Get-Content $java) -replace 'retriever\.release\(\);', 'try { retriever.release(); } catch (java.io.IOException ignored) {}' |
    Set-Content $java

Write-Host "Patches appliques."
```

### Priorité moyenne

#### Taille de l'APK (253 MB)

L'APK est gros à cause de `youtubedl-android` (runtime Python embarqué) et `ffmpeg_kit_flutter_new`.

Options pour réduire :
- Utiliser `flutter build apk --split-per-abi` → génère un APK par ABI (~80 MB au lieu de 253 MB) — déjà limité à `arm64-v8a` donc peu de gain supplémentaire
- Utiliser `flutter build appbundle` pour le Play Store (il split automatiquement par ABI)
- Évaluer si `ffmpeg_kit_flutter_new` peut être remplacé par une version "audio only" plus légère

#### Signature de l'APK release

Actuellement signé avec la **debug keystore** :
```kotlin
signingConfig = signingConfigs.getByName("debug")
```

Pour distribuer : créer une keystore de production et configurer `signingConfigs.release`.

```bash
keytool -genkey -v -keystore sonlite-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias sonlite
```

### Priorité basse

#### `android/app/build.gradle.kts` — targetSdk

`targetSdk = flutter.targetSdkVersion` peut devenir obsolète. Fixer à 35 ou 36 explicitement comme pour `compileSdk`.

#### Avertissements Java `source value 8`

Les avertissements `[options] source value 8 is obsolete` viennent de plugins tiers compilés avec `JavaVersion.VERSION_1_8`. Pas bloquant, mais pollue les logs.

---

## Commandes utiles

```bash
# Build APK release
flutter build apk --release

# Installer sur le téléphone connecté
flutter install --release

# Build par ABI (APK plus léger)
flutter build apk --release --split-per-abi

# Nettoyer le build
flutter clean

# Arrêter le daemon Gradle (si erreurs de cache)
cd android && gradlew.bat --stop
```

---

## Icône de l'application

Générée via `assets/icon/gen_icon.py` (Python + Pillow).  
Design : 5 barres d'égaliseur, fond dégradé indigo-violet, coins arrondis.

Pour regénérer après modification du design :
```bash
cd assets/icon && python gen_icon.py
cd ../.. && dart run flutter_launcher_icons
```
