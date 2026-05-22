// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$tracksDaoHash() => r'52398e67accf35e740aa8ff821756c5e2f738707';

/// See also [tracksDao].
@ProviderFor(tracksDao)
final tracksDaoProvider = Provider<TracksDao>.internal(
  tracksDao,
  name: r'tracksDaoProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$tracksDaoHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TracksDaoRef = ProviderRef<TracksDao>;
String _$trackRepositoryHash() => r'2b49b57d89f410805709a88a3c9cfe596b906654';

/// See also [TrackRepository].
@ProviderFor(TrackRepository)
final trackRepositoryProvider =
    AutoDisposeStreamNotifierProvider<TrackRepository, List<Track>>.internal(
      TrackRepository.new,
      name: r'trackRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$trackRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TrackRepository = AutoDisposeStreamNotifier<List<Track>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
