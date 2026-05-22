import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'log_service.dart';

enum AudioLoopMode { off, all, oneWithCount }

class SonLiteAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();

  AudioLoopMode _loopMode = AudioLoopMode.off;
  bool _shuffleEnabled = false;
  List<MediaItem> _originalQueue = [];

  // Nombre de répétitions restantes (0 = infini quand oneWithCount actif)
  int _repeatTotal = 0;
  int _repeatRemaining = 0;
  bool _stopAfterLoop = false;

  final _loopModeController = StreamController<AudioLoopMode>.broadcast();
  final _shuffleController = StreamController<bool>.broadcast();
  final _loopStateController = StreamController<int>.broadcast();

  Stream<AudioLoopMode> get loopModeStream => _loopModeController.stream;
  Stream<bool> get shuffleStream => _shuffleController.stream;
  // 0=off, 1=×1, 2=×2, -1=infini
  Stream<int> get loopStateStream => _loopStateController.stream;

  AudioLoopMode get loopMode => _loopMode;
  bool get shuffleEnabled => _shuffleEnabled;
  int get loopState => _currentLoopState();

  int _currentLoopState() {
    if (_loopMode != AudioLoopMode.oneWithCount) return 0;
    if (_repeatTotal == 0) return -1;
    return _repeatTotal;
  }

  SonLiteAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) skipToNext();
    });
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  // MediaItem.== compare par id (= filePath). Si la base contient deux Track
  // pointant vers le même filePath (collision de noms de fichiers lors d'imports
  // ou téléchargements simultanés), indexOf renvoie toujours le PREMIER match
  // → le swipe boucle sur les mêmes pistes. On compare par trackId (unique en
  // base) via extras pour rester robuste à ces doublons.
  int _indexOfCurrent() {
    final current = mediaItem.value;
    if (current == null) return -1;
    final currentTid = current.extras?['trackId'];
    final q = queue.value;
    if (currentTid != null) {
      for (int i = 0; i < q.length; i++) {
        if (q[i].extras?['trackId'] == currentTid) return i;
      }
    }
    return q.indexOf(current);
  }

  @override
  Future<void> skipToNext() async {
    if (queue.value.isEmpty) {
      appLog('skipToNext : queue vide', level: LogLevel.warn, source: 'audio');
      return;
    }
    final currentIndex = _indexOfCurrent();
    appLog('skipToNext (depuis index=$currentIndex)', source: 'audio');

    if (_loopMode == AudioLoopMode.oneWithCount) {
      if (_repeatTotal == 0 || _repeatRemaining > 0) {
        if (_repeatTotal > 0) _repeatRemaining--;
        await skipToQueueItem(currentIndex < 0 ? 0 : currentIndex);
        return;
      }
      if (_stopAfterLoop) {
        await stop();
        return;
      }
      // Toutes les répétitions épuisées → désactiver la boucle
      _loopMode = AudioLoopMode.off;
      _repeatTotal = 0;
      _repeatRemaining = 0;
      _loopModeController.add(_loopMode);
      _loopStateController.add(0);
    }

    final newIndex = currentIndex + 1;
    if (newIndex >= queue.value.length) {
      // En shuffle : on re-mélange la bibliothèque pour un second tour qui
      // n'aura pas exactement le même ordre. En mode normal : on revient
      // au début comme avant.
      if (_shuffleEnabled && _originalQueue.isNotEmpty) {
        appLog('shuffle : fin de tournée → re-mélange', source: 'audio');
        queue.add(_buildShuffledOrder());
      }
      await skipToQueueItem(0);
      return;
    }
    await skipToQueueItem(newIndex);
  }

  @override
  Future<void> skipToPrevious() async {
    if (queue.value.isEmpty) return;
    final newIndex = _indexOfCurrent() - 1;
    if (newIndex >= 0) {
      await skipToQueueItem(newIndex);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    final item = queue.value[index];
    final path = item.extras?['filePath'] as String? ?? item.id;
    final tid = item.extras?['trackId'];
    appLog('skipToQueueItem #$index (trackId=$tid) → ${item.title}',
        source: 'audio');
    mediaItem.add(item);
    try {
      await _player.setFilePath(path);
      await _player.play();
    } catch (e) {
      appLog('setFilePath ÉCHEC : $e (path=$path)',
          level: LogLevel.error, source: 'audio');
      rethrow;
    }
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    queue.add([...queue.value, ...mediaItems]);
    if (_shuffleEnabled) _originalQueue = [..._originalQueue, ...mediaItems];
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    _originalQueue = List.from(queue);
    // Si le shuffle est actif, on re-mélange la nouvelle queue immédiatement
    // sinon shuffle resterait actif "fantôme" et le user n'aurait qu'un
    // play séquentiel sans le savoir.
    if (_shuffleEnabled) {
      this.queue.add(_buildShuffledOrder());
    } else {
      this.queue.add(queue);
    }
  }

  // Cycle 4 états : off → ×1 → ×2 → infini → off
  void cycleTrackLoop() {
    final state = _currentLoopState();
    if (state == 0) {
      _loopMode = AudioLoopMode.oneWithCount;
      _repeatTotal = 1;
      _repeatRemaining = 1;
    } else if (state == 1) {
      _repeatTotal = 2;
      _repeatRemaining = 2;
    } else if (state == 2) {
      _repeatTotal = 0; // infini
      _repeatRemaining = 0;
    } else {
      _loopMode = AudioLoopMode.off;
      _repeatTotal = 0;
      _repeatRemaining = 0;
    }
    _loopModeController.add(_loopMode);
    _loopStateController.add(_currentLoopState());
  }

  Future<void> setShuffle(bool enabled) async {
    // Idempotent : re-appeler avec la même valeur n'écrase pas _originalQueue.
    // Évite un bug subtil où setShuffle(true) ré-appelé alors que la queue est
    // déjà mélangée réduisait le pool à la mini-queue active.
    if (_shuffleEnabled == enabled) return;
    _shuffleEnabled = enabled;
    _shuffleController.add(enabled);

    if (enabled) {
      _originalQueue = List.from(queue.value);
      appLog('shuffle ON — pool de ${_originalQueue.length} pistes',
          source: 'audio');
      queue.add(_buildShuffledOrder());
    } else {
      final current = mediaItem.value;
      appLog('shuffle OFF — retour à l\'ordre original', source: 'audio');
      queue.add(_originalQueue);
      // mediaItem.add() n'a aucun effet si l'instance n'a pas changé : pas
      // besoin de le ré-émettre ici, l'index est recalculé à la volée.
      if (current != null) {
        final idx = _originalQueue.indexOf(current);
        if (idx < 0) {
          // Le morceau courant n'est plus dans la queue d'origine → on
          // démarre depuis le début pour éviter un état incohérent.
          unawaited(skipToQueueItem(0));
        }
      }
    }
  }

  /// Construit une queue contenant TOUTE la bibliothèque mélangée, en plaçant
  /// la piste courante en tête (index 0). C'est ce que font Spotify / Apple
  /// Music : pas de mini-fenêtre de 3 pistes, pas de loop à 5 morceaux.
  List<MediaItem> _buildShuffledOrder() {
    final current = mediaItem.value;
    final currentTid = current?.extras?['trackId'];
    final others = _originalQueue
        .where((m) => m.extras?['trackId'] != currentTid)
        .toList()
      ..shuffle();
    return [?current, ...others];
  }

  void setLoopConfig(AudioLoopMode mode, {int count = 0, bool stopAfter = false}) {
    _loopMode = mode;
    _repeatTotal = count;
    _repeatRemaining = count;
    _stopAfterLoop = stopAfter;
    _loopModeController.add(_loopMode);
    _loopStateController.add(_currentLoopState());
  }

  AudioPlayer get player => _player;

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 3],
      processingState: {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: mediaItem.value != null
          ? queue.value.indexOf(mediaItem.value!)
          : 0,
    ));
  }

  @override
  Future<void> onTaskRemoved() => stop();
}
