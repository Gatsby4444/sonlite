import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/player_providers.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    final playbackAsync = ref.watch(playbackStateProvider);

    return mediaItemAsync.when(
      data: (item) {
        if (item == null) return const SizedBox.shrink();
        final isPlaying = playbackAsync.valueOrNull?.playing ?? false;
        final handler = ref.read(audioHandlerProvider);

        return GestureDetector(
          onTap: () => context.push('/player'),
          child: Container(
            height: 64,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: item.artUri != null
                      ? Image.file(
                          File(item.artUri!.toFilePath()),
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, s) => const _DefaultArt(),
                        )
                      : const _DefaultArt(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(item.artist ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: isPlaying ? handler.pause : handler.play,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: handler.skipToNext,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}

class _DefaultArt extends StatelessWidget {
  const _DefaultArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(Icons.music_note,
          color: Theme.of(context).colorScheme.onPrimaryContainer),
    );
  }
}
