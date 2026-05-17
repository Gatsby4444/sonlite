// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$playbackStateHash() => r'3129865f6968a99f09ff5fc7e0c6c5a5f5b36e71';

/// See also [playbackState].
@ProviderFor(playbackState)
final playbackStateProvider = AutoDisposeStreamProvider<PlaybackState>.internal(
  playbackState,
  name: r'playbackStateProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$playbackStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PlaybackStateRef = AutoDisposeStreamProviderRef<PlaybackState>;
String _$currentMediaItemHash() => r'1df8b06622fdc696a1d56695ce68a66d2cf788a6';

/// See also [currentMediaItem].
@ProviderFor(currentMediaItem)
final currentMediaItemProvider = AutoDisposeStreamProvider<MediaItem?>.internal(
  currentMediaItem,
  name: r'currentMediaItemProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentMediaItemHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentMediaItemRef = AutoDisposeStreamProviderRef<MediaItem?>;
String _$audioQueueHash() => r'14524aee8ea748288faba61d5efac40cf9ef7838';

/// See also [audioQueue].
@ProviderFor(audioQueue)
final audioQueueProvider = AutoDisposeStreamProvider<List<MediaItem>>.internal(
  audioQueue,
  name: r'audioQueueProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$audioQueueHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AudioQueueRef = AutoDisposeStreamProviderRef<List<MediaItem>>;
String _$audioPositionHash() => r'f65536cccace1a983f3f9787833d00b75d7cb6aa';

/// See also [audioPosition].
@ProviderFor(audioPosition)
final audioPositionProvider = AutoDisposeStreamProvider<Duration>.internal(
  audioPosition,
  name: r'audioPositionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$audioPositionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AudioPositionRef = AutoDisposeStreamProviderRef<Duration>;
String _$loopModeHash() => r'55c82d45029df01c6a256fcf552f7cffea7bbe0f';

/// See also [loopMode].
@ProviderFor(loopMode)
final loopModeProvider = StreamProvider<AudioLoopMode>.internal(
  loopMode,
  name: r'loopModeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$loopModeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LoopModeRef = StreamProviderRef<AudioLoopMode>;
String _$shuffleEnabledHash() => r'132b71add132c0f88b2d9642371b8a18deb6ff11';

/// See also [shuffleEnabled].
@ProviderFor(shuffleEnabled)
final shuffleEnabledProvider = StreamProvider<bool>.internal(
  shuffleEnabled,
  name: r'shuffleEnabledProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$shuffleEnabledHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ShuffleEnabledRef = StreamProviderRef<bool>;
String _$loopStateHash() => r'59c27113f4c008fc2d27eddf13ed074b63a3478d';

/// See also [loopState].
@ProviderFor(loopState)
final loopStateProvider = StreamProvider<int>.internal(
  loopState,
  name: r'loopStateProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$loopStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LoopStateRef = StreamProviderRef<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
