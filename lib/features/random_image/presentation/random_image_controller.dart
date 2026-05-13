import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/app_exceptions.dart';
import '../../../services/download_service.dart';
import '../../../services/quota_service.dart';
import '../../tags/data/local_tag_store.dart';
import '../data/history_store.dart';
import '../data/random_image_repository.dart';
import '../domain/history_image.dart';
import '../domain/quota_state.dart';
import '../domain/random_image.dart';

final randomImageControllerProvider =
    StateNotifierProvider<RandomImageController, RandomImageViewState>((ref) {
  final controller = RandomImageController(
    repository: ref.watch(randomImageRepositoryProvider),
    tagStore: ref.watch(localTagStoreProvider),
    historyStore: ref.watch(historyStoreProvider),
    downloadService: ref.watch(downloadServiceProvider),
    quotaController: ref.read(quotaControllerProvider.notifier),
    readQuotaState: () => ref.read(quotaControllerProvider),
  );
  unawaited(controller.initialize());
  return controller;
});

const _unset = Object();
const _defaultPreloadTarget = 6;

class RandomImageViewState {
  const RandomImageViewState({
    required this.preloadQueue,
    required this.historyImages,
    required this.preloadTarget,
    required this.isFastBrowseMode,
    required this.consecutivePreloadExhaustions,
    required this.isImageZoomed,
    required this.userTags,
    required this.isInitialLoading,
    required this.isPreloading,
    required this.isNextLoading,
    required this.isDownloading,
    this.currentImage,
    this.selectedTag,
    this.errorMessage,
    this.lastLoadError,
  });

  factory RandomImageViewState.initial() {
    return const RandomImageViewState(
      preloadQueue: [],
      historyImages: [],
      preloadTarget: _defaultPreloadTarget,
      isFastBrowseMode: false,
      consecutivePreloadExhaustions: 0,
      isImageZoomed: false,
      userTags: [],
      isInitialLoading: true,
      isPreloading: false,
      isNextLoading: false,
      isDownloading: false,
    );
  }

  final RandomImage? currentImage;
  final List<RandomImage> preloadQueue;
  final List<HistoryImage> historyImages;
  final int preloadTarget;
  final bool isFastBrowseMode;
  final int consecutivePreloadExhaustions;
  final bool isImageZoomed;
  final String? selectedTag;
  final List<String> userTags;
  final bool isInitialLoading;
  final bool isPreloading;
  final bool isNextLoading;
  final bool isDownloading;
  final String? errorMessage;
  final String? lastLoadError;

  RandomImageViewState copyWith({
    Object? currentImage = _unset,
    List<RandomImage>? preloadQueue,
    List<HistoryImage>? historyImages,
    int? preloadTarget,
    bool? isFastBrowseMode,
    int? consecutivePreloadExhaustions,
    bool? isImageZoomed,
    Object? selectedTag = _unset,
    List<String>? userTags,
    bool? isInitialLoading,
    bool? isPreloading,
    bool? isNextLoading,
    bool? isDownloading,
    Object? errorMessage = _unset,
    Object? lastLoadError = _unset,
  }) {
    return RandomImageViewState(
      currentImage: identical(currentImage, _unset)
          ? this.currentImage
          : currentImage as RandomImage?,
      preloadQueue: preloadQueue ?? this.preloadQueue,
      historyImages: historyImages ?? this.historyImages,
      preloadTarget: preloadTarget ?? this.preloadTarget,
      isFastBrowseMode: isFastBrowseMode ?? this.isFastBrowseMode,
      consecutivePreloadExhaustions:
          consecutivePreloadExhaustions ?? this.consecutivePreloadExhaustions,
      isImageZoomed: isImageZoomed ?? this.isImageZoomed,
      selectedTag: identical(selectedTag, _unset)
          ? this.selectedTag
          : selectedTag as String?,
      userTags: userTags ?? this.userTags,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isPreloading: isPreloading ?? this.isPreloading,
      isNextLoading: isNextLoading ?? this.isNextLoading,
      isDownloading: isDownloading ?? this.isDownloading,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      lastLoadError: identical(lastLoadError, _unset)
          ? this.lastLoadError
          : lastLoadError as String?,
    );
  }
}

class RandomImageController extends StateNotifier<RandomImageViewState> {
  RandomImageController({
    required RandomImageRepository repository,
    required LocalTagStore tagStore,
    required HistoryStore historyStore,
    required DownloadService downloadService,
    required QuotaController quotaController,
    required QuotaState Function() readQuotaState,
  })  : _repository = repository,
        _tagStore = tagStore,
        _historyStore = historyStore,
        _downloadService = downloadService,
        _quotaController = quotaController,
        _readQuotaState = readQuotaState,
        super(RandomImageViewState.initial());

  final RandomImageRepository _repository;
  final LocalTagStore _tagStore;
  final HistoryStore _historyStore;
  final DownloadService _downloadService;
  final QuotaController _quotaController;
  final QuotaState Function() _readQuotaState;
  final ListQueue<int> _recentImageIds = ListQueue<int>();

  bool _initialized = false;
  bool _isPreloading = false;
  int _generation = 0;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _log('initialize');

    final tags = _tagStore.loadTags();
    final selectedTag = _tagStore.loadSelectedTag();
    final effectiveSelectedTag =
        selectedTag != null && tags.contains(selectedTag) ? selectedTag : null;
    if (effectiveSelectedTag != selectedTag) {
      await _tagStore.saveSelectedTag(effectiveSelectedTag);
    }

    final historyImages = await _historyStore.load();
    final restoredImage = await _restoreLastCurrent(historyImages);
    if (!mounted) {
      return;
    }
    if (restoredImage != null) {
      _rememberImageId(restoredImage.imageId);
    }
    state = state.copyWith(
      currentImage: restoredImage,
      userTags: tags,
      selectedTag: effectiveSelectedTag,
      historyImages: historyImages,
      preloadTarget: _defaultPreloadTarget,
      isInitialLoading: restoredImage == null,
    );

    if (restoredImage == null) {
      await _loadFreshCurrent(isInitial: true);
    } else {
      unawaited(_fillPreloadQueue(_generation));
    }
  }

  void setImageZoomed(bool value) {
    if (state.isImageZoomed == value) {
      return;
    }
    state = state.copyWith(isImageZoomed: value);
  }

  Future<void> nextImage() async {
    if (state.isInitialLoading || state.isNextLoading) {
      return;
    }
    if (_readQuotaState().isServerLocked) {
      state = state.copyWith(errorMessage: '歇 60 秒，让服务器也喝口水。');
      return;
    }

    state = state.copyWith(errorMessage: null);
    if (state.preloadQueue.isNotEmpty) {
      final queue = [...state.preloadQueue];
      final next = queue.removeAt(0);
      final browsing = _nextBrowseMode(queue.isEmpty);
      final historyImages = await _historyStore.upsertFromRandomImage(next);
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        currentImage: next,
        preloadQueue: queue,
        historyImages: historyImages,
        isImageZoomed: false,
        consecutivePreloadExhaustions: browsing.exhaustions,
        isFastBrowseMode: browsing.isFast,
        preloadTarget: browsing.target,
      );
      unawaited(_fillPreloadQueue(_generation));
      return;
    }

    if (!_readQuotaState().canAcquire) {
      state = state.copyWith(errorMessage: _quotaRecoveryMessage());
      return;
    }

    final browsing = _nextBrowseMode(true);
    state = state.copyWith(
      isNextLoading: true,
      consecutivePreloadExhaustions: browsing.exhaustions,
      isFastBrowseMode: browsing.isFast,
      preloadTarget: browsing.target,
    );
    await _loadFreshCurrent();
  }

  Future<void> switchTag(String? tag) async {
    final normalized = tag?.trim();
    final effectiveTag =
        normalized == null || normalized.isEmpty ? null : normalized;
    if (effectiveTag == state.selectedTag && state.currentImage != null) {
      return;
    }

    _generation += 1;
    await _tagStore.saveSelectedTag(effectiveTag);
    state = state.copyWith(
      selectedTag: effectiveTag,
      preloadQueue: const [],
      preloadTarget: _defaultPreloadTarget,
      isFastBrowseMode: false,
      consecutivePreloadExhaustions: 0,
      isImageZoomed: false,
      errorMessage: null,
    );

    await _loadFreshCurrent();
  }

  Future<bool> addTag(String value) async {
    final tag = value.trim();
    if (tag.isEmpty) {
      state = state.copyWith(errorMessage: '标签不能为空');
      return false;
    }
    if (tag.length > 60) {
      state = state.copyWith(errorMessage: '标签最长 60 个字符');
      return false;
    }
    if (state.userTags.any((item) => item.toLowerCase() == tag.toLowerCase())) {
      state = state.copyWith(errorMessage: '这个标签已经添加过了');
      return false;
    }

    final tags = [...state.userTags, tag];
    await _tagStore.saveTags(tags);
    state = state.copyWith(userTags: tags);
    await switchTag(tag);
    return true;
  }

  Future<void> deleteTag(String tag) async {
    final tags = state.userTags.where((item) => item != tag).toList();
    await _tagStore.saveTags(tags);
    state = state.copyWith(userTags: tags);
    if (state.selectedTag == tag) {
      await switchTag(null);
    }
  }

  Future<void> downloadCurrentImage() async {
    final current = state.currentImage;
    if (current == null || state.isDownloading) {
      return;
    }

    state = state.copyWith(isDownloading: true, errorMessage: null);
    var imageToSave = current;
    try {
      final localFile = File(imageToSave.localFilePath);
      if (!await localFile.exists()) {
        final imageId = imageToSave.imageId;
        if (imageId == null) {
          throw const NiceViewException('当前图片已丢失，请切换下一张后再下载');
        }
        if (!_readQuotaState().canAcquire) {
          throw QuotaExceededException(_quotaRecoveryMessage());
        }
        imageToSave = await _repository.fetchImageById(
          imageId,
          sourceTag: imageToSave.sourceTag,
        );
        if (mounted && state.currentImage?.imageId == imageId) {
          state = state.copyWith(currentImage: imageToSave);
        }
      }

      await _downloadService.saveImage(imageToSave);
      if (mounted) {
        state = state.copyWith(errorMessage: '已保存到系统相册');
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(errorMessage: _messageForError(error));
      }
    } finally {
      if (mounted) {
        state = state.copyWith(isDownloading: false);
      }
    }
  }

  Future<void> deleteHistoryImage(HistoryImage image) async {
    final images = await _historyStore.delete(image);
    if (mounted) {
      state = state.copyWith(historyImages: images);
    }
  }

  Future<void> touchHistoryImage(HistoryImage image) async {
    final images = await _historyStore.touch(image);
    if (mounted) {
      state = state.copyWith(historyImages: images);
    }
  }

  Future<void> removeMissingHistoryImage(HistoryImage image) async {
    final images = await _historyStore.removeMissing(image);
    if (mounted) {
      state = state.copyWith(
        historyImages: images,
        errorMessage: '这张历史图已经不在本机了',
      );
    }
  }

  void clearMessage() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }

  Future<void> retryCurrent() async {
    await _loadFreshCurrent(isInitial: state.currentImage == null);
  }

  Future<RandomImage?> _restoreLastCurrent(
    List<HistoryImage> historyImages,
  ) async {
    final lastCurrent = await _historyStore.loadLastCurrent();
    final candidates = <HistoryImage>[
      if (lastCurrent != null) lastCurrent,
      ...historyImages,
    ];
    final seen = <String>{};
    for (final image in candidates) {
      if (!seen.add(image.historyId)) {
        continue;
      }
      if (await image.file.exists()) {
        _log('restore last current imageId=${image.imageId}');
        return RandomImage(
          localFilePath: image.localFilePath,
          imageId: image.imageId,
          galleryId: image.galleryId,
          contentType: image.contentType,
          sourceTag: image.sourceTag,
          fetchedAt: image.fetchedAt,
        );
      }
    }
    return null;
  }

  Future<void> _loadFreshCurrent({bool isInitial = false}) async {
    final generation = ++_generation;
    _log(
      'load current generation=$generation initial=$isInitial '
      'tag=${state.selectedTag ?? '<all>'}',
    );
    state = state.copyWith(
      isInitialLoading: isInitial && state.currentImage == null,
      isNextLoading: !isInitial || state.currentImage != null,
      errorMessage: null,
      lastLoadError: null,
    );

    try {
      final image = await _fetchRandomWithRetry(tag: state.selectedTag);
      if (!mounted || generation != _generation) {
        _log('discard stale image generation=$generation');
        return;
      }
      _rememberImageId(image.imageId);
      final historyImages = await _historyStore.upsertFromRandomImage(image);
      if (!mounted || generation != _generation) {
        return;
      }
      state = state.copyWith(
        currentImage: image,
        historyImages: historyImages,
        isInitialLoading: false,
        isNextLoading: false,
        isImageZoomed: false,
        lastLoadError: null,
      );
      _log(
        'load success generation=$generation imageId=${image.imageId} '
        'path=${image.localFilePath}',
      );
      if (isInitial) {
        unawaited(
          Future<void>.delayed(const Duration(seconds: 2), () {
            if (mounted && generation == _generation) {
              return _fillPreloadQueue(generation);
            }
          }),
        );
      } else {
        unawaited(_fillPreloadQueue(generation));
      }
    } catch (error) {
      if (!mounted || generation != _generation) {
        return;
      }
      final message = _messageForError(error);
      _log('load failed generation=$generation error=$error message=$message');
      state = state.copyWith(
        isInitialLoading: false,
        isNextLoading: false,
        errorMessage: message,
        lastLoadError: message,
      );
    }
  }

  Future<RandomImage> _fetchRandomWithRetry({String? tag}) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        return await _repository.fetchRandom(tag: tag);
      } on ImageNotFoundException catch (error) {
        lastError = error;
      } on NiceViewException catch (error) {
        if (error is QuotaExceededException ||
            error is ServerLockoutException ||
            error is EmptyTagException) {
          rethrow;
        }
        lastError = error;
        if (attempt < 2) {
          _log('retry random request after transient error: $error');
          await Future<void>.delayed(
              Duration(milliseconds: 500 + attempt * 750));
        }
      }
    }
    throw lastError ?? const ImageNotFoundException('图片不存在');
  }

  Future<void> _fillPreloadQueue(int generation) async {
    if (_isPreloading || _readQuotaState().isServerLocked) {
      return;
    }
    _isPreloading = true;
    if (mounted) {
      state = state.copyWith(isPreloading: true);
    }

    var attempts = 0;
    try {
      while (mounted &&
          generation == _generation &&
          state.preloadQueue.length < state.preloadTarget &&
          _readQuotaState().canAcquire &&
          attempts < state.preloadTarget * 4) {
        final quota = _readQuotaState();
        final missing = state.preloadTarget - state.preloadQueue.length;
        final remainingAttempts = state.preloadTarget * 4 - attempts;
        var requestCount = missing;
        if (requestCount > quota.remaining) {
          requestCount = quota.remaining;
        }
        if (requestCount > remainingAttempts) {
          requestCount = remainingAttempts;
        }
        if (requestCount <= 0) {
          break;
        }

        attempts += requestCount;
        _log('preload batch count=$requestCount missing=$missing');
        final results = await Future.wait(
          List.generate(requestCount, (_) async {
            try {
              return _PreloadResult(
                image: await _fetchRandomWithRetry(tag: state.selectedTag),
              );
            } catch (error) {
              return _PreloadResult(error: error);
            }
          }),
        );
        if (!mounted || generation != _generation) {
          return;
        }

        var added = 0;
        Object? firstError;
        for (final result in results) {
          final error = result.error;
          if (error != null) {
            if (error is ServerLockoutException) {
              throw error;
            }
            if (error is QuotaExceededException) {
              return;
            }
            firstError ??= error;
            continue;
          }

          final image = result.image;
          if (image == null || _isDuplicate(image)) {
            continue;
          }
          _rememberImageId(image.imageId);
          state = state.copyWith(
            preloadQueue: [...state.preloadQueue, image],
          );
          added += 1;
        }

        if (added == 0 && firstError != null) {
          break;
        }
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(errorMessage: _messageForError(error));
      }
    } finally {
      _isPreloading = false;
      if (mounted) {
        state = state.copyWith(isPreloading: false);
      }
    }
  }

  _BrowseMode _nextBrowseMode(bool queueExhausted) {
    if (!queueExhausted) {
      return _BrowseMode(
        exhaustions: 0,
        isFast: state.isFastBrowseMode,
        target: state.preloadTarget,
      );
    }

    final exhaustions = state.consecutivePreloadExhaustions + 1;
    final isFast = exhaustions >= 2 || state.isFastBrowseMode;
    return _BrowseMode(
      exhaustions: exhaustions,
      isFast: isFast,
      target: _defaultPreloadTarget,
    );
  }

  bool _isDuplicate(RandomImage image) {
    final imageId = image.imageId;
    if (imageId == null) {
      return false;
    }
    if (_recentImageIds.contains(imageId)) {
      return true;
    }
    if (state.currentImage?.imageId == imageId) {
      return true;
    }
    return state.preloadQueue.any((item) => item.imageId == imageId);
  }

  void _rememberImageId(int? imageId) {
    if (imageId == null) {
      return;
    }
    _recentImageIds.remove(imageId);
    _recentImageIds.addLast(imageId);
    while (_recentImageIds.length > 20) {
      _recentImageIds.removeFirst();
    }
  }

  String _quotaRecoveryMessage() {
    final wait = _readQuotaState().timeUntilNextAvailable;
    if (wait == null || wait.inSeconds <= 0) {
      return '请求额度已用尽，请稍后再试';
    }
    return '请求额度已用尽，约 ${wait.inSeconds}s 后恢复';
  }

  String _messageForError(Object error) {
    if (error is ServerLockoutException) {
      return '歇 60 秒，让服务器也喝口水。';
    }
    if (error is QuotaExceededException) {
      return _quotaRecoveryMessage();
    }
    if (error is EmptyTagException) {
      return '该标签暂时没有图片';
    }
    if (error is NiceViewException) {
      return error.message;
    }
    return '网络连接失败，稍后再试';
  }

  @override
  void dispose() {
    unawaited(_quotaController.pruneAndSave());
    super.dispose();
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[NiceView][Controller] $message');
    }
  }
}

class _PreloadResult {
  const _PreloadResult({
    this.image,
    this.error,
  });

  final RandomImage? image;
  final Object? error;
}

class _BrowseMode {
  const _BrowseMode({
    required this.exhaustions,
    required this.isFast,
    required this.target,
  });

  final int exhaustions;
  final bool isFast;
  final int target;
}
