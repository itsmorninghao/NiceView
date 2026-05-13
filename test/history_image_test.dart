import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nice_view/features/random_image/data/random_image_repository.dart';
import 'package:nice_view/features/random_image/domain/history_image.dart';

void main() {
  test('empty history list can be sorted by callers', () {
    final images = HistoryImage.listFromJsonString(null);

    expect(images, isEmpty);
    expect(() => images.sort((a, b) => b.viewedAt.compareTo(a.viewedAt)),
        returnsNormally);
  });

  test('history list parses persisted json', () {
    final fetchedAt = DateTime(2026, 5, 14, 2, 30);
    final viewedAt = DateTime(2026, 5, 14, 2, 31);
    final value = jsonEncode([
      {
        'historyId': '42',
        'localFilePath': '/tmp/nice_view_42.jpg',
        'imageId': 42,
        'galleryId': 7,
        'contentType': 'image/jpeg',
        'sourceTag': 'city',
        'fetchedAt': fetchedAt.toIso8601String(),
        'viewedAt': viewedAt.toIso8601String(),
      },
    ]);

    final images = HistoryImage.listFromJsonString(value);

    expect(images.single.historyId, '42');
    expect(images.single.imageId, 42);
    expect(images.single.viewedAt, viewedAt);
  });

  test('content type maps to stable image extensions', () {
    expect(extensionForContentType('image/png'), '.png');
    expect(extensionForContentType('image/webp; charset=utf-8'), '.webp');
    expect(extensionForContentType('image/gif'), '.gif');
    expect(extensionForContentType(null), '.jpg');
  });
}
