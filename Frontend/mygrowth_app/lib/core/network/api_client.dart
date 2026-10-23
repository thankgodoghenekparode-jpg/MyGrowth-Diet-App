import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// A typed API failure raised by [ApiClient].
class ApiException implements Exception {
  ApiException(
    this.statusCode,
    this.code,
    this.message, {
    this.details,
    this.isNetworkError = false,
  });

  final int statusCode;
  final String code;
  final String message;
  final dynamic details;
  final bool isNetworkError;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isValidationError => statusCode == 400 || statusCode == 422;
  bool get isConflict => statusCode == 409;
  bool get isServer => statusCode >= 500;

  /// First field-level validation message, if the backend returned details.
  String? get fieldError {
    if (details is Map<String, dynamic>) {
      for (final value in details!.values) {
        if (value is List && value.isNotEmpty && value.first is String) {
          return value.first as String;
        }
        if (value is String) return value;
      }
    }
    if (details is List && details!.isNotEmpty) {
      final first = details!.first;
      if (first is String) return first;
      if (first is Map<String, dynamic> && first['message'] is String) {
        return first['message'] as String;
      }
    }
    return null;
  }

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

typedef TokenReader = Future<String?> Function();
typedef TokenRefresher = Future<bool> Function();

/// Lightweight REST client for the MyGrowth backend.
///
/// - Attaches the bearer access token to every request.
/// - On a 401, transparently attempts a single refresh-and-retry.
/// - Maps the backend's `{error:{code,message,details}}` envelope to
///   [ApiException] with human-readable messages.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String baseUrl;

  static const _accessKey = 'mgdp.accessToken';
  static const _refreshKey = 'mgdp.refreshToken';

  Future<void> Function()? onSessionExpired;
  Future<void> Function(String accessToken)? onTokensUpdated;

  String? _accessToken;
  String? _refreshToken;
  bool _refreshing = false;
  final List<Completer<void>> _waiters = [];

  String? get accessToken => _accessToken;
  bool get hasSession => _accessToken != null;

  void close() => _client.close();

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_accessKey);
    _refreshToken = prefs.getString(_refreshKey);
  }

  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
  }) async {
    _accessToken = accessToken;
    if (refreshToken != null) _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, accessToken);
    if (refreshToken != null) await prefs.setString(_refreshKey, refreshToken);
    final cb = onTokensUpdated;
    if (cb != null) await cb(accessToken);
  }

  Future<void> clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }

  // ---------------------------------------------------------------- verbs

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path, {Object? body}) =>
      _send('DELETE', path, body: body);

  /// Multipart upload of in-memory bytes.
  ///
  /// [onProgress] receives coarse phases (0 while preparing, 0.35 before the
  /// request is sent, 1.0 on completion) because the file is buffered before
  /// sending to guarantee large uploads don't block the UI isolate.
  Future<dynamic> upload(
    String path, {
    required List<int> bytes,
    required String fieldName,
    required String filename,
    String? contentType,
    Map<String, String> fields = const {},
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0);
    final uri = _resolve(path, null);
    final multipart = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers())
      ..files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: filename,
          contentType:
              contentType == null ? null : MediaType.parse(contentType),
        ),
      );
    fields.forEach((key, value) => multipart.fields[key] = value);

    final body = await multipart.finalize().toBytes();
    final request = http.Request('POST', uri)
      ..headers.addAll(multipart.headers)
      ..bodyBytes = body;
    onProgress?.call(0.35);

    http.Response response;
    try {
      final streamed = await _client
          .send(request)
          .timeout(const Duration(minutes: 5));
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException(
        0,
        'timeout',
        'The upload took too long. Please try again with a smaller file.',
        isNetworkError: true,
      );
    } catch (e) {
      throw ApiException(
        0,
        'network',
        'Unable to reach the server during upload. Check your connection.',
        isNetworkError: true,
      );
    }
    onProgress?.call(1);
    return _handleResponse(response);
  }

  // -------------------------------------------------------------- helpers

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Uri _resolve(String path, Map<String, String>? query) {
    final base = Uri.parse(baseUrl);
    var uri = base.replace(path: _join(base.path, path));
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...query});
    }
    return uri;
  }

  String _join(String basePath, String path) {
    final left = basePath.endsWith('/')
        ? basePath.substring(0, basePath.length - 1)
        : basePath;
    final right = path.startsWith('/') ? path : '/$path';
    return '$left$right';
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool retried = false,
  }) async {
    final uri = _resolve(path, query);
    final jsonBody = body == null ? null : jsonEncode(body);

    http.Response response;
    try {
      final request = http.Request(method, uri)
        ..headers.addAll(_headers());
      if (jsonBody != null) request.body = jsonBody;
      final streamed = await _client.send(request);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException(
        0,
        'timeout',
        'The request took too long. Please check your connection and try again.',
        isNetworkError: true,
      );
    } catch (e) {
      debugPrint('Network error on $method ${uri.path}: $e');
      throw ApiException(
        0,
        'network',
        'Unable to reach the server. Check your internet connection and try again.',
        isNetworkError: true,
      );
    }

    if (response.statusCode == 401 && !retried && path != '/auth/refresh') {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _send(method, path, query: query, body: body, retried: true);
      }
      final cb = onSessionExpired;
      if (cb != null) unawaited(cb());
    }

    return _handleResponse(response);
  }

  Future<bool> _tryRefresh() async {
    if (_refreshToken == null) return false;
    if (_refreshing) {
      final completer = Completer<void>();
      _waiters.add(completer);
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {},
      );
      return _accessToken != null;
    }
    _refreshing = true;
    try {
      final uri = _resolve('/auth/refresh', null);
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final access = data['data']?['accessToken'] as String?;
        final refresh = data['data']?['refreshToken'] as String?;
        if (access != null) {
          await saveSession(accessToken: access, refreshToken: refresh);
          return true;
        }
      }
      await clearSession();
      return false;
    } catch (_) {
      return false;
    } finally {
      _refreshing = false;
      for (final w in _waiters) {
        if (!w.isCompleted) w.complete();
      }
      _waiters.clear();
    }
  }

  dynamic _handleResponse(http.Response response) {
    final raw = utf8.decode(response.bodyBytes, allowMalformed: true);
    dynamic json;
    if (raw.trim().isNotEmpty) {
      try {
        json = jsonDecode(raw);
      } catch (_) {
        json = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (json is Map<String, dynamic> && json.containsKey('data')) {
        return json['data'];
      }
      return json;
    }

    String code = 'unknown';
    String message =
        'Something went wrong. Please try again. (${response.statusCode})';
    dynamic details;
    if (json is Map<String, dynamic>) {
      final err = json['error'];
      if (err is Map<String, dynamic>) {
        code = err['code']?.toString() ?? code;
        message = err['message']?.toString() ?? message;
        details = err['details'];
      } else if (err is String) {
        message = err;
      }
    }
    return _raise(
      response.statusCode,
      code,
      message,
      details,
    );
  }

  Never _raise(int status, String code, String message, dynamic details) {
    throw ApiException(status, code, message, details: details);
  }
}
