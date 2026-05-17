# Plan de distribution SonLite

## Distribution actuelle : GitHub Releases

L'APK signé (clé debug) est publié directement sur GitHub Releases.  
Les utilisateurs téléchargent et installent manuellement (option "sources inconnues" requise).

---

## Publication Play Store (future)

### ⚠️ Avertissement — yt-dlp / YouTube

Le téléchargement YouTube viole les CGU de YouTube. Google Play détecte `yt-dlp`/`youtubedl` dans le code.  
**Stratégie :** ne jamais mentionner YouTube dans la fiche Play Store. Décrire l'app comme "lecteur de musique locale avec téléchargeur audio universel".

### Étapes

#### 1. Compte Google Play Console
- play.google.com/console → 25 USD one-time
- Vérification d'identité requise

#### 2. Keystore de production (CRITIQUE — à faire avant toute soumission)
```bash
keytool -genkey -v -keystore sonlite-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias sonlite
```
Configurer `android/app/build.gradle.kts` :
```kotlin
signingConfigs {
    create("release") {
        storeFile = file("../../sonlite-release.jks")  // hors du repo git !
        storePassword = System.getenv("STORE_PASSWORD")
        keyAlias = "sonlite"
        keyPassword = System.getenv("KEY_PASSWORD")
    }
}
```
⚠️ Ne jamais commiter le `.jks` dans git. Si perdu → impossible de mettre à jour l'app.

#### 3. Assets Play Store requis
| Asset | Taille |
|---|---|
| Icône haute résolution | 512×512 PNG |
| Feature graphic | 1024×500 PNG |
| Screenshots (min 2) | 1080×1920 PNG |
| Privacy Policy URL | Page web publique |

- **Titre** : "SonLite — Lecteur de musique" (max 30 chars)
- **Description** : sans mention de YouTube

#### 4. Build AAB (format Play Store)
```bash
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

#### 5. Soumission
- Créer app dans Play Console → Production
- Uploader le `.aab` signé avec le keystore de prod
- Review Google : 1 à 7 jours

---

## Versioning

Incrémenter `version` dans `pubspec.yaml` à chaque release :
```
version: 1.0.0+1   →  1.0.1+2  →  1.1.0+3  etc.
```
Format : `nomVersion+versionCode` (le versionCode doit toujours augmenter).
