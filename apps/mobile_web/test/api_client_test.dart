import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeyabo/core/network/api_client.dart';
import 'support.dart';

void main() {
  test('maps API errors to readable messages', () async {
    final api = fakeApi((o) => (status: 409, body: {'error': {'code': 'CONFLICT', 'message': 'Email or username already in use'}}));
    expect(() => api.post('/auth/register'), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Email or username already in use').having((e) => e.status, 'status', 409)));
  });

  test('401 triggers one refresh, retries with the new token, and concurrent calls share the refresh', () async {
    final store = TokenStore(MemStorage())..access = 'old'..refresh = 'r1';
    var refreshes = 0;
    final api = fakeApi((o) {
      if (o.path == '/auth/refresh') { refreshes++; return (status: 200, body: {'accessToken': 'new', 'refreshToken': 'r2'}); }
      return o.headers['Authorization'] == 'Bearer new' ? (status: 200, body: {'ok': true}) : (status: 401, body: {'error': {'message': 'expired'}});
    }, store: store);
    final results = await Future.wait([api.get('/a'), api.get('/b'), api.get('/c')]);
    expect(results.every((r) => r['ok'] == true), true);
    expect(refreshes, 1); // rotating refresh tokens would break if this raced
    expect(store.refresh, 'r2');
  });

  test('a failed refresh signs the user out and clears tokens', () async {
    final store = TokenStore(MemStorage())..access = 'old'..refresh = 'bad';
    var signedOut = false;
    final api = fakeApi((o) => (status: 401, body: {'error': {'message': 'nope'}}), store: store, onSignedOut: () => signedOut = true);
    await expectLater(api.get('/me'), throwsA(isA<ApiException>()));
    expect(signedOut, true); expect(store.access, isNull); expect(store.refresh, isNull);
  });

  test('connection errors become a friendly message', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = _Failing();
    final api = ApiClient(TokenStore(MemStorage()), dio: dio);
    await expectLater(api.get('/x'), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('Cannot reach'))));
  });
}

class _Failing implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, s, c) async => throw DioException.connectionError(requestOptions: o, reason: 'down');
  @override
  void close({bool force = false}) {}
}
