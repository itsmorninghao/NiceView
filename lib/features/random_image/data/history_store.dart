import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/shared_preferences_provider.dart';
import '../domain/history_image.dart';
import '../domain/random_image.dart';
import 'random_image_repository.dart';

final historyStoreProvider = Provider<HistoryStore>((ref) {
  return HistoryStore(ref.watch(sharedPreferencesProvider));
});

class HistoryStore {
  HistoryStore(this._preferences);

  static const _historyKey = 'nice_view.history_images';
  static const _lastCurrentKey = 'nice_view.last_current_image';
  static const _preloadQueueKey = 'nice_view.preload_queue';
  static const _maxHistory = 30;
  static const _maxPreload = 12;

  final SharedPreferences _preferences;

  Future<List<HistoryImage>> load() async {
    final items = HistoryImage.listFromJsonString(
      _preferences.getString(_historyKey),
    );
    items.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
    return items.take(_maxHistory).toList();
  }

  Future<HistoryImage?> loadLastCurrent() async {
    final value = _preferences.getString(_lastCurrentKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      return HistoryImage.fromJson(
        Map<String, Object?>.from(jsonDecode(value) as Map),
      );
    } catch (_) {
      await _preferences.remove(_lastCurrentKey);
      return null;
    }
  }

  Future<List<HistoryImage>> upsertFromRandomImage(RandomImage image) async {
    final source = File(image.localFilePath);
    if (!await source.exists()) {
      return load();
    }

    final now = DateTime.now();
    final images = await load();
    final existingIndex = image.imageId == null
        ? -1
        : images.indexWhere((item) => item.imageId == image.imageId);
    final historyId = image.imageId?.toString() ??
        'local_${now.microsecondsSinceEpoch}_${source.lengthSync()}';
    final targetPath = await _copyIntoHistoryCache(
      source,
      historyId,
      image.contentType,
    );

    late final HistoryImage currentHistoryImage;
    if (existingIndex >= 0) {
      final existing = images.removeAt(existingIndex);
      if (existing.localFilePath != targetPath) {
        await _deleteFile(existing.localFilePath);
      }
      currentHistoryImage = HistoryImage(
        historyId: existing.historyId,
        localFilePath: targetPath,
        imageId: image.imageId,
        galleryId: image.galleryId,
        contentType: image.contentType,
        sourceTag: image.sourceTag,
        fetchedAt: image.fetchedAt,
        viewedAt: now,
      );
      images.insert(0, currentHistoryImage);
    } else {
      currentHistoryImage = HistoryImage(
        historyId: historyId,
        localFilePath: targetPath,
        imageId: image.imageId,
        galleryId: image.galleryId,
        contentType: image.contentType,
        sourceTag: image.sourceTag,
        fetchedAt: image.fetchedAt,
        viewedAt: now,
      );
      images.insert(0, currentHistoryImage);
    }

    while (images.length > _maxHistory) {
      final removed = images.removeLast();
      await _deleteFile(removed.localFilePath);
    }
    await _save(images);
    await _saveLastCurrent(currentHistoryImage);
    return images;
  }

  Future<List<HistoryImage>> delete(HistoryImage image) async {
    final images = await load();
    images.removeWhere((item) => item.historyId == image.historyId);
    await _deleteFile(image.localFilePath);
    await _removeLastCurrentIfMatches(image);
    await _save(images);
    return images;
  }

  Future<List<HistoryImage>> touch(HistoryImage image) async {
    final images = await load();
    final index =
        images.indexWhere((item) => item.historyId == image.historyId);
    if (index < 0) {
      return images;
    }
    final next = images.removeAt(index).copyWith(viewedAt: DateTime.now());
    images.insert(0, next);
    await _save(images);
    return images;
  }

  Future<List<HistoryImage>> removeMissing(HistoryImage image) async {
    final images = await load();
    images.removeWhere((item) => item.historyId == image.historyId);
    await _removeLastCurrentIfMatches(image);
    await _save(images);
    return images;
  }

  Future<List<RandomImage>> loadPreloadQueue({String? selectedTag}) async {
    final savedImages = await _loadSavedPreloadQueue();
    if (savedImages.isEmpty) {
      return <RandomImage>[];
    }

    final images = <RandomImage>[];
    for (final image in savedImages) {
      if (image.sourceTag != selectedTag) {
        await _deleteFile(image.localFilePath);
        continue;
      }
      if (await image.file.exists()) {
        images.add(image);
      }
    }

    final retained = images.take(_maxPreload).toList();
    if (retained.length != savedImages.length) {
      await _savePreloadQueueMetadata(retained);
    }
    return retained;
  }

  Future<List<RandomImage>> savePreloadQueue(
    List<RandomImage> images, {
    String? selectedTag,
    Set<String> preservePaths = const <String>{},
  }) async {
    final previousImages = await _loadSavedPreloadQueue();
    if (images.isEmpty) {
      await clearPreloadQueue();
      return <RandomImage>[];
    }

    final retained = <RandomImage>[];
    for (final image in images.take(_maxPreload)) {
      if (image.sourceTag != selectedTag || !await image.file.exists()) {
        continue;
      }
      final cachePath = await _copyIntoPreloadCache(image);
      retained.add(image.copyWith(localFilePath: cachePath));
    }

    final retainedPaths = retained.map((image) => image.localFilePath).toSet();
    for (final image in previousImages) {
      if (!retainedPaths.contains(image.localFilePath) &&
          !preservePaths.contains(image.localFilePath)) {
        await _deleteFile(image.localFilePath);
      }
    }

    await _savePreloadQueueMetadata(retained);
    return retained;
  }

  Future<void> clearPreloadQueue() async {
    final images = await _loadSavedPreloadQueue();
    for (final image in images) {
      await _deleteFile(image.localFilePath);
    }
    await _preferences.remove(_preloadQueueKey);
  }

  Future<String> _copyIntoHistoryCache(
    File source,
    String historyId,
    String? contentType,
  ) async {
    final directory = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'history'),
    );
    await directory.create(recursive: true);
    final target = File(
      p.join(directory.path,
          'nice_view_$historyId${extensionForContentType(contentType)}'),
    );
    await source.copy(target.path);
    return target.path;
  }

  Future<String> _copyIntoPreloadCache(RandomImage image) async {
    final source = image.file;
    final directory = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'preload'),
    );
    await directory.create(recursive: true);
    if (p.isWithin(directory.path, source.path) ||
        p.equals(directory.path, p.dirname(source.path))) {
      return source.path;
    }

    final imageKey =
        image.imageId?.toString() ?? DateTime.now().microsecondsSinceEpoch;
    final target = File(
      p.join(
        directory.path,
        'nice_view_preload_${imageKey}_${DateTime.now().millisecondsSinceEpoch}'
        '${extensionForContentType(image.contentType)}',
      ),
    );
    await source.copy(target.path);
    return target.path;
  }

  Future<void> _save(List<HistoryImage> images) async {
    await _preferences.setString(
      _historyKey,
      jsonEncode(images.map((image) => image.toJson()).toList()),
    );
  }

  Future<void> _savePreloadQueueMetadata(List<RandomImage> images) async {
    await _preferences.setString(
      _preloadQueueKey,
      jsonEncode(images.map((image) => image.toJson()).toList()),
    );
  }

  Future<List<RandomImage>> _loadSavedPreloadQueue() async {
    try {
      return RandomImage.listFromJsonString(
        _preferences.getString(_preloadQueueKey),
      );
    } catch (_) {
      await _preferences.remove(_preloadQueueKey);
      return <RandomImage>[];
    }
  }

  Future<void> _saveLastCurrent(HistoryImage image) {
    return _preferences.setString(
      _lastCurrentKey,
      jsonEncode(image.toJson()),
    );
  }

  Future<void> _removeLastCurrentIfMatches(HistoryImage image) async {
    final lastCurrent = await loadLastCurrent();
    if (lastCurrent?.historyId == image.historyId) {
      await _preferences.remove(_lastCurrentKey);
    }
  }

  Future<void> _deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
