# Guide de test — SonLite

## 1. Tester l'app sur un vrai device Android

### Prérequis
- Un téléphone Android **ARM64** (quasiment tous les téléphones depuis 2017)
- Android 7.0+ (API 24+)
- USB debugging activé sur le téléphone

### Activer le mode développeur sur Android
1. Aller dans **Paramètres → À propos du téléphone**
2. Appuyer **7 fois** sur **Numéro de build**
3. Retourner dans **Paramètres → Options développeur**
4. Activer **Débogage USB**

### Connecter et lancer
```bash
# Brancher le téléphone en USB, puis vérifier qu'il est détecté
flutter devices

# Lancer l'app sur le device (remplacer <device-id> par l'id affiché)
cd D:\projets\SONLITE
flutter run -d <device-id>
```

> Si un seul device est connecté, `flutter run` suffit sans `-d`.

### Ce que tu peux tester sur device

#### ✅ Import de fichiers locaux
1. Aller dans **Bibliothèque** → bouton **+** ou import
2. Sélectionner un fichier MP3/M4A depuis le stockage
3. La piste doit apparaître dans la liste avec titre et durée

#### ✅ Lecteur audio
1. Appuyer sur une piste pour la lancer
2. Tester : play/pause, skip, seek (glisser la barre)
3. Quitter l'app → la lecture doit **continuer en arrière-plan**
4. La notification de lecture doit apparaître dans le panneau de notifications

#### ✅ Playlists
1. Aller dans **Playlists** → créer une playlist
2. Ajouter des pistes depuis la bibliothèque
3. Réordonner avec le drag & drop

#### ✅ Téléchargement YouTube (ARM64 uniquement)
1. Aller dans **Télécharger**
2. Coller une URL YouTube (ex: `https://www.youtube.com/watch?v=dQw4w9WgXcQ`)
3. Appuyer sur Télécharger
4. Suivre la progression — la piste doit apparaître dans la bibliothèque une fois terminé

> ⚠️ **Ne fonctionne PAS sur émulateur x86_64.** Uniquement sur vrai device ARM64.

---

## 2. Lancer le backend

### Prérequis
- **Docker Desktop** installé et lancé : https://www.docker.com/products/docker-desktop/
- Node.js (pour le build admin en développement) : optionnel si on passe par Docker

### Lancer avec Docker Compose
```bash
cd D:\projets\SONLITE-SERVER
docker-compose up --build
```

Premier démarrage : ~2-3 minutes (téléchargement des images + build React).
Relances suivantes : ~20 secondes.

**Services disponibles après démarrage :**
| Service | URL | Description |
|---|---|---|
| API FastAPI | http://localhost:8000 | Backend principal |
| Swagger (doc API) | http://localhost:8000/docs | Interface de test des endpoints |
| Interface Admin | http://localhost:5173 | Dashboard web |

**Compte admin par défaut :**
- Email : `admin@sonlite.local`
- Mot de passe : `admin123`

> Changer ces valeurs dans `D:\projets\SONLITE-SERVER\backend\.env` avant de partager ou déployer.

---

## 3. Tester le backend avec Swagger

Aller sur http://localhost:8000/docs

### Créer un compte utilisateur
1. `POST /auth/register` → cliquer **Try it out**
2. Body :
```json
{
  "email": "test@exemple.com",
  "username": "testuser",
  "password": "monmotdepasse"
}
```
3. Copier le `access_token` dans la réponse

### S'authentifier dans Swagger
1. Cliquer le bouton **Authorize** (cadenas en haut à droite)
2. Coller le token dans le champ `HTTPBearer`
3. Tous les endpoints protégés sont maintenant accessibles

### Tester le manifest yt-dlp
- `GET /api/ytdlp/manifest` → retourne les versions stables/nightly actives
- Réponse attendue :
```json
{
  "stable": {
    "version": "2024.11.18",
    "url": "https://github.com/...",
    "sha256": "",
    "force_update": false
  },
  "nightly": null
}
```

### Tester les endpoints admin (avec token admin)
Se connecter d'abord avec `admin@sonlite.local` / `admin123` via `POST /auth/login`.

- `GET /api/stats` → statistiques globales
- `GET /api/users` → liste des utilisateurs
- `PUT /api/ytdlp/stable` → mettre à jour la version stable

---

## 4. Tester l'interface Admin

Aller sur http://localhost:5173

1. Se connecter avec `admin@sonlite.local` / `admin123`
2. **Dashboard** : vérifier les cartes stats et le graphique d'inscriptions
3. **Utilisateurs** : le compte test créé via Swagger doit apparaître
4. **yt-dlp** :
   - Mettre à jour la version stable (remplir version, URL, SHA256)
   - Cliquer ⚡ pour activer le force update
   - La barre de déploiement montre combien d'appareils ont la dernière version

---

## 5. Connecter l'app Flutter au backend

> Par défaut l'app pointe sur `10.0.2.2:8000` (adresse localhost depuis un émulateur Android).
> Pour un **vrai device**, modifier l'adresse dans le fichier suivant :

**`lib/core/services/api_service.dart` ligne 10 :**
```dart
// Émulateur Android
const _baseUrl = 'http://10.0.2.2:8000';

// Vrai device sur le même réseau Wi-Fi
// Remplacer par l'IP locale de ton PC (ex: 192.168.1.42)
const _baseUrl = 'http://192.168.1.42:8000';
```

Pour trouver l'IP locale de ton PC Windows :
```bash
ipconfig
# Chercher "Adresse IPv4" sous l'adaptateur Wi-Fi
```

Relancer l'app après modification (`flutter run`).

### Vérifier que la connexion fonctionne
1. Lancer l'app sur le device
2. Aller sur l'écran **Login**
3. Créer un compte ou se connecter
4. Dans l'admin → **Utilisateurs** : le nouveau compte doit apparaître
5. Dans l'admin → **yt-dlp** : après quelques secondes, un appareil doit s'enregistrer sous "Déploiement"

---

## Résumé rapide

```
# Terminal 1 — Backend
cd D:\projets\SONLITE-SERVER && docker-compose up --build

# Terminal 2 — App Flutter (device branché en USB)
cd D:\projets\SONLITE && flutter run
```
