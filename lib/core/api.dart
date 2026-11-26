import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Base URL of the AgroBid API. Override with
/// `--dart-define=API_BASE_URL=http://127.0.0.1:8000` for a local backend.
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://agrobidbackend.vercel.app');

class ApiException implements Exception {
  ApiException(this.message, {this.status, this.fieldErrors = const []});

  final String message;
  final int? status;
  final List<String> fieldErrors;

  @override
  String toString() => fieldErrors.isEmpty ? message : '$message\n${fieldErrors.join('\n')}';
}

/// Where tokens live. Browser storage on the web, memory in tests.
abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> clear();
}

class PrefsTokenStore implements TokenStore {
  static const _prefix = 'agrobid_admin.';

  @override
  Future<String?> read(String key) async => (await SharedPreferences.getInstance()).getString(_prefix + key);

  @override
  Future<void> write(String key, String value) async => (await SharedPreferences.getInstance()).setString(_prefix + key, value);

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      await prefs.remove(key);
    }
  }
}

class MemoryTokenStore implements TokenStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> clear() async => _values.clear();
}

/// Thin wrapper over the AgroBid REST API. Every JSON call returns the `data`
/// field of the `{success, message, data}` envelope or throws [ApiException].
class ApiClient {
  ApiClient({String? baseUrl, TokenStore? store})
      : store = store ?? PrefsTokenStore(),
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? apiBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        )) {
    _dio.interceptors.add(QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await this.store.read('access_token');
        if (token != null && !options.headers.containsKey('Authorization')) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final path = error.requestOptions.path;
        final retried = error.requestOptions.extra['retried'] == true;
        // Login, refresh and logout answer 401 for bad input; never refresh on those.
        if (error.response?.statusCode != 401 || path.contains('/auth/') || retried) {
          return handler.next(error);
        }
        final refreshed = await _refresh();
        if (!refreshed) {
          await this.store.clear();
          onSessionExpired?.call();
          return handler.next(error);
        }
        final retry = error.requestOptions
          ..extra['retried'] = true
          ..headers['Authorization'] = 'Bearer ${await this.store.read('access_token')}';
        try {
          handler.resolve(await _dio.fetch(retry));
        } on DioException catch (e) {
          handler.next(e);
        }
      },
    ));
  }

  final TokenStore store;
  final Dio _dio;

  /// Called when the refresh token is no longer valid; the app returns to login.
  void Function()? onSessionExpired;

  String get baseUrl => _dio.options.baseUrl;

  Future<bool> _refresh() async {
    final refresh = await store.read('refresh_token');
    if (refresh == null) return false;
    try {
      final res = await Dio(BaseOptions(baseUrl: baseUrl)).post('/api/v1/auth/refresh', data: {'refresh_token': refresh});
      final data = res.data['data'] as Map<String, dynamic>;
      await saveTokens(data['access_token'] as String, data['refresh_token'] as String);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveTokens(String access, String refresh) async {
    await store.write('access_token', access);
    await store.write('refresh_token', refresh);
  }

  Future<T> _send<T>(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      final body = res.data;
      if (body is Map<String, dynamic> && body.containsKey('success')) return body['data'] as T;
      return body as T;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  ApiException _toApiException(DioException e) {
    final res = e.response;
    if (res == null) {
      return ApiException('Cannot reach the AgroBid server ($baseUrl). Check your internet connection.');
    }
    final body = res.data;
    if (body is Map<String, dynamic>) {
      final errors = body['errors'];
      final fields = errors is List
          ? errors.whereType<Map>().map((m) => '${m['field'] ?? ''}: ${m['message'] ?? ''}'.trim()).toList()
          : <String>[];
      return ApiException((body['message'] ?? body['detail'] ?? 'Request failed (${res.statusCode})').toString(), status: res.statusCode, fieldErrors: fields);
    }
    return ApiException('Request failed (${res.statusCode})', status: res.statusCode);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: _clean(query)));

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) =>
      _send(() => _dio.post(path, data: body, queryParameters: _clean(query)));

  Future<dynamic> put(String path, {Object? body}) => _send(() => _dio.put(path, data: body));

  Future<dynamic> delete(String path, {Object? body}) => _send(() => _dio.delete(path, data: body));

  /// Downloads a photo or document as raw bytes.
  Future<Uint8List> bytes(String path) async {
    try {
      final res = await _dio.get<List<int>>(path, options: Options(responseType: ResponseType.bytes));
      return Uint8List.fromList(res.data ?? const []);
    } on DioException catch (e) {
      // Error bodies arrive as bytes too; decode the JSON envelope for its message.
      final raw = e.response?.data;
      if (raw is List<int>) {
        try {
          final body = jsonDecode(utf8.decode(raw));
          if (body is Map) throw ApiException((body['message'] ?? 'Could not load the file').toString(), status: e.response?.statusCode);
        } on FormatException {
          // Not JSON; fall through to the generic message.
        }
        throw ApiException('Could not load the file', status: e.response?.statusCode);
      }
      throw _toApiException(e);
    }
  }

  Future<dynamic> upload(String path, {required List<int> bytes, required String filename, Map<String, String> fields = const {}, String method = 'POST'}) {
    final form = FormData.fromMap({...fields, 'file': MultipartFile.fromBytes(bytes, filename: filename)});
    return _send(() => _dio.request(path, data: form, options: Options(method: method)));
  }

  static Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    return {
      for (final entry in query.entries)
        if (entry.value != null && entry.value.toString().isNotEmpty) entry.key: entry.value,
    };
  }
}
