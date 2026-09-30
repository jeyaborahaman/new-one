import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jeyabo/core/network/api_client.dart';

/// In-memory secure storage so tests never touch the platform channel.
class MemStorage extends FlutterSecureStorage {
  MemStorage() : super();
  final m = <String, String>{};
  @override
  Future<String?> read({required String key, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async => m[key];
  @override
  Future<void> write({required String key, required String? value, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async { value == null ? m.remove(key) : m[key] = value; }
  @override
  Future<void> delete({required String key, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async { m.remove(key); }
}

typedef Handler = ({int status, Object body}) Function(RequestOptions o);

/// Routes Dio requests to a Dart function so screens can be tested without a server.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  final Handler handler;
  final calls = <String>[];
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    calls.add('${o.method} ${o.path}');
    final r = handler(o);
    return ResponseBody.fromString(jsonEncode(r.body), r.status, headers: {Headers.contentTypeHeader: ['application/json']});
  }
  @override
  void close({bool force = false}) {}
}

ApiClient fakeApi(Handler h, {TokenStore? store, void Function()? onSignedOut}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test/v1'))..httpClientAdapter = FakeAdapter(h);
  return ApiClient(store ?? TokenStore(MemStorage()), dio: dio, onSignedOut: onSignedOut);
}
