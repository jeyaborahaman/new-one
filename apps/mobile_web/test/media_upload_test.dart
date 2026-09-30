import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jeyabo/core/media_upload.dart';
import 'package:jeyabo/core/network/api_client.dart';
import 'support.dart';

void main() {
  final bytes = Uint8List.fromList(List.generate(2048, (i) => i % 251));
  PickedMedia media() => PickedMedia(XFile.fromData(bytes, name: 'a.png', mimeType: 'image/png'), 'image', 'image/png', bytes.length);

  test('uploads via presigned URL without leaking the bearer token, then confirms', () async {
    final apiCalls = <String>[];
    final store = TokenStore(MemStorage())..access = 'secret-access'..refresh = 'r';
    final api = fakeApi((o) {
      apiCalls.add('${o.method} ${o.path}');
      if (o.path == '/media/uploads') {
        expect(o.data, {'kind': 'image', 'mime': 'image/png', 'size': 2048});
        return (status: 201, body: {'media_id': 42, 'upload_url': 'https://storage.test/u/1/x.png?sig=abc'});
      }
      return (status: 200, body: {'id': 42, 'status': 'ready'});
    }, store: store);

    Map<String, dynamic>? storageHeaders; String? storageUrl; var progressCalls = 0;
    final storageAdapter = FakeAdapter((o) { storageUrl = o.uri.toString(); storageHeaders = o.headers; return (status: 200, body: {}); });
    final storage = Dio()..httpClientAdapter = storageAdapter;

    final id = await uploadMedia(api, media(), storage: storage, onProgress: (_) => progressCalls++);
    expect(id, 42);
    expect(apiCalls, ['POST /media/uploads', 'POST /media/42/complete']);
    expect(storageUrl, 'https://storage.test/u/1/x.png?sig=abc');
    expect(storageHeaders!['Content-Type'], 'image/png');
    expect(storageHeaders!.containsKey('Authorization'), false); // never send our token to the storage host
  });

  test('a rejected upload slot surfaces the API message and never calls complete', () async {
    final calls = <String>[];
    final api = fakeApi((o) { calls.add(o.path); return (status: 400, body: {'error': {'code': 'BAD_REQUEST', 'message': 'File too large (max 10 MB)'}}); });
    await expectLater(uploadMedia(api, media()), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('too large'))));
    expect(calls, ['/media/uploads']);
  });

  test('a failed storage PUT becomes a friendly error and is not confirmed', () async {
    final calls = <String>[];
    final api = fakeApi((o) { calls.add(o.path); return (status: 201, body: {'media_id': 1, 'upload_url': 'https://storage.test/x'}); });
    final storage = Dio()..httpClientAdapter = FakeAdapter((o) => (status: 403, body: {}));
    await expectLater(uploadMedia(api, media(), storage: storage), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('Upload failed'))));
    expect(calls, ['/media/uploads']); // complete was never called
  });
}
