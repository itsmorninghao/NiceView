import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/app_exceptions.dart';

final veilApiClientProvider = Provider<VeilApiClient>((ref) {
  return VeilApiClient();
});

class VeilImageResponse {
  const VeilImageResponse({
    required this.bytes,
    required this.contentType,
    this.imageId,
    this.galleryId,
  });

  final List<int> bytes;
  final String? contentType;
  final int? imageId;
  final int? galleryId;
}

class VeilApiClient {
  VeilApiClient() : _client = HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 60);
    _client.idleTimeout = const Duration(seconds: 15);
  }

  static const _host = 'veil.ortlinde.com';
  static const _receiveTimeout = Duration(seconds: 90);

  final HttpClient _client;

  Future<VeilImageResponse> random({String? tag}) {
    return _imageRequest(
      '/v1/random',
      queryParameters: tag == null ? null : {'tag': tag},
    );
  }

  Future<VeilImageResponse> imageById(int imageId) {
    return _imageRequest('/v1/image/$imageId');
  }

  Future<VeilImageResponse> _imageRequest(
    String path, {
    Map<String, Object?>? queryParameters,
  }) async {
    final normalizedQuery = queryParameters?.map(
      (key, value) => MapEntry(key, value?.toString()),
    );
    final uri = Uri.https(_host, path, normalizedQuery);
    _log('GET $uri');

    late final HttpClientResponse response;
    try {
      final request = await _client.getUrl(uri).timeout(_receiveTimeout);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'image/*,*/*;q=0.8')
        ..set(HttpHeaders.userAgentHeader, 'NiceView/1.0');
      response = await request.close().timeout(_receiveTimeout);
    } on TimeoutException catch (error) {
      _log('request timeout: $error');
      throw const NiceViewException('网络请求超时，稍后再试');
    } on SocketException catch (error) {
      _log('socket error: $error');
      throw const NiceViewException('网络连接失败，稍后再试');
    } on HandshakeException catch (error) {
      _log('tls error: $error');
      throw const NiceViewException('安全连接失败，稍后再试');
    } on HttpException catch (error) {
      _log('http error: $error');
      throw NiceViewException(error.message);
    }

    final statusCode = response.statusCode;
    final contentType = response.headers.contentType?.mimeType ??
        response.headers.value(HttpHeaders.contentTypeHeader);
    _log('response $statusCode type=$contentType');

    late final List<int> bytes;
    try {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(_receiveTimeout)) {
        builder.add(chunk);
      }
      bytes = builder.takeBytes();
      _log('received ${bytes.length} bytes');
    } on TimeoutException catch (error) {
      _log('body timeout: $error');
      throw const NiceViewException('图片下载超时，稍后再试');
    } on SocketException catch (error) {
      _log('body socket error: $error');
      throw const NiceViewException('图片下载中断，稍后再试');
    } on HttpException catch (error) {
      _log('body http error: $error');
      throw const NiceViewException('图片下载中断，稍后再试');
    }

    if (statusCode == 429) {
      throw const ServerLockoutException('请求太快了，请稍后再试');
    }
    if (statusCode == 404) {
      throw const ImageNotFoundException('图片不存在');
    }
    if (statusCode < 200 || statusCode >= 300) {
      throw NiceViewException('服务器暂时不可用：$statusCode');
    }

    if (bytes.isEmpty) {
      throw const NiceViewException('图片数据为空');
    }

    if (contentType != null && !contentType.startsWith('image/')) {
      throw const EmptyTagException('该标签暂时没有图片');
    }

    return VeilImageResponse(
      bytes: bytes,
      contentType: contentType,
      imageId: int.tryParse(response.headers.value('x-image-id') ?? ''),
      galleryId: int.tryParse(response.headers.value('x-gallery-id') ?? ''),
    );
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[NiceView][VeilApi] $message');
    }
  }
}
