import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/services/youtube_service.dart';

part 'downloader_screen.g.dart';

@riverpod
class DownloadQueue extends _$DownloadQueue {
  @override
  List<DownloadItem> build() => [];

  Future<void> addDownload(String url, WidgetRef ref) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    state = [...state, DownloadItem(id: id, url: url)];

    final service = ref.read(youtubeServiceProvider);
    await service.downloadAudio(url, (progress) {
      state = state.map((item) {
        if (item.id == id) return item.copyWith(progress: progress);
        return item;
      }).toList();
    });
  }

  void clear() {
    state = state
        .where((i) => i.progress.status != DownloadStatus.done &&
            i.progress.status != DownloadStatus.error)
        .toList();
  }
}

class DownloadItem {
  final int id;
  final String url;
  final DownloadProgress progress;

  DownloadItem({
    required this.id,
    required this.url,
    this.progress = DownloadProgress.idle,
  });

  DownloadItem copyWith({DownloadProgress? progress}) =>
      DownloadItem(id: id, url: url, progress: progress ?? this.progress);
}

class DownloaderScreen extends ConsumerStatefulWidget {
  const DownloaderScreen({super.key});

  @override
  ConsumerState<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends ConsumerState<DownloaderScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(downloadQueueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Télécharger'),
        actions: [
          if (queue.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Effacer terminés',
              onPressed: () => ref.read(downloadQueueProvider.notifier).clear(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Champ URL
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'URL YouTube (vidéo ou playlist)',
                      prefixIcon: const Icon(Icons.link),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _controller.clear(),
                      ),
                    ),
                    onSubmitted: (_) => _startDownload(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Télécharger'),
                  onPressed: _startDownload,
                ),
              ],
            ),
          ),

          // File d'attente
          Expanded(
            child: queue.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_download_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text('Colle une URL YouTube pour télécharger',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: queue.length,
                    itemBuilder: (context, i) =>
                        _DownloadTile(item: queue[i]),
                  ),
          ),
        ],
      ),
    );
  }

  void _startDownload() {
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    _controller.clear();
    ref.read(downloadQueueProvider.notifier).addDownload(url, ref);
  }
}

class _DownloadTile extends StatelessWidget {
  final DownloadItem item;
  const _DownloadTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final progress = item.progress;
    final status = progress.status;

    return ListTile(
      leading: _statusIcon(context, status),
      title: Text(
        progress.title ?? _shortUrl(item.url),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status == DownloadStatus.downloading ||
              status == DownloadStatus.processing)
            LinearProgressIndicator(
              value: progress.progress,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            )
          else
            Text(_statusText(status, progress.error)),
        ],
      ),
      isThreeLine: false,
    );
  }

  Widget _statusIcon(BuildContext context, DownloadStatus status) {
    switch (status) {
      case DownloadStatus.idle:
      case DownloadStatus.fetching:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case DownloadStatus.downloading:
      case DownloadStatus.processing:
        return const Icon(Icons.downloading);
      case DownloadStatus.done:
        return Icon(Icons.check_circle,
            color: Theme.of(context).colorScheme.primary);
      case DownloadStatus.error:
        return Icon(Icons.error_outline,
            color: Theme.of(context).colorScheme.error);
    }
  }

  String _statusText(DownloadStatus status, String? error) {
    switch (status) {
      case DownloadStatus.idle:
        return 'En attente...';
      case DownloadStatus.fetching:
        return 'Récupération des infos...';
      case DownloadStatus.downloading:
        return 'Téléchargement en cours...';
      case DownloadStatus.processing:
        return 'Finalisation...';
      case DownloadStatus.done:
        return 'Téléchargé';
      case DownloadStatus.error:
        return 'Erreur: ${error ?? 'inconnue'}';
    }
  }

  String _shortUrl(String url) =>
      url.length > 50 ? '${url.substring(0, 47)}...' : url;
}
