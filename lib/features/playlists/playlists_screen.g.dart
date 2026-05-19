// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlists_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$playlistTracksHash() => r'a11ab634b5c59e3e42883064413ea8bff702118b';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [playlistTracks].
@ProviderFor(playlistTracks)
const playlistTracksProvider = PlaylistTracksFamily();

/// See also [playlistTracks].
class PlaylistTracksFamily
    extends Family<AsyncValue<List<PlaylistTrackEntry>>> {
  /// See also [playlistTracks].
  const PlaylistTracksFamily();

  /// See also [playlistTracks].
  PlaylistTracksProvider call(int playlistId) {
    return PlaylistTracksProvider(playlistId);
  }

  @override
  PlaylistTracksProvider getProviderOverride(
    covariant PlaylistTracksProvider provider,
  ) {
    return call(provider.playlistId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'playlistTracksProvider';
}

/// See also [playlistTracks].
class PlaylistTracksProvider
    extends AutoDisposeFutureProvider<List<PlaylistTrackEntry>> {
  /// See also [playlistTracks].
  PlaylistTracksProvider(int playlistId)
    : this._internal(
        (ref) => playlistTracks(ref as PlaylistTracksRef, playlistId),
        from: playlistTracksProvider,
        name: r'playlistTracksProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$playlistTracksHash,
        dependencies: PlaylistTracksFamily._dependencies,
        allTransitiveDependencies:
            PlaylistTracksFamily._allTransitiveDependencies,
        playlistId: playlistId,
      );

  PlaylistTracksProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.playlistId,
  }) : super.internal();

  final int playlistId;

  @override
  Override overrideWith(
    FutureOr<List<PlaylistTrackEntry>> Function(PlaylistTracksRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PlaylistTracksProvider._internal(
        (ref) => create(ref as PlaylistTracksRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        playlistId: playlistId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<PlaylistTrackEntry>> createElement() {
    return _PlaylistTracksProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PlaylistTracksProvider && other.playlistId == playlistId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, playlistId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PlaylistTracksRef
    on AutoDisposeFutureProviderRef<List<PlaylistTrackEntry>> {
  /// The parameter `playlistId` of this provider.
  int get playlistId;
}

class _PlaylistTracksProviderElement
    extends AutoDisposeFutureProviderElement<List<PlaylistTrackEntry>>
    with PlaylistTracksRef {
  _PlaylistTracksProviderElement(super.provider);

  @override
  int get playlistId => (origin as PlaylistTracksProvider).playlistId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
