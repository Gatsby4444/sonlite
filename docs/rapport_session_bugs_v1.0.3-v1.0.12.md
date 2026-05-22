# Rapport de session — SonLite v1.0.3 → v1.0.12

**Date :** 2026-05-19  
**Périmètre :** Correction de bugs UI/lecteur + amélioration UX + feature image cache  
**Versions parcourues :** v1.0.3-beta → v1.0.4 → v1.0.5 → v1.0.6 → v1.0.7 → v1.0.8 → v1.0.9 → v1.0.10 → v1.0.11 → v1.0.12

---

## Table des matières

1. [Chronologie des problèmes et corrections](#1-chronologie-des-problèmes-et-corrections)
2. [Analyse technique approfondie de chaque bug](#2-analyse-technique-approfondie-de-chaque-bug)
3. [Ce qui a fonctionné du premier coup](#3-ce-qui-a-fonctionné-du-premier-coup)
4. [Ce qui a nécessité plusieurs tentatives](#4-ce-qui-a-nécessité-plusieurs-tentatives)
5. [Économies de temps possibles](#5-économies-de-temps-possibles)
6. [Mieux comprendre l'utilisateur et anticiper ses attentes](#6-mieux-comprendre-lutilisateur-et-anticiper-ses-attentes)
7. [Checklist préventive pour les prochaines sessions](#7-checklist-préventive-pour-les-prochaines-sessions)

---

## 1. Chronologie des problèmes et corrections

### v1.0.3-beta

**Contexte :** Premier sprint d'intégration du lecteur unifié.

| Problème signalé | Cause identifiée | Correction appliquée |
|---|---|---|
| Lecteur décalé trop haut | `bottom` calculé sans offset de la NavigationBar | Ajout du paramètre `navBarOffset` dans `UnifiedPlayerSheet` |
| Swipe non fluide (vertical et horizontal) | Multiple `GestureDetector` empilés avec conflits, seuils trop sensibles | Remplacer par un seul `GestureDetector` vertical englobant + ajustement des seuils |

---

### v1.0.5

**Contexte :** Correction du swipe après retour utilisateur.

| Problème signalé | Cause identifiée | Correction appliquée |
|---|---|---|
| Swipe horizontal : "le morceau swipe puis rollback avec piste suivante" | L'animation `animateTo()` après le swipe re-centrait l'artwork AVANT que `skipToNext()` change le `mediaItem`, créant un flash visuel | Snap direct `_swipeCtrl.value = 0.0` après que `skipToNext()` soit settled, sans animation de retour |
| Swipe down trop sensible | Seuil bas (200 px/s), sensibilité linéaire | Seuil porté à 400 px/s + sensibilité adaptative (`lerpDouble(4.0, 1.0, t)`) |

---

### v1.0.6

**Contexte :** Sprint UX — navigation par swipe, contrôles fixes, gestion images.

| Fonctionnalité / bug | Solution |
|---|---|
| Swipe entre les 3 onglets principaux | `PageView` dans l'AppShell avec `PageController` synchronisé à la `NavigationBar` |
| Contrôles player fixes en bas (hors zone swipe) | Restructuration `_FullContent` : `GestureDetector` global en haut, `Column` fixe avec controls en bas |
| Accès galerie direct pour les images | `ImageService.pickCropAndSave()` distinguant galerie vs fichiers |
| Suppression image playlist | Option `_ImageSource.remove` dans le bottom sheet |

---

### v1.0.7

**Contexte :** Deux bugs majeurs remontés.

#### Bug A — Lecteur ne s'ouvre pas automatiquement depuis la playlist

**Diagnostic initial (incomplet) :** Supposé être un problème d'ordre de déclenchement entre `updateQueue` et `playerExpandedProvider`.

**Correction v1.0.7 (insuffisante) :** Ajout de `ref.listen<AsyncValue<MediaItem?>>` comme déclencheur de secours.

**Résultat test :** Lecteur toujours non visible depuis la playlist. Bug persistant.

#### Bug B — Zone de swipe horizontal insuffisante

**Diagnostic :** Seule la zone artwork avait un `GestureDetector`. Le header et le titre étaient hors zone.

**Correction v1.0.7 (mal comprise par le modèle) :** Ajout d'un `GestureDetector` supplémentaire sur le titre — au lieu d'un seul `GestureDetector` englobant toute la zone supérieure.

**Résultat test :** Gaps encore présents entre les zones. Bug persistant.

---

### v1.0.8

**Contexte :** Deuxième tentative sur les deux bugs de v1.0.7.

#### Bug A — Mauvais morceau lu (toujours le morceau 0)

**Diagnostic profond :**
```dart
// audio_handler.dart — updateQueue appelait skipToQueueItem(0) en interne
@override
Future<void> updateQueue(List<MediaItem> queue) async {
  _originalQueue = List.from(queue);
  this.queue.add(queue);
  await skipToQueueItem(0);  // ← root cause
}
```
`skipToQueueItem(0)` forçait toujours le morceau 0 ET déclenchait un double-rebuild qui empêchait `ref.listen<bool>` de voir l'état correct.

**Correction :** Suppression du `skipToQueueItem(0)` interne dans `updateQueue`.

**Déclenchement du lecteur (`_playFrom`) :**
```dart
// Avant (incorrect) :
handler.updateQueue(queue);
handler.skipToQueueItem(index);
ref.read(playerExpandedProvider.notifier).state = true;

// Après (correct) :
handler.updateQueue(queue).then((_) {
  handler.skipToQueueItem(index);
  ref.read(playerExpandedProvider.notifier).state = true;
});
```

#### Bug B — Zone de swipe horizontal

**Correction finale :** Un seul `GestureDetector(behavior: HitTestBehavior.translucent)` dans un `Expanded` enveloppant header + artwork + titre. Les contrôles en dessous, hors du `GestureDetector`.

---

### v1.0.9

**Contexte :** `PlaylistDetailScreen` pousse via `Navigator.push(MaterialPageRoute(...))` — au-dessus de l'AppShell, donc l'`UnifiedPlayerSheet` de l'AppShell n'est pas visible.

| Problème signalé | Cause | Correction |
|---|---|---|
| Lecteur ne s'ouvre pas depuis la playlist | `PlaylistDetailScreen` est au-dessus de l'AppShell (impératif Navigator), son `UnifiedPlayerSheet` n'existe pas | Ajout d'un `UnifiedPlayerSheet(navBarOffset: 0)` directement dans le `Stack` de `PlaylistDetailScreen.build()` |

---

### v1.0.10

**Contexte :** Deux bugs résiduels identifiés en plan mode.

#### Bug — Lecteur affiche la piste suivante au 1er lancement

**Root cause :**
```dart
_swipeCtrl = AnimationController(
  vsync: this,
  lowerBound: -1.0,   // ← Flutter utilise lowerBound comme valeur initiale
  upperBound: 1.0,
  // value non spécifié → implicitement = lowerBound = -1.0
);
```
Avec `swipe = -1.0` : l'artwork courant était hors écran à gauche, la piste suivante était quasi-centrée.

**Correction :**
```dart
_swipeCtrl = AnimationController(
  vsync: this,
  lowerBound: -1.0,
  upperBound: 1.0,
  value: 0.0,  // ← explicite
);
```

#### Bug — Safety check causait la ré-expansion dans AppShell

**Root cause :** Un bloc `if (shouldBeExpanded && _expandCtrl.value < 0.5)` dans `build()` se déclenchait au rebuild d'AppShell lors du retour de la playlist (provider encore `true`, controller à `0`).

**Correction :** Suppression complète du safety check. Les deux `ref.listen` suffisent.

---

### v1.0.11 (correction insuffisante)

**Contexte :** Bug persistant — lecteur se ré-ouvre quand on quitte la playlist avec le mini-player.

**Tentative :** Ajout de `dispose()` dans `_PlaylistDetailScreenState` pour remettre `playerExpandedProvider = false`.

**Pourquoi ça ne marche pas :**
> `dispose()` se déclenche APRÈS la fin de la transition de navigation (~300ms), pas avant.

Pendant ces 300ms, AppShell est visible avec `_expandCtrl.value = 1.0` (animé quand le morceau a démarré). Le provider est encore `true`. Quand `dispose()` fire enfin, `ref.listen<bool>` déclenche `animateTo(0.0)` — mais AppShell est déjà pleinement visible avec le lecteur ouvert.

---

### v1.0.12 (corrections finales)

#### Fix 1 — PopScope avant la transition

**Root cause précise :** Race condition. L'animation `_collapse()` dure 350ms. Si l'utilisateur appuie Retour avant que `.then(() => playerExpandedProvider = false)` ait fired, AppShell apparaît avec le lecteur expand.

**Correction :**
```dart
// PlaylistDetailScreen.build()
return PopScope(
  onPopInvokedWithResult: (didPop, _) {
    if (didPop) ref.read(playerExpandedProvider.notifier).state = false;
  },
  child: Stack(...)
);
```
`PopScope.onPopInvokedWithResult` se déclenche **synchroniquement** quand le pop est initié, **avant** le début de la transition. AppShell's `ref.listen<bool>` démarre `animateTo(0.0)` avant qu'AppShell soit visible.

#### Fix 2 — Éviction du cache image Flutter

**Root cause :** `PaintingBinding.imageCache` mémoïse les images décodées par clé `FileImage(path)`. Si le fichier est écrasé (même chemin, nouveau contenu), Flutter sert l'ancienne image en cache sans relire le disque.

**Correction dans `TrackRepository` :**
```dart
Future<void> updateThumbnail(int id, String? thumbnailPath) async {
  final old = await ref.read(tracksDaoProvider).getTrackById(id);
  if (old?.thumbnailPath != null) {
    PaintingBinding.instance.imageCache.evict(FileImage(File(old!.thumbnailPath!)));
  }
  await ref.read(tracksDaoProvider).updateThumbnail(id, thumbnailPath);
}
```
Idem pour `restoreOriginalThumbnail` et `PlaylistRepository.updatePlaylist`.

---

## 2. Analyse technique approfondie de chaque bug

### 2.1 Le bug du lecteur qui se ré-ouvre (le plus long à corriger — 4 versions)

Ce bug a pris **4 versions** (v1.0.9 → v1.0.12) pour être résolu. C'est le bug le plus instructif de la session.

**Pourquoi était-il difficile ?**

Il impliquait la combinaison de trois mécanismes Flutter mal compris ensemble :

1. **`Navigator.push(MaterialPageRoute)` vs `ShellRoute`** — Les écrans poussés via le Navigator impératif sont au-dessus de l'AppShell dans l'arbre de widgets. L'AppShell et son `UnifiedPlayerSheet` restent montés et leurs providers écoutent toujours les changements.

2. **Le cycle de vie de `dispose()` dans Flutter** — `dispose()` se déclenche APRÈS la fin de l'animation de transition de route (~300ms), pas au moment où l'utilisateur appuie Retour. C'est un comportement non intuitif qui surprend même les développeurs expérimentés Flutter.

3. **`TickerFuture` et annulation des `.then()`** — Quand `AnimationController.dispose()` est appelé pendant une animation, le `TickerFuture` est annulé et les callbacks `.then()` ne s'exécutent jamais. C'est ce qui a rendu le fix `dispose()` doublement inefficace.

**La solution finale correcte :**

`PopScope.onPopInvokedWithResult` est le seul hook Flutter qui se déclenche **synchroniquement à l'initiation du pop**, avant l'animation de transition. C'est la seule approche garantissant que l'état soit remis à zéro avant qu'AppShell redevienne visible.

---

### 2.2 Le bug du mauvais morceau lu (toujours morceau 0)

**Cause racine cachée :** `updateQueue` dans `audio_handler.dart` appelait `skipToQueueItem(0)` en interne. Ce comportement était "caché" — raisonnable en isolation (initialiser la lecture à la première piste), mais catastrophique en contexte : il écrasait l'index passé par `_playFrom`.

**Effet secondaire du double-rebuild :** `skipToQueueItem(0)` déclenchait un changement de `mediaItem` (null → item[0]) qui causait un rebuild du provider avant que `playerExpandedProvider` soit positionné à `true`. Le `ref.listen<bool>` avait donc déjà "consommé" son delta sans déclencher l'expansion.

**Leçon :** Les méthodes de type "setup + side effect" dans les services audio sont des bombes à retardement. `updateQueue` doit faire UNE chose : mettre à jour la queue. L'initialisation de la lecture est la responsabilité de l'appelant.

---

### 2.3 Le bug `_swipeCtrl` initialisé à `lowerBound`

**Comportement Flutter documenté mais non intuitif :** `AnimationController` initialise sa valeur à `lowerBound` quand `value:` n'est pas spécifié. Avec `lowerBound: -1.0`, la valeur initiale est `-1.0`, ce qui positionnait l'artwork courant hors écran à gauche.

Ce bug disparaissait après le premier swipe manuel (qui remettait `value = 0.0`), rendant la reproduction incohérente.

**Leçon :** Toujours spécifier `value:` explicitement sur les `AnimationController` avec des bornes non-standard.

---

### 2.4 Le bug du cache image Flutter

**Comportement standard Flutter** : `Image.file()` utilise `FileImage` comme clé de cache. La clé est le **chemin** du fichier, pas son contenu. Flutter ne vérifie jamais si le fichier a été modifié sur disque après la première lecture.

Ce comportement est documenté et intentionnel (performance), mais non intuitif pour les développeurs débutants.

**Leçon :** Toute mise à jour d'image sur disque doit s'accompagner d'une éviction du cache. C'est une règle invariante dans les apps Flutter qui gèrent des fichiers locaux mutables.

---

## 3. Ce qui a fonctionné du premier coup

| Fonctionnalité | Version | Note |
|---|---|---|
| Swipe entre les 3 onglets principaux | v1.0.6 | `PageView` + `PageController` synchronisé |
| Suppression d'image de playlist | v1.0.6 | Option dans le bottom sheet |
| Accès galerie vs fichiers | v1.0.6 | `ImageService` avec enum `_ImageSource` |
| Contrôles player fixes en bas | v1.0.6 | Restructuration du layout `_FullContent` |
| Correction du rollback artwork | v1.0.5 | Snap direct `value = 0.0` après `skipToNext` |

---

## 4. Ce qui a nécessité plusieurs tentatives

| Bug | Tentatives | Raison de l'échec initial |
|---|---|---|
| Lecteur ne s'ouvre pas depuis playlist | 3 (v1.0.7, v1.0.8, v1.0.9) | Mauvais diagnostic : la vraie cause était `skipToQueueItem(0)` dans `updateQueue`, pas l'ordre des listeners |
| Lecteur se ré-ouvre en quittant la playlist | 4 (v1.0.9, v1.0.10, v1.0.11, v1.0.12) | Mécompréhension progressive du cycle de vie Flutter : safety check → dispose() → PopScope |
| Zone de swipe horizontal | 2 (v1.0.7, v1.0.8) | Mauvaise interprétation de la demande utilisateur (ajouter un GestureDetector vs un seul englobant) |
| Positionnement du lecteur | 2 (v1.0.3, v1.0.4) | Mauvaise estimation de l'offset initial |

---

## 5. Économies de temps possibles

### 5.1 Lire l'intégralité du code concerné avant tout diagnostic

**Ce qui s'est passé :** Pour le bug "lecteur ne s'ouvre pas depuis la playlist", le modèle a d'abord cherché la cause dans `unified_player_sheet.dart` (listeners, providers) sans lire `audio_handler.dart::updateQueue`. C'est là que se trouvait la vraie cause (`skipToQueueItem(0)` caché).

**Règle à appliquer :** Avant tout diagnostic, tracer l'**intégralité du flux d'exécution** d'un tap jusqu'à l'effet visible. Pour "cliquer un morceau ouvre le lecteur", ce flux est :
```
TrackTile.onTap
  → _playFrom()
    → audioHandler.updateQueue()    ← LIRE CE CODE
      → skipToQueueItem(0)          ← BUG ICI
    → audioHandler.skipToQueueItem(index)
    → playerExpandedProvider = true
      → ref.listen<bool> dans UnifiedPlayerSheet
        → _expandCtrl.animateTo(1.0)
```

Lire `audio_handler.dart` dès le début aurait trouvé le bug en **une version** au lieu de trois.

---

### 5.2 Comprendre `dispose()` dans le contexte des transitions Flutter avant de proposer un fix

**Ce qui s'est passé :** La correction "ajouter `dispose()` pour remettre le provider à false" a été proposée et appliquée en v1.0.11 sans vérifier quand `dispose()` se déclenche réellement dans le cycle de vie d'une transition `MaterialPageRoute`.

**Règle à appliquer :** Pour tout bug lié au cycle de vie d'une page, poser explicitement la question :
> "À quel moment précis dans la transition ce hook se déclenche-t-il ?"

Réponses à mémoriser :
- `dispose()` → APRÈS la fin de la transition de sortie (~300ms après le back)
- `PopScope.onPopInvokedWithResult` → AVANT la transition, synchroniquement
- `ModalRoute.didPopNext()` → quand la route qui couvre REPART (pas la route courante)
- `WidgetsBindingObserver.didPopRoute()` → pour intercepter le back système

Cette connaissance aurait évité **deux versions** (v1.0.11 était inutile).

---

### 5.3 Demander une clarification précise sur les demandes de gestes/layout

**Ce qui s'est passé :** La demande "étendre la zone de swipe horizontal" a été interprétée comme "ajouter un GestureDetector sur le titre" alors que l'utilisateur voulait "un seul GestureDetector couvrant tout depuis le header jusqu'en bas de l'artwork".

**Règle à appliquer :** Pour toute demande de modification de gestes ou de layout, demander :
> "Quelle zone exactement doit répondre au geste ? Peux-tu décrire visuellement les limites (top, bottom, left, right) ?"

Ou mieux : proposer deux options illustrées par des schémas ASCII avant d'implémenter.

---

### 5.4 Tester la correction sur tous les cas d'usage avant de livrer

**Ce qui s'est passé :** Le fix v1.0.9 (ajouter `UnifiedPlayerSheet` dans `PlaylistDetailScreen`) a résolu le problème de visibilité mais a introduit le bug de ré-expansion dans AppShell — car `playerExpandedProvider = true` restait actif quand on quittait.

**Règle à appliquer :** Après chaque fix, écrire explicitement les **cas à vérifier** avant de livrer :
1. Le cas corrigé fonctionne
2. Les cas adjacents ne régressent pas
3. Les cas "limite" (retour rapide, retour sans avoir réduit le lecteur, etc.)

Pour ce bug spécifiquement, les cas à vérifier auraient été :
- [ ] Ouvrir playlist → lancer morceau → lecteur s'ouvre ✓
- [ ] Ouvrir playlist → lancer morceau → réduire → retour → mini player visible seulement ✓
- [ ] Ouvrir playlist → lancer morceau → retour immédiat → AppShell visible sans lecteur plein écran ✓

Le cas 3 n'a pas été vérifié en v1.0.9, 1.0.10, 1.0.11.

---

### 5.5 Ne pas ajouter un safety check sans analyser ses effets de bord

**Ce qui s'est passé :** Un "safety check" avait été ajouté pour garantir l'expansion du lecteur dans certains cas limites :
```dart
if (shouldBeExpanded && _expandCtrl.value < 0.5) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _expand();
  });
}
```
Ce code, bien intentionné, déclenchait l'expansion à chaque rebuild quand `playerExpandedProvider = true` ET `_expandCtrl < 0.5` — incluant le rebuild d'AppShell lors du retour de la playlist.

**Règle à appliquer :** Toute logique dans `build()` qui déclenche un effet de bord (animation, setState, navigation) est à risque élevé. Préférer les `ref.listen` qui ne se déclenchent que sur les **changements de valeur**, pas sur les rebuilds.

---

### 5.6 Traiter les bugs et features en même temps quand ils touchent les mêmes fichiers

**Ce qui s'est passé :** Le bug "cache image" et le bug "lecteur se ré-ouvre" ont été traités ensemble en v1.0.12 (avec raison), mais ils auraient pu être détectés et groupés plus tôt si on avait analysé systématiquement les patterns de mise à jour dans les repositories dès v1.0.6 (quand la gestion d'images a été ajoutée).

**Règle à appliquer :** Quand on implémente une feature qui écrit/modifie des fichiers locaux en Flutter, se poser systématiquement la question :
> "Est-ce que `imageCache` a besoin d'être invalidé ici ?"

---

## 6. Mieux comprendre l'utilisateur et anticiper ses attentes

### 6.1 Profil de l'utilisateur

L'utilisateur est un **vibe-coder avec expérience Python/Node.js, débutant Flutter**. Ce profil a des implications directes sur la collaboration :

| Caractéristique | Impact sur les échanges |
|---|---|
| Débutant Flutter | Ne connaît pas les subtilités du cycle de vie (dispose, AnimationController, imageCache). Les explications techniques détaillées sont utiles mais ne doivent pas bloquer la progression. |
| Expérimenté côté backend | Comprend les concepts de race condition, de cache, de séquencement asynchrone — utiliser ces analogies. |
| Vibe-coder | Préfère voir des résultats rapides et tester sur device réel. Les bugs UX sont détectés à l'usage, pas à la lecture du code. |
| Tests sur device physique | Le feedback est précis ("le morceau swipe de l'autre côté puis rollback") mais pas technique. Traduire ces descriptions visuelles en root causes précises est la tâche principale du modèle. |

---

### 6.2 Patterns de demandes récurrents

En analysant l'ensemble de la session, plusieurs patterns se dégagent :

#### Pattern A — "C'est mieux mais il reste X"
L'utilisateur valide partiellement et signale le résidu. Cela signifie que **la correction était dans la bonne direction mais incomplète**. À chaque retour de ce type, chercher ce qui n'a pas été couvert dans le cas original.

#### Pattern B — "Ça n'a pas marché" (sans détail)
Signifie que le bug est identique au rapport précédent. Le diagnostic initial était probablement trop superficiel. Approfondir l'analyse du flux d'exécution complet.

#### Pattern C — "Et aussi..." (feature en fin de message)
L'utilisateur ajoute une fonctionnalité secondaire à la fin d'un rapport de bugs. Ces demandes sont souvent plus simples qu'il n'y paraît et peuvent être traitées en même temps. Ex : "et aussi faire en sorte que le changement d'image soit visible immédiatement".

#### Pattern D — Instructions de release précises
L'utilisateur est très précis sur la gestion des releases GitHub : ne jamais supprimer, ne promouvoir en "latest" que sur demande explicite. Ces contraintes doivent être traitées comme des **invariants non négociables** et vérifiées avant chaque `gh release create`.

---

### 6.3 Attentes implicites non formulées

Au fil de la session, plusieurs attentes n'ont jamais été formulées explicitement mais se sont révélées à travers les retours :

#### Attente 1 — Cohérence comportementale entre bibliothèque et playlist

Quand le bug "lecteur ne s'ouvre pas depuis la playlist" a été signalé, le comportement depuis la bibliothèque fonctionnait déjà. L'utilisateur attendait une **parité de comportement** entre les deux surfaces. Cette attente aurait dû être anticipée en v1.0.7 : dès qu'une fonctionnalité est corrigée à un endroit, vérifier systématiquement tous les points d'entrée analogues.

#### Attente 2 — Le mini-player persiste après avoir quitté la playlist

Le bug "le lecteur se ré-ouvre" révèle une attente forte : **l'état du lecteur (réduit vs plein écran) doit survivre à la navigation**. L'utilisateur a réduit le lecteur intentionnellement — quitter la playlist ne doit pas défaire ce geste.

Cette attente aurair dû être modélisée dès v1.0.9 : "quand on ajoute un `UnifiedPlayerSheet` dans `PlaylistDetailScreen`, comment le state du lecteur sera-t-il géré quand on quitte cet écran ?"

#### Attente 3 — Feedback immédiat pour toute action utilisateur

Le bug "image non rafraîchie" révèle une attente d'UX fondamentale : **chaque action doit avoir un retour visuel immédiat**. Pour un utilisateur non-technique, l'absence de feedback visuel = l'action a échoué. Cette attente aurait dû conduire à traiter le cache d'images dès v1.0.6 (quand la gestion des images a été introduite).

#### Attente 4 — La gestion du back doit être "naturelle"

L'utilisateur n'a pas décrit le bug comme "un problème de cycle de vie Flutter" mais comme "ça rouvre le lecteur". Pour lui, appuyer Retour doit se comporter comme sur n'importe quelle autre app : on revient à l'écran précédent dans l'état où on l'a laissé. Cette attente est universelle et aurait dû guider le design de l'intégration `PlaylistDetailScreen` dès le départ.

---

### 6.4 Vocabulaire utilisateur → vocabulaire technique

| Ce que l'utilisateur dit | Ce que ça signifie techniquement |
|---|---|
| "Le morceau se lance mais cela n'ouvre plus automatiquement le lecteur" | `playerExpandedProvider` reste `false` ou `ref.listen<bool>` ne se déclenche pas |
| "Le morceau sélectionné se lance bien mais le lecteur s'ouvre en affichant le son suivant" | `_swipeCtrl.value = -1.0` (lowerBound) ou `mediaItem` change avant `playerExpandedProvider` |
| "Cela rouvre le lecteur quand je quitte la playlist" | `_expandCtrl.value = 1.0` visible dans AppShell après pop, avec `playerExpandedProvider` encore `true` |
| "Le morceau swipe de l'autre côté puis rollback" | Animation `animateTo(-1.0)` + `animateTo(0.0)` se succèdent, le snap à 0 devrait être immédiat |
| "Le swipe up n'est pas fluide" | Seuil de déclenchement trop bas ou vitesse de swipe non compensée |
| "Il faut recharger l'app pour voir le changement" | Flutter image cache non invalidé après écriture sur disque |

---

### 6.5 Anticiper les bugs introduits par chaque nouvelle fonctionnalité

Chaque fonctionnalité ajoutée dans cette session avait un **bug latent prévisible** :

| Feature ajoutée | Bug latent prévisible | Aurait dû être anticipé en |
|---|---|---|
| `UnifiedPlayerSheet` dans `PlaylistDetailScreen` | Ré-expansion dans AppShell au retour | v1.0.9 — en se demandant "que se passe-t-il avec `playerExpandedProvider` quand on pop ?" |
| Gestion des images de morceau/playlist | Cache image non invalidé | v1.0.6 — en se demandant "Flutter met-il à jour les images chargées depuis le disque ?" |
| `updateQueue` initialisant `skipToQueueItem(0)` | Mauvais morceau joué à l'index non-0 | v1.0.3 — en se demandant "est-ce que `updateQueue` doit initialiser la lecture ?" |
| `AnimationController` avec `lowerBound: -1.0` | Artwork décalé au 1er affichage | v1.0.9 — en spécifiant `value: 0.0` de façon défensive |

---

## 7. Checklist préventive pour les prochaines sessions

### Avant chaque implémentation

- [ ] Tracer le flux d'exécution complet (de l'action utilisateur à l'effet visible) et lire TOUS les fichiers impliqués
- [ ] Pour tout `AnimationController` avec `lowerBound != 0` : spécifier `value:` explicitement
- [ ] Pour toute modification de fichier image local : prévoir l'éviction du `imageCache`
- [ ] Pour toute navigation impérative (`Navigator.push`) : prévoir la gestion du state au retour
- [ ] Pour tout hook de cycle de vie (`dispose`, `initState`) : vérifier à quel moment précis il se déclenche dans une transition

### Avant chaque livraison (release)

- [ ] Tester le cas corrigé
- [ ] Tester les cas adjacents (même fonctionnalité depuis d'autres surfaces)
- [ ] Tester le cas "retour rapide" / "action interrompue"
- [ ] Ne jamais supprimer une release GitHub existante
- [ ] Ne promouvoir en "latest" que sur demande explicite de l'utilisateur

### Pour chaque retour utilisateur

- [ ] Si "ça n'a pas marché" → approfondir le diagnostic, pas répéter le même fix
- [ ] Si "c'est mieux mais" → chercher ce qui n'a pas été couvert dans le cas original
- [ ] Traduire la description visuelle du bug en root cause précise avant de coder
- [ ] Grouper les corrections touchant les mêmes fichiers dans la même version

---

*Rapport généré le 2026-05-19 — SonLite v1.0.3 → v1.0.12*
