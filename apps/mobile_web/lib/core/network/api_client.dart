import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';
import '../l10n.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status, this.code, this.fields});
  final String message;
  final int? status;
  final String? code;
  final Map<String, dynamic>? fields;
  @override
  String toString() => message;
}

/// Persists the refresh/access tokens (Keychain / Keystore; encrypted storage on web).
class TokenStore {
  TokenStore([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;
  String? access, refresh;

  Future<void> load() async { access = await _s.read(key: 'access'); refresh = await _s.read(key: 'refresh'); }
  Future<void> save(String a, String r) async { access = a; refresh = r; await _s.write(key: 'access', value: a); await _s.write(key: 'refresh', value: r); }
  Future<void> clear() async { access = refresh = null; await _s.delete(key: 'access'); await _s.delete(key: 'refresh'); }
}

/// Dio wrapper: bearer auth, one shared refresh on 401 (rotating refresh tokens must not race), friendly errors.
class ApiClient {
  ApiClient(this.tokens, {Dio? dio, this.onSignedOut, String Function()? language}) : _language = language ?? (() => fallbackLanguage), dio = dio ?? Dio(BaseOptions(baseUrl: apiBase, connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 30))) {
    this.dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      o.headers['Accept-Language'] = _language(); // the API answers error messages in this language
      final t = tokens.access;
      if (t != null && o.extra['noAuth'] != true) o.headers['Authorization'] = 'Bearer $t';
      h.next(o);
    }, onError: (e, h) async {
      final isAuthCall = e.requestOptions.path.startsWith('/auth/');
      if (e.response?.statusCode == 401 && !isAuthCall && tokens.refresh != null && e.requestOptions.extra['retried'] != true) {
        if (await _refreshOnce()) {
          final o = e.requestOptions..extra['retried'] = true;
          try { return h.resolve(await this.dio.fetch(o)); } on DioException catch (e2) { return h.next(e2); }
        }
      }
      h.next(e);
    }));
  }

  final Dio dio;
  final TokenStore tokens;
  final void Function()? onSignedOut;
  final String Function() _language;
  Future<bool>? _refreshing;

  /// Strings in the app's current language, for messages created outside widgets.
  AppLocalizations get strings => stringsFor(_language());

  /// Renews the token pair (shared with 401 handling, so concurrent callers never race). False = signed out.
  Future<bool> refreshTokens() => _refreshOnce();
  Future<bool> _refreshOnce() => _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  Future<bool> _doRefresh() async {
    try {
      final r = await dio.post('/auth/refresh', data: {'refreshToken': tokens.refresh}, options: Options(extra: {'noAuth': true}));
      await tokens.save(r.data['accessToken'], r.data['refreshToken']);
      return true;
    } catch (_) {
      await tokens.clear();
      onSignedOut?.call();
      return false;
    }
  }

  ApiException _wrap(DioException e) {
    final d = e.response?.data;
    if (d is Map && d['error'] is Map) {
      final er = d['error'] as Map;
      return ApiException(er['message']?.toString() ?? 'Request failed', status: e.response?.statusCode, code: er['code']?.toString(), fields: (er['fields'] as Map?)?.cast<String, dynamic>());
    }
    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) return ApiException(strings.errorNetwork);
    return ApiException(strings.errorGeneric('${e.response?.statusCode ?? 'network'}'), status: e.response?.statusCode);
  }

  Future<dynamic> _run(Future<Response> Function() f) async {
    try { return (await f()).data; } on DioException catch (e) { throw _wrap(e); }
  }
  Future<dynamic> get(String p, {Map<String, dynamic>? q}) => _run(() => dio.get(p, queryParameters: q));
  Future<dynamic> post(String p, {Object? body}) => _run(() => dio.post(p, data: body));
  Future<dynamic> put(String p, {Object? body}) => _run(() => dio.put(p, data: body));
  Future<dynamic> patch(String p, {Object? body}) => _run(() => dio.patch(p, data: body));
  Future<dynamic> delete(String p, {Object? body}) => _run(() => dio.delete(p, data: body));
}
