import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../services/app_exceptions.dart';
import '../../../services/quota_service.dart';
import '../domain/random_image.dart';
import 'veil_api_client.dart';

final randomImageRepositoryProvider = Provider<RandomImageRepository>((ref) {
  return RandomImageRepository(
    ref.watch(veilApiClientProvider),
    ref.read(quotaControllerProvider.notifier),
  );
});

class RandomImageRepository {
  RandomImageRepository(this._apiClient, this._quotaController);

  final VeilApiClient _apiClient;
  final QuotaController _quotaController;

  Future<RandomImage> fetchRandom({String? tag}) {
    return _quotaGuardedFetch(
      () => _apiClient.random(tag: tag),
      sourceTag: tag,
    );
  }

  Future<RandomImage> fetchImageById(int imageId, {String? sourceTag}) {
    return _quotaGuardedFetch(
      () => _apiClient.imageById(imageId),
      sourceTag: sourceTag,
    );
  }

  Future<RandomImage> _quotaGuardedFetch(
    Future<VeilImageResponse> Function() request, {
    String? sourceTag,
  }) async {
    final allowed = await _quotaController.tryConsumeRemoteRequest();
    if (!allowed) {
      throw const QuotaExceededException('请求额度已用尽');
    }

    try {
      final response = await request();
      return _persistResponse(response, sourceTag: sourceTag);
    } on ServerLockoutException {
      await _quotaController.startServerLockout();
      rethrow;
    }
  }

  Future<RandomImage> _persistResponse(
    VeilImageResponse response, {
    String? sourceTag,
  }) async {
    final cacheDirectory = Directory(
      p.join((await getTemporaryDirectory()).path, 'nice_view_images'),
    );
    await cacheDirectory.create(recursive: true);

    final extension = extensionForContentType(response.contentType);
    final token = response.imageId?.toString() ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final file = File(
      p.join(
        cacheDirectory.path,
        'nice_view_${token}_${DateTime.now().millisecondsSinceEpoch}$extension',
      ),
    );
    await file.writeAsBytes(response.bytes, flush: true);
    if (kDebugMode) {
      debugPrint(
        '[NiceView][Repository] saved ${response.bytes.length} bytes to '
        '${file.path}',
      );
    }

    return RandomImage(
      localFilePath: file.path,
      imageId: response.imageId,
      galleryId: response.galleryId,
      contentType: response.contentType,
      sourceTag: sourceTag,
      fetchedAt: DateTime.now(),
    );
  }
}

String extensionForContentType(String? contentType) {
  final normalized = contentType?.split(';').first.trim().toLowerCase();
  return switch (normalized) {
    'image/png' => '.png',
    'image/webp' => '.webp',
    'image/gif' => '.gif',
    _ => '.jpg',
  };
}
