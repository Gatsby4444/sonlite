# Rapport de développement — SonLite
**Date** : 17 mai 2026  
**Durée du sprint** : ~1 journée (session unique)  
**Stack** : Flutter 3.x · Kotlin · youtubedl-android · FFmpeg · Drift · Riverpod

---

## 1. Objectif principal

Créer une application Android de **lecteur de musique locale** avec un **téléchargeur audio intégré** permettant de télécharger l'audio depuis une URL (YouTube et autres) directement sur l'appareil, sans passer par des sites tiers douteux, sans publicités et utilisable hors ligne.

L'idée centrale : supprimer la friction entre "je veux écouter cette musique" et "je l'écoute dans mon lecteur", tout en gardant les fichiers en local sur le téléphone.

---

## 2. Architecture technique choisie

### 2.1 Choix Flutter
Flutter a été retenu pour la capacité à livrer une UI fluide et moderne rapidement, même avec une expérience Flutter limitée. Le paradigme "vibe coding" (développement assisté par IA) a guidé les choix techniques.

### 2.2 Stack complète

| Couche | Technologie | Rôle |
|---|---|---|
| UI / Navigation | Flutter + go_router | Écrans et routing |
| State management | Riverpod + riverpod_annotation | État réactif et injection de dépendances |
| Base de données | Drift (SQLite) | Bibliothèque musicale persistante |
| Lecture audio | just_audio + audio_service | Lecture en arrière-plan, notification, contrôles |
| Téléchargement | youtubedl-android (junkfood02 fork) | Wrapper Android de yt-dlp avec runtime Python embarqué |
| Traitement audio | FFmpeg (via youtubedl-android) | Trim, split, conversion MP3 |
| HTTP | Dio | Appels API |
| Stockage sécurisé | flutter_secure_storage | JWT, device ID |
| Métadonnées audio | flutter_media_metadata | Lecture des tags ID3 |
| Images | image_picker + image_cropper | Gestion des pochettes |
| Waveform | audio_waveforms | Visualisation de la forme d'onde dans l'éditeur |

### 2.3 Architecture des couches

```
lib/
├── core/
│   ├── database/        # Drift DAOs, repositories
│   ├── providers/       # Providers globaux (auth, thème)
│   ├── router/          # go_router
│   └── services/        # YoutubeService, FfmpegService, StartupService...
└── features/
    ├── library/         # Bibliothèque musicale
    ├── player/          # Lecteur audio
    ├── downloader/      # Téléchargeur
    ├── editor/          # Éditeur audio (trim/split)
    ├── playlists/       # Gestion des playlists
    ├── settings/        # Paramètres
    └── auth/            # Authentification (phase 2)
```

### 2.4 Communication Flutter ↔ Android (Platform Channels)

Deux canaux MethodChannel ont été créés dans `MainActivity.kt` :

- **`com.sonlite/ytdlp`** : `update`, `getInfo`, `download`
- **`com.sonlite/ffmpeg`** : `execute` (arguments FFmpeg en liste)

Un EventChannel **`com.sonlite/ytdlp_progress`** diffuse la progression du téléchargement en temps réel.

---

## 3. Fonctionnalités développées

### 3.1 Fonctionnalités principales (MVP)

#### Téléchargeur audio
- Coller une URL → extraction des métadonnées (titre, durée, artiste, miniature)
- Téléchargement de l'audio en meilleure qualité disponible (`-x --audio-format best --audio-quality 0`)
- Barre de progression en temps réel via EventChannel
- Miniature téléchargée séparément et stockée localement
- Enregistrement automatique en base de données
- **Mise à jour automatique de yt-dlp** au premier téléchargement de chaque session (non bloquant en cas d'échec réseau)

#### Lecteur audio
- Lecture avec just_audio
- Contrôles en arrière-plan via audio_service
- Notification persistante avec titre/artiste/pochette
- Contrôles depuis les écouteurs Bluetooth
- Mini-player persistant en bas de l'écran
- Écran player complet

#### Bibliothèque musicale
- Liste de tous les morceaux avec couverture, titre, artiste, durée
- Tri et recherche
- Import depuis les fichiers locaux existants (file_picker)
- Lecture des métadonnées ID3 (flutter_media_metadata)

#### Playlists
- Création, renommage, suppression de playlists
- Ajout/suppression de morceaux

#### Éditeur audio
- Trim : couper un extrait (début → fin)
- Split : diviser en plusieurs parties à des timestamps
- Conversion MP3 (libmp3lame)
- Visualisation de la forme d'onde (audio_waveforms)

### 3.2 Fonctionnalités annexes

- **Thème dynamique** : couleur d'accentuation personnalisable, persistée
- **Gestion des pochettes** : import depuis la galerie, recadrage (image_cropper)
- **Stockage sécurisé** : JWT et device ID via flutter_secure_storage
- **Startup service** : vérification d'une mise à jour yt-dlp au démarrage, communication avec un éventuel backend (Phase 2)
- **Sanitisation des noms de fichiers** : caractères spéciaux remplacés pour compatibilité Android

---

## 4. Problèmes rencontrés, causes et solutions

---

### PROBLÈME 1 — Crash au démarrage sur Android 13

**Symptôme :**
```
java.lang.Error: FFmpegKit failed to start on brand: Redmi, model: M2101K6G, api level: 33
Caused by: java.lang.UnsatisfiedLinkError: Bad JNI version returned from JNI_OnLoad 
in "libffmpegkit_abidetect.so": 0
```

**Cause profonde :**  
Le package `ffmpeg_kit_flutter_new` (fork `com.antonkarpenko`) enregistre un plugin Flutter (`onAttachedToActivity`) qui charge immédiatement la bibliothèque native `libffmpegkit_abidetect.so`. Cette `.so` a été compilée avec un NDK trop ancien dont la version JNI est incompatible avec Android 13 (API 33). Le chargement se fait dans un initialiseur statique Java — non rattrapable.

**Diagnostic :**  
Le crash se produit avant même l'affichage du premier écran. La trace de pile pointe vers `AbiDetect.<clinit>` (initialiseur statique) appelé depuis `FFmpegKitConfig.<clinit>`, lui-même déclenché par `onAttachedToActivity`.

**Solution appliquée :**  
Suppression complète de `ffmpeg_kit_flutter_new` de `pubspec.yaml`. Le projet dépendait déjà de `io.github.junkfood02.youtubedl-android:ffmpeg:0.18.1` qui embarque un binaire FFmpeg fonctionnel. Création d'un platform channel `com.sonlite/ffmpeg` dans `MainActivity.kt` qui :
1. Appelle `ensureInitialized()` pour s'assurer que FFmpeg est extrait
2. Localise le binaire FFmpeg à `{getNoBackupFilesDir()}/packages/ffmpeg/bin/ffmpeg`
3. L'exécute via `ProcessBuilder` avec `LD_LIBRARY_PATH = applicationInfo.nativeLibraryDir`

**Réécriture de `ffmpeg_service.dart` :**  
Passage d'une API `FFmpegKit.execute(cmdString)` à une API `_channel.invokeMethod('execute', {'args': [...]})` avec les arguments en liste (plus propre, évite les problèmes de parsing de la chaîne de commande).

**Comment éviter à l'avenir :**
- Avant d'ajouter un package FFmpeg Flutter, vérifier son activité GitHub et les issues ouvertes sur Android 13+
- `ffmpeg_kit_flutter_new` est un fork non officiel — préférer les solutions qui utilisent directement les bibliothèques natives déjà présentes dans les autres dépendances
- Si un package charge des `.so` natives au démarrage, tester systématiquement sur un appareil récent (API 31+) avant de l'adopter

---

### PROBLÈME 2 — yt-dlp impossible en binaire standalone sur Android

**Contexte (décision d'architecture préalable) :**  
La première idée était d'embarquer le binaire `yt-dlp` standalone directement dans l'APK et de l'exécuter via `Process.run`.

**Cause du blocage :**  
Android interdit l'exécution de binaires arbitraires depuis le répertoire de l'application (protection SELinux). Un binaire extrait dans `filesDir` n'a pas le bit d'exécution autorisé.

**Solution adoptée :**  
Utilisation de la librairie `youtubedl-android` (fork junkfood02) qui :
- Embarque un runtime Python complet comme `libpython.zip.so`
- Utilise une technique légale : les `.so` sont extraites depuis `nativeLibraryDir` puis décompressées dans `noBackupFilesDir` par le code Java de la librairie
- Expose une API Java/Kotlin (`YoutubeDL.getInstance().execute(request)`)

**Comment éviter à l'avenir :**
- Sur Android, pour exécuter un interpréteur ou un outil système, toujours chercher une librairie Android dédiée plutôt que d'embarquer un binaire natif
- La règle : si une `.so` est chargée via `System.loadLibrary()`, Android l'accepte ; si c'est un exécutable lancé via `ProcessBuilder` depuis `filesDir`, ça échoue

---

### PROBLÈME 3 — Téléchargement non fonctionnel en version release (première occurrence)

**Symptôme :**
```
PlatformException(GETINFO_ERROR, Unable to parse video information, null, null)
```
Fonctionne en debug, échoue en release.

**Cause profonde :**  
Flutter active R8 (successeur de ProGuard) en mode release. R8 **obfusque** les noms de classes Java/Kotlin. La librairie `youtubedl-android` utilise Jackson (`com.fasterxml.jackson`) pour désérialiser le JSON produit par yt-dlp (infos vidéo). Jackson utilise massivement la réflexion Java pour mapper le JSON vers des objets (`VideoInfo`, `VideoFormat`, etc.). Quand R8 renomme ces classes, la réflexion échoue et Jackson ne peut plus parser la réponse.

**Diagnostic :**  
Comparaison debug (fonctionne) vs release (échoue) → la seule différence est R8. Pas de ProGuard configuré dans le projet à ce stade.

**Solution appliquée :**  
Création de `android/app/proguard-rules.pro` :
```proguard
-keep class com.yausername.** { *; }
-keep class com.fasterxml.jackson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes Exceptions
```
Référencé dans `build.gradle.kts` :
```kotlin
proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
```

**Comment éviter à l'avenir :**
- Toute librairie Android qui utilise la réflexion (Jackson, Gson, Retrofit, Room...) **nécessite des règles ProGuard**
- Consulter systématiquement la documentation de chaque dépendance pour ses règles ProGuard recommandées
- Tester le build release sur device dès le début du développement, pas seulement en fin de sprint

---

### PROBLÈME 4 — Échec de compilation R8 après ajout des règles ProGuard

**Symptôme :**
```
ERROR: Missing classes detected while running R8.
ERROR: R8: Missing class java.beans.ConstructorProperties
```

**Cause :**  
Jackson référence des classes Java SE (`java.beans.*`, `org.w3c.dom.bootstrap.*`) qui n'existent pas sur Android. R8 signale ces références manquantes comme des erreurs bloquantes.

**Solution :**  
Ajout des règles `dontwarn` générées automatiquement par R8 dans `missing_rules.txt` :
```proguard
-dontwarn java.beans.ConstructorProperties
-dontwarn java.beans.Transient
-dontwarn org.w3c.dom.bootstrap.DOMImplementationRegistry
```

**Comment éviter à l'avenir :**
- Après tout ajout de dépendance, lancer un build release et vérifier `build/app/outputs/mapping/release/missing_rules.txt`
- Ces `dontwarn` sont inoffensives : elles indiquent à R8 d'ignorer des références à des classes Java SE absentes sur Android mais jamais appelées à l'exécution

---

### PROBLÈME 5 — Téléchargement toujours non fonctionnel en release (deuxième occurrence)

**Symptôme :**
```
PlatformException(GETINFO_ERROR, K4.e, null, null)
```
Erreur différente de la précédente. Apparaît même après l'ajout des règles `-keep`.

**Cause profonde :**  
Confusion entre **obfuscation** (renommage des classes) et **shrinking** (suppression du code mort). Les règles `-keep` protègent contre le renommage mais R8 continue à **supprimer** des classes jugées inutilisées. Or, `youtubedl-android` charge certaines classes **dynamiquement** via réflexion : R8 ne peut pas détecter statiquement que ces classes sont nécessaires et les supprime.

`K4.e` est le résultat du `toString()` d'une exception dont la classe a été supprimée ou corrompue par le shrinking — un nom de classe résiduel dans les tables de débogage.

La tentative intermédiaire (`-dontobfuscate`) n'a pas aidé car elle désactive le renommage mais **pas la suppression**.

**Solution finale :**  
Désactivation complète de R8 dans le build release :
```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
        isMinifyEnabled = false
        isShrinkResources = false
    }
}
```

**Impact :** APK légèrement plus grand (178MB vs 172MB) mais 100% fonctionnel.

**Comment éviter à l'avenir :**
- Pour toute librairie qui charge du code via réflexion, classe dynamique ou JNI, commencer par désactiver R8 et valider le fonctionnement, puis réactiver avec des règles progressives
- La règle `-keep` seule ne suffit pas si la librairie est complexe : ajouter aussi `-keepclassmembers` et `-keepnames`
- Pour les projets non-commerciaux ou dont la taille d'APK n'est pas critique, garder `isMinifyEnabled = false` est une décision valide
- Une future approche plus propre serait d'utiliser un consumer ProGuard fourni par la librairie youtubedl-android elle-même (à vérifier dans les releases futures)

---

### PROBLÈME 6 — Nomenclature incorrecte de l'APK sur GitHub

**Symptôme :**  
L'APK uploadé sur la release GitHub s'appelait `app-release.apk` au lieu du nom choisi.

**Cause :**  
La syntaxe `gh release create ... "fichier.apk#nom-affiché.apk"` pour renommer l'asset lors de l'upload ne fonctionne pas dans toutes les versions de `gh` CLI.

**Solution :**  
Upload séparé : supprimer l'asset existant puis uploader le fichier avec le bon nom via `gh release upload`.

**Comment éviter à l'avenir :**
```powershell
# Copier d'abord le fichier avec le bon nom, puis uploader
Copy-Item app-release.apk sonlite1.0.x.apk
gh release upload v1.0.x sonlite1.0.x.apk
```

---

## 5. Décisions techniques importantes et leurs justifications

### 5.1 Utilisation de `useLegacyPackaging = true`
Sans cette option, Android 6+ extrait les `.so` directement depuis l'APK en mémoire au lieu de les copier sur le disque. `youtubedl-android` a besoin que ses `.so` (Python runtime, FFmpeg) soient de vrais fichiers sur le système de fichiers pour les décompresser et les exécuter.

### 5.2 `abiFilters = ["arm64-v8a"]` uniquement
Limiter à l'architecture 64-bit arm couvre ~95% des appareils Android modernes et divise la taille de l'APK par 2 (le runtime Python pèse ~80MB par ABI). Décision consciente, documentée dans le code.

### 5.3 FFmpeg via ProcessBuilder plutôt que via l'API Java de youtubedl-android
La classe `com.yausername.ffmpeg.FFmpeg` n'expose pas de méthode `execute()` — elle gère uniquement l'initialisation et la mise à jour du binaire. Le binaire FFmpeg est extrait dans `{noBackupFilesDir}/packages/ffmpeg/bin/ffmpeg`. L'exécution se fait donc via `ProcessBuilder` avec le `LD_LIBRARY_PATH` correctement configuré.

### 5.4 Mise à jour automatique de yt-dlp (non-bloquante)
YouTube change régulièrement ses règles d'extraction. Plutôt que d'obliger l'utilisateur à mettre à jour l'APK, `YoutubeService._ensureUpdated()` appelle `updateYoutubeDL(STABLE)` une fois par lancement d'app. Si yt-dlp est déjà à jour, l'opération est rapide. Si le réseau est absent, l'app fonctionne quand même avec la version en cache.

---

## 6. Processus de publication

### 6.1 Builds
- **Debug** (`flutter build apk --debug`) : pour le développement et les tests
- **Release** (`flutter build apk --release`) : pour la distribution, R8 désactivé

### 6.2 Signing
Actuellement signé avec la **clé debug Android** (acceptable pour distribution hors Play Store, pas pour le Play Store officiel).

### 6.3 Distribution GitHub Releases
- Repo : https://github.com/Gatsby4444/sonlite
- Convention de nommage APK : `sonlite{X.Y.Z}.apk`
- Releases : v1.0.0 → v1.0.1 → v1.0.2 (versions correctives de cette session)

### 6.4 Mise à jour de l'APK
1. Incrémenter `version` dans `pubspec.yaml` : `1.0.0+1` → `1.0.1+2` (format `nomVersion+versionCode`)
2. `flutter build apk --release`
3. `gh release create vX.Y.Z "build\app\outputs\flutter-apk\app-release.apk#sonliteX.Y.Z.apk"`

---

## 7. Idées d'améliorations immédiates

### 7.1 Correctifs techniques prioritaires

| Amélioration | Description | Complexité |
|---|---|---|
| Keystore de production | Générer une vraie clé de signature pour sécuriser les mises à jour | Faible |
| Règles ProGuard complètes | Investiguer les règles exactes nécessaires pour réactiver R8 et réduire la taille APK | Moyenne |
| Chemin FFmpeg robuste | La détection du binaire FFmpeg via un chemin codé en dur est fragile — lire la valeur depuis la librairie via réflexion | Moyenne |
| Gestion des erreurs yt-dlp | Distinguer "vidéo privée", "région bloquée", "réseau absent", "yt-dlp outdated" dans les messages d'erreur | Faible |
| Timeout sur les téléchargements | Ajouter un timeout configurable pour éviter les blocages infinis | Faible |

### 7.2 Améliorations UX

| Amélioration | Description |
|---|---|
| File de téléchargement | Permettre de mettre plusieurs URLs en attente et les traiter séquentiellement |
| Historique des téléchargements | Afficher les téléchargements récents avec statut réussi/échoué |
| Égaliseur audio | Intégrer un EQ basique (just_audio supporte les filtres) |
| Mode sommeil | Arrêter la lecture après X minutes ou à la fin d'un morceau |
| Shuffle et repeat | Modes de lecture aléatoire et en boucle |
| Widget Android | Widget de contrôle sur l'écran d'accueil |
| Partage | Partager un fichier audio vers d'autres apps |
| Recherche globale | Recherche dans titre, artiste, album simultanément |
| Tri avancé | Tri par date d'ajout, durée, nombre d'écoutes |

### 7.3 Fonctionnalités nouvelles à envisager

| Fonctionnalité | Description | Complexité |
|---|---|---|
| **Import depuis Spotify** | Lire une playlist Spotify et télécharger les équivalents audio | Haute |
| **Synchro lyrics** | Affichage des paroles synchronisées (LRC) | Moyenne |
| **Statistiques d'écoute** | Combien de fois écouté, temps total d'écoute par artiste | Faible |
| **Export playlist M3U** | Exporter/importer des playlists au format standard | Faible |
| **Découverte par BPM** | Analyser le tempo des fichiers et filtrer par BPM | Haute |
| **Crossfade** | Transition progressive entre deux morceaux | Moyenne |
| **Détection des doublons** | Identifier les morceaux identiques ou similaires | Moyenne |
| **Support podcasts** | Gestion séparée pour les podcasts (reprise, vitesse variable) | Moyenne |
| **Backup/Restore** | Sauvegarder la bibliothèque + playlists vers Google Drive | Haute |
| **Tags automatiques** | Compléter les métadonnées manquantes via MusicBrainz ou Last.fm | Moyenne |

---

## 8. Feuille de route Phase 2 (Backend / Social)

D'après l'architecture prévue en mémoire de projet :

### Phase 2 — Serveur
- API FastAPI pour synchronisation de bibliothèque entre appareils
- Authentification JWT (infrastructure déjà en place côté Flutter)
- Endpoint de manifeste yt-dlp (`getYtDlpManifest()` déjà implémenté dans `startup_service.dart`)
- Historique de téléchargements côté serveur

### Phase 3 — Social
- Partage de playlists entre utilisateurs
- Découverte de musique basée sur ce qu'écoutent les autres utilisateurs
- Système de "likes" et recommandations

---

## 9. Points de vigilance pour la suite

### 9.1 Sécurité
- Ne jamais commiter le keystore (`.jks`) dans git — règle ajoutée dans `.gitignore`
- Les tokens JWT sont dans `flutter_secure_storage` (chiffré Android Keystore) — correct
- La clé de signing actuelle est la clé debug — à changer avant toute distribution large

### 9.2 Stabilité yt-dlp
- YouTube change ses règles environ toutes les 2-4 semaines
- La mise à jour automatique au premier téléchargement couvre ce cas
- Si YouTube fait un changement majeur, la mise à jour peut échouer si elle-même nécessite une nouvelle version de yt-dlp non encore disponible dans le channel STABLE → surveiller les issues GitHub de youtubedl-android

### 9.3 Taille de l'APK
- 178MB est lourd pour une app mobile
- Principal coupable : runtime Python embarqué (~80MB pour arm64) + FFmpeg (~35MB compressé)
- Impossible à réduire sans changer de stratégie de téléchargement
- Une approche alternative serait un backend server-side qui fait le téléchargement — mais cela change fundamentalement l'architecture

### 9.4 Compatibilité Android future
- `minSdk = 24` (Android 7.0) est raisonnable pour 2026
- Surveiller les breaking changes Android sur `useLegacyPackaging` dans les futures versions d'AGP
- Les binaires arm64 embarqués dans youtubedl-android sont compatibles jusqu'à Android 15 (API 35) — vérifier lors des mises à jour majeures de youtubedl-android

---

## 10. Résumé des fichiers modifiés lors de cette session

| Fichier | Type de modification |
|---|---|
| `pubspec.yaml` | Suppression de `ffmpeg_kit_flutter_new` |
| `android/app/build.gradle.kts` | `isMinifyEnabled = false`, `isShrinkResources = false`, `useLegacyPackaging = true` |
| `android/app/proguard-rules.pro` | Créé : règles keep + dontwarn (historique, inactif avec minify=false) |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Ajout channel `com.sonlite/ffmpeg` + méthode `runFFmpeg()` |
| `lib/core/services/ffmpeg_service.dart` | Réécriture complète : FFmpegKit → platform channel |
| `README.md` | Réécriture complète avec description du projet |
| `.gitignore` | Ajout règle `*.jks` / `*.keystore` |
| `LICENSE` | Créé : MIT |
| `DISTRIBUTION.md` | Créé : plan de publication Play Store |
| `rapportfinal.md` | Ce fichier |

---

## 11. Conclusion

En une journée de développement, SonLite est passé d'une base de code Flutter à une application Android **fonctionnelle, distribuée et versionnée** sur GitHub. Les obstacles majeurs étaient tous liés à l'intégration d'outils natifs Android dans Flutter :

1. **FFmpegKit** : incompatibilité JNI sur Android 13 → remplacé par l'exécution directe du binaire FFmpeg de youtubedl-android
2. **R8 minification** : suppression de classes utilisées par réflexion → désactivée pour garantir la stabilité

Ces problèmes sont représentatifs des défis classiques du développement Flutter-Android : la frontière entre Dart et le monde natif Java/Kotlin est une source constante de friction qui nécessite une bonne compréhension des deux écosystèmes.

Le projet dispose maintenant d'une base solide pour évoluer vers les phases Serveur et Social prévues dans la roadmap.

---

*Rapport généré avec Claude Code (claude-sonnet-4-6) — 17 mai 2026*
