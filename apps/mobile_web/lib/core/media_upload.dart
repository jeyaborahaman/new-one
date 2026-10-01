import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'network/api_client.dart';

/// A file the user picked, plus the details the upload API needs.
class PickedMedia {
  PickedMedia(this.file, this.kind, this.mime, this.size, {this.previewBytes});
  final XFile file;
  final String kind; // image | video
  final String mime;
  final int size;
  final Uint8List? previewBytes; // only for images, to show a preview

  String get name => file.name;

  static Future<PickedMedia?> pick(String kind, {ImageSource source = ImageSource.gallery, ImagePicker? picker}) async {
    final p = picker ?? ImagePicker();
    final f = kind == 'video' ? await p.pickVideo(source: source) : await p.pickImage(source: source, maxWidth: 2048, imageQuality: 88);
    if (f == null) return null;
    final size = await f.length();
    final mime = f.mimeType ?? lookupMimeType(f.name, headerBytes: null) ?? (kind == 'video' ? 'video/mp4' : 'image/jpeg');
    return PickedMedia(f, kind, mime, size, previewBytes: kind == 'image' ? await f.readAsBytes() : null);
  }
}

/// Upload flow: ask the API for a presigned URL, PUT the bytes straight to storage, then confirm.
/// Storage URLs must NOT receive our bearer token, so the PUT uses its own Dio.
Future<int> uploadMedia(ApiClient api, PickedMedia m, {void Function(double)? onProgress, Dio? storage}) async {
  final init = await api.post('/media/uploads', body: {'kind': m.kind, 'mime': m.mime, 'size': m.size});
  final id = init['media_id'] as int;
  final dio = storage ?? Dio();
  try {
    // Web can only send bytes; mobile streams from disk so large videos are not held in memory.
    final Object body = kIsWeb ? await m.file.readAsBytes() : m.file.openRead();
    await dio.put(init['upload_url'] as String, data: body, options: Options(headers: {'Content-Type': m.mime, Headers.contentLengthHeader: m.size}), onSendProgress: (sent, total) { if (onProgress != null && total > 0) onProgress(sent / total); });
  } on DioException catch (e) {
    throw ApiException(e.type == DioExceptionType.connectionError ? api.strings.uploadFailedNetwork : api.strings.uploadFailedCode('${e.response?.statusCode ?? 'network'}'));
  }
  await api.post('/media/$id/complete');
  return id;
}
