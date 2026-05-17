import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import 'api_service.dart';

part 'startup_service.g.dart';

@riverpod
StartupService startupService(Ref ref) => StartupService(ref);

class StartupService {
  final Ref _ref;
  final _storage = const FlutterSecureStorage();
  static const _deviceIdKey = 'device_id';
  static const _ytdlpVersionKey = 'ytdlp_installed_version';

  StartupService(this._ref);

  Future<void> run() async {
    final api = _ref.read(apiServiceProvider);
    final isLoggedIn = await api.isLoggedIn();
    if (!isLoggedIn) return;

    try {
      final deviceId = await _getOrCreateDeviceId();
      final ytdlpVersion = await _getInstalledYtDlpVersion();

      await api.deviceCheckin(
        deviceId: deviceId,
        ytdlpVersion: ytdlpVersion,
        appVersion: '1.0.0',
      );

      final manifest = await api.getYtDlpManifest();
      await _handleManifest(manifest);
    } catch (e) {
      debugPrint('[startup] checkin failed (serveur inaccessible?): $e');
    }
  }

  Future<void> _handleManifest(Map<String, dynamic> manifest) async {
    final stable = manifest['stable'] as Map<String, dynamic>?;
    if (stable == null) return;

    final remoteVersion = stable['version'] as String?;
    final forceUpdate = stable['force_update'] as bool? ?? false;
    final installedVersion = await _storage.read(key: _ytdlpVersionKey);

    if (forceUpdate || (remoteVersion != null && remoteVersion != installedVersion)) {
      debugPrint('[startup] Nouvelle version yt-dlp disponible : $remoteVersion (force=$forceUpdate)');
      // La notification UI est gérée via un provider séparé
      await _storage.write(key: 'ytdlp_update_available', value: remoteVersion ?? '');
      await _storage.write(key: 'ytdlp_update_url', value: stable['url'] as String? ?? '');
      await _storage.write(key: 'ytdlp_force_update', value: forceUpdate.toString());
    }
  }

  Future<String> _getOrCreateDeviceId() async {
    var id = await _storage.read(key: _deviceIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await _storage.write(key: _deviceIdKey, value: id);
    }
    return id;
  }

  Future<String?> _getInstalledYtDlpVersion() async {
    // Essayer d'obtenir la version du binaire embarqué
    try {
      final docs = await getApplicationDocumentsDirectory();
      final libDir = Directory('${docs.parent.path}/lib');
      final ytdlpPath = '${libDir.path}/libytdlp.so';

      if (await File(ytdlpPath).exists()) {
        final result = await Process.run(ytdlpPath, ['--version']);
        if (result.exitCode == 0) {
          return (result.stdout as String).trim();
        }
      }
    } catch (_) {}
    return await _storage.read(key: _ytdlpVersionKey);
  }
}
