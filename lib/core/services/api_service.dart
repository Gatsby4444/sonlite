import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'api_service.g.dart';

const _baseUrl = 'http://10.0.2.2:8000'; // localhost depuis l'émulateur Android

@riverpod
ApiService apiService(Ref ref) => ApiService();

class ApiService {
  final _storage = const FlutterSecureStorage();
  late final Dio dio;

  ApiService() {
    dio = Dio(BaseOptions(baseUrl: _baseUrl, connectTimeout: const Duration(seconds: 10)));
    dio.interceptors.add(_AuthInterceptor(_storage, dio));
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    final res = await dio.post('/auth/login', data: {'email': email, 'password': password});
    await _saveTokens(res.data);
  }

  Future<void> register(String email, String username, String password) async {
    final res = await dio.post('/auth/register', data: {
      'email': email,
      'username': username,
      'password': password,
    });
    await _saveTokens(res.data);
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await dio.get('/auth/me');
    return res.data as Map<String, dynamic>;
  }

  // ── Manifest yt-dlp ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getYtDlpManifest() async {
    final res = await dio.get('/api/ytdlp/manifest');
    return res.data as Map<String, dynamic>;
  }

  Future<void> deviceCheckin({
    required String deviceId,
    String? ytdlpVersion,
    String? appVersion,
  }) async {
    await dio.post('/api/device/checkin', data: {
      'device_id': deviceId,
      'ytdlp_version': ytdlpVersion,
      'app_version': appVersion,
    });
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    await _storage.write(key: 'access_token', value: data['access_token'] as String);
    await _storage.write(key: 'refresh_token', value: data['refresh_token'] as String);
  }
}

class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  final Dio _dio;
  bool _refreshing = false;

  _AuthInterceptor(this._storage, this._dio);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_refreshing) {
      _refreshing = true;
      try {
        final refresh = await _storage.read(key: 'refresh_token');
        if (refresh != null) {
          final res = await _dio.post(
            '/auth/refresh',
            data: {'refresh_token': refresh},
            options: Options(headers: {}), // pas d'intercepteur sur ce call
          );
          await _storage.write(key: 'access_token', value: res.data['access_token'] as String);
          await _storage.write(key: 'refresh_token', value: res.data['refresh_token'] as String);

          err.requestOptions.headers['Authorization'] = 'Bearer ${res.data['access_token']}';
          final retried = await _dio.fetch(err.requestOptions);
          handler.resolve(retried);
          return;
        }
      } catch (_) {
        await _storage.deleteAll();
      } finally {
        _refreshing = false;
      }
    }
    handler.next(err);
  }
}
