# Guide de test — SonLite sur Android Studio

Ce guide explique comment lancer l'application SonLite sur un émulateur Android
depuis Android Studio. Aucune expérience préalable n'est requise.

---

## Prérequis

Avant de commencer, vérifie que tu as :

- **Android Studio** installé (la version utilisée pour configurer Flutter)
- **Flutter** installé dans `D:\flutter` et ajouté au PATH
- Le projet SonLite dans `D:\projets\sonlite`

---

## Étape 1 — Ouvrir le projet dans Android Studio

1. Lance **Android Studio**
2. Sur l'écran d'accueil, clique sur **Open**
3. Navigue jusqu'à `D:\projets\sonlite` et clique **OK**
4. Attends qu'Android Studio indexe le projet (barre de progression en bas)

> Si Android Studio te propose d'installer des plugins Flutter/Dart, accepte.
> Cela permet la coloration syntaxique et les outils Flutter intégrés.

---

## Étape 2 — Installer les plugins Flutter et Dart

Si ce n'est pas déjà fait :

1. Va dans **File → Settings** (ou `Ctrl + Alt + S`)
2. Clique sur **Plugins** dans le menu de gauche
3. Dans l'onglet **Marketplace**, cherche `Flutter`
4. Clique **Install** sur le plugin Flutter (le plugin Dart s'installe automatiquement)
5. Redémarre Android Studio quand il te le demande

---

## Étape 3 — Créer un émulateur Android

Un émulateur simule un téléphone Android sur ton PC. Tu n'as pas besoin d'un vrai téléphone.

### 3.1 — Ouvrir le Device Manager

- Dans la barre d'outils en haut à droite, clique sur l'icône **Device Manager**
  (ressemble à un téléphone avec un petit Android)
- Ou passe par le menu : **View → Tool Windows → Device Manager**

### 3.2 — Créer un nouvel émulateur

1. Clique sur le bouton **+** (ou **Create Virtual Device**)
2. Dans la liste des appareils, sélectionne **Pixel 8** (ou Pixel 7, peu importe)
3. Clique **Next**

### 3.3 — Choisir la version d'Android

1. Tu vois une liste d'images système (versions d'Android)
2. Sélectionne **API 35** (Android 15) ou **API 34** (Android 14)
   - Si tu ne l'as pas encore, clique sur le lien **Download** à côté
   - Attends le téléchargement (environ 1 Go, peut prendre quelques minutes)
3. Une fois téléchargée, sélectionne-la et clique **Next**

### 3.4 — Finaliser la configuration

1. Dans l'écran suivant, laisse tout par défaut
2. Le nom sera automatiquement `Pixel 8 API 35` ou similaire
3. Clique **Finish**

L'émulateur apparaît maintenant dans le Device Manager.

---

## Étape 4 — Démarrer l'émulateur

1. Dans le **Device Manager**, clique sur l'icône ▶ (triangle vert) à droite de ton émulateur
2. L'émulateur se lance dans une fenêtre séparée — attends que l'écran d'accueil Android apparaisse
3. Le premier démarrage peut prendre **2 à 3 minutes**, c'est normal

> Tu peux laisser l'émulateur ouvert en arrière-plan pendant toute la session de développement.

---

## Étape 5 — Lancer SonLite sur l'émulateur

### Option A — Depuis Android Studio (recommandé pour débuter)

1. En haut de la fenêtre Android Studio, tu vois une barre avec :
   - Un menu déroulant de configuration (probablement marqué `main.dart`)
   - Un menu déroulant d'appareil (devrait maintenant afficher ton émulateur)
   - Un bouton ▶ vert **Run**

2. Vérifie que le menu d'appareil affiche bien ton émulateur (ex: `Pixel 8 API 35`)
3. Clique sur **▶ Run** (ou appuie sur `Shift + F10`)
4. Attends — Flutter compile l'application (environ 1 à 2 minutes la première fois)
5. L'application SonLite s'ouvre automatiquement sur l'émulateur

### Option B — Depuis le terminal intégré

1. Dans Android Studio, ouvre le terminal : **View → Tool Windows → Terminal**
   (ou l'onglet **Terminal** en bas)
2. Tape :
   ```
   flutter run
   ```
3. Flutter détecte automatiquement l'émulateur et lance l'app

---

## Étape 6 — Comprendre les commandes Flutter en cours d'exécution

Une fois l'app lancée via le terminal, tu peux utiliser ces touches :

| Touche | Action |
|--------|--------|
| `r` | **Hot reload** — applique les changements de code instantanément (sans redémarrer) |
| `R` | **Hot restart** — redémarre l'app (efface l'état mémoire) |
| `q` | Quitter |
| `p` | Afficher les bordures des widgets (débogage UI) |
| `i` | Afficher les informations de performance |

> **Hot reload** est la fonctionnalité la plus utile : tu modifies le code,
> tu appuies sur `r`, et le changement apparaît en moins d'une seconde.

---

## Étape 7 — Tester les fonctionnalités de SonLite

### 7.1 — Tester la bibliothèque (écran principal)

- L'écran **Bibliothèque** s'affiche au lancement
- Il est vide pour l'instant — c'est normal

### 7.2 — Tester l'import de fichiers audio

Pour importer un fichier dans l'émulateur :

1. Glisse-dépose un fichier MP3 depuis ton PC vers la fenêtre de l'émulateur
   — ou —
   Dans Android Studio, va dans **Device Manager → ton émulateur → ... → Files**
   et dépose un fichier là

2. Dans SonLite, clique sur le bouton **+ Importer** (en bas à droite)
3. Navigue vers le fichier et sélectionne-le
4. Il apparaît dans la bibliothèque

### 7.3 — Tester le téléchargement YouTube

1. Clique sur l'onglet **Télécharger** (icône download en bas)
2. Colle une URL YouTube dans le champ (ex: `https://www.youtube.com/watch?v=dQw4w9WgXcQ`)
3. Clique sur **Télécharger**
4. La progression apparaît dans la liste

> Note : l'émulateur doit avoir accès à internet. Il utilise la connexion de ton PC.

### 7.4 — Tester le lecteur audio

1. Clique sur un titre dans la bibliothèque
2. La mini-barre de lecture apparaît en bas
3. Clique dessus pour ouvrir le lecteur complet
4. Teste play/pause, seek (glisser la barre), titre suivant/précédent

### 7.5 — Tester les playlists

1. Clique sur l'onglet **Playlists**
2. Appuie sur **+ Nouvelle playlist** et donne-lui un nom
3. Clique sur la playlist pour l'ouvrir
4. Appuie sur l'icône **+** en haut à droite pour ajouter des titres
5. Maintiens et fais glisser les titres pour les réordonner (icône ≡)

### 7.6 — Tester l'éditeur audio

1. Dans la bibliothèque, appuie longuement sur un titre (ou sur les 3 points ⋮)
2. Sélectionne **Éditer**
3. Tu arrives sur l'éditeur avec 3 onglets :
   - **Couper** : déplace les sliders Début/Fin puis clique sur "Exporter le segment"
   - **Séparer** : ajoute des points de coupure puis exporte
   - **Renommer** : modifie le titre et l'artiste puis sauvegarde

---

## Résolution des problèmes courants

### L'émulateur est très lent

- Active la virtualisation matérielle dans le BIOS (Intel VT-x ou AMD-V)
- Dans le Device Manager, édite l'émulateur et augmente la RAM à 2 Go ou plus
- Ferme les autres applications gourmandes en mémoire

### `flutter run` dit "No devices found"

- Vérifie que l'émulateur est bien démarré et que l'écran Android est visible
- Attends quelques secondes que Flutter détecte l'émulateur
- Tape `flutter devices` pour voir la liste des appareils détectés

### L'app crashe au démarrage

- Regarde les logs dans le terminal — le message d'erreur est affiché en rouge
- Appuie sur `R` (majuscule) pour un hot restart
- Si le problème persiste, ferme l'app sur l'émulateur et relance `flutter run`

### Erreur "Gradle build failed"

- Va dans le terminal et tape :
  ```
  cd android
  gradlew clean
  cd ..
  flutter run
  ```

### Le téléchargement YouTube ne fonctionne pas

- Vérifie que l'émulateur a accès à internet (essaie d'ouvrir Chrome dans l'émulateur)
- Certaines URLs peuvent être bloquées — essaie une autre vidéo YouTube

---

## Astuce : tester sur un vrai téléphone Android

Si tu as un téléphone Android, c'est encore mieux que l'émulateur (plus rapide, audio réel) :

1. Sur ton téléphone, va dans **Paramètres → À propos du téléphone**
2. Appuie **7 fois** sur **Numéro de build** — les "Options développeur" se débloquent
3. Dans **Paramètres → Options développeur**, active **Débogage USB**
4. Connecte le téléphone à ton PC avec un câble USB
5. Accepte la popup "Autoriser le débogage USB" sur le téléphone
6. Tape `flutter devices` dans le terminal — ton téléphone doit apparaître
7. Lance `flutter run` — l'app s'installe sur ton téléphone

---

## Structure du projet pour référence

```
D:\projets\sonlite\
├── lib\
│   ├── main.dart                    ← Point d'entrée de l'app
│   ├── features\
│   │   ├── library\                 ← Écran bibliothèque
│   │   ├── player\                  ← Lecteur audio
│   │   ├── playlists\               ← Gestion des playlists
│   │   ├── downloader\              ← Téléchargement YouTube
│   │   └── editor\                  ← Éditeur audio
│   └── core\
│       ├── database\                ← Base de données SQLite
│       ├── services\                ← Services (audio, import, YouTube, FFmpeg)
│       └── router\                  ← Navigation
├── android\                         ← Configuration Android
└── pubspec.yaml                     ← Dépendances du projet
```
