import 'dart:async';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

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

  @override
  Future<void> skipToNext() async {
    if (queue.value.isEmpty) return;
    final currentIndex = mediaItem.value != null
        ? queue.value.indexOf(mediaItem.value!)
        : -1;

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
      await skipToQueueItem(0); // toujours revenir au début (bibliothèque et playlists)
      return;
    }
    await skipToQueueItem(newIndex);
    _maybeExtendShuffleQueue(newIndex);
  }

  @override
  Future<void> skipToPrevious() async {
    if (queue.value.isEmpty) return;
    final newIndex = (mediaItem.value != null
        ? queue.value.indexOf(mediaItem.value!) - 1
        : 0);
    if (newIndex >= 0) {
      await skipToQueueItem(newIndex);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    final item = queue.value[index];
    mediaItem.add(item);
    await _player.setFilePath(item.extras?['filePath'] as String? ?? item.id);
    await _player.play();
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    queue.add([...queue.value, ...mediaItems]);
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    _originalQueue = List.from(queue);
    this.queue.add(queue);
    if (queue.isNotEmpty) {
      await skipToQueueItem(0);
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
    _shuffleEnabled = enabled;
    _shuffleController.add(enabled);
    if (enabled) {
      _originalQueue = List.from(queue.value);
      final current = mediaItem.value;
      final excludeIds = {if (current != null) current.id};

      // Pre-pick 3 upcoming tracks (pondéré par récence)
      final upcoming = <MediaItem>[];
      final poolSize = _originalQueue.length - 1;
      for (int i = 0; i < 3 && i < poolSize; i++) {
        final pick = _pickWeightedRandom(
          excludeIds: {...excludeIds, ...upcoming.map((e) => e.id)},
        );
        upcoming.add(pick);
      }
      queue.add([?current, ...upcoming]);
    } else {
      final current = mediaItem.value;
      queue.add(_originalQueue);
      if (current != null) {
        final idx = _originalQueue.indexOf(current);
        if (idx >= 0) mediaItem.add(current);
      }
    }
  }

  // Sélection aléatoire pondérée : les morceaux récents ont moins de chances
  MediaItem _pickWeightedRandom({Set<String> excludeIds = const {}}) {
    final candidates = _originalQueue
        .where((item) => !excludeIds.contains(item.id))
        .toList();

    final pool = candidates.isNotEmpty ? candidates : _originalQueue;

    // Position depuis la fin de la queue → plus c'est récent, plus c'est bas
    final posFromEnd = <String, int>{};
    final q = queue.value;
    for (int i = 0; i < q.length; i++) {
      posFromEnd[q[i].id] = q.length - 1 - i;
    }

    final weights = pool.map((item) {
      final pos = posFromEnd[item.id];
      if (pos == null) return 1.0; // jamais joué récemment → poids max
      // pos=0 (le plus récent) → poids ~0.05 ; pos=9 → ~0.55
      final factor = (pos + 1) / (q.length + 1);
      return 0.05 + factor * 0.95;
    }).toList();

    final total = weights.fold(0.0, (a, b) => a + b);
    var point = Random().nextDouble() * total;
    for (int i = 0; i < pool.length; i++) {
      point -= weights[i];
      if (point <= 0) return pool[i];
    }
    return pool.last;
  }

  void setLoopConfig(AudioLoopMode mode, {int count = 0, bool stopAfter = false}) {
    _loopMode = mode;
    _repeatTotal = count;
    _repeatRemaining = count;
    _stopAfterLoop = stopAfter;
    _loopModeController.add(_loopMode);
    _loopStateController.add(_currentLoopState());
  }

  // Maintient ≥ 3 pistes à l'avance : ajoute 1 track à la fois
  void _maybeExtendShuffleQueue(int currentIndex) {
    if (!_shuffleEnabled || _originalQueue.isEmpty) return;
    final ahead = queue.value.length - currentIndex - 1;
    if (ahead >= 3) return;
    // Exclure les tracks déjà dans la look-ahead window
    final aheadIds =
        queue.value.sublist(currentIndex + 1).map((e) => e.id).toSet();
    queue.add([...queue.value, _pickWeightedRandom(excludeIds: aheadIds)]);
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
