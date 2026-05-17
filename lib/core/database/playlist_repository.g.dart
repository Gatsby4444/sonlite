// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$playlistsDaoHash() => r'f0fa7acdb7c5f1908be0cd9cff97ec2660a5d76d';

/// See also [playlistsDao].
@ProviderFor(playlistsDao)
final playlistsDaoProvider = Provider<PlaylistsDao>.internal(
  playlistsDao,
  name: r'playlistsDaoProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$playlistsDaoHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PlaylistsDaoRef = ProviderRef<PlaylistsDao>;
String _$playlistRepositoryHash() =>
    r'e6818d564572185787d426f106a5d017a4428783';

/// See also [PlaylistRepository].
@ProviderFor(PlaylistRepository)
final playlistRepositoryProvider =
    AutoDisposeStreamNotifierProvider<
      PlaylistRepository,
      List<Playlist>
    >.internal(
      PlaylistRepository.new,
      name: r'playlistRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$playlistRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PlaylistRepository = AutoDisposeStreamNotifier<List<Playlist>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
