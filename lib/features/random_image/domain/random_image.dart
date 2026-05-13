import 'dart:io';

class RandomImage {
  const RandomImage({
    required this.localFilePath,
    required this.fetchedAt,
    this.imageId,
    this.galleryId,
    this.contentType,
    this.sourceTag,
  });

  final String localFilePath;
  final int? imageId;
  final int? galleryId;
  final String? contentType;
  final String? sourceTag;
  final DateTime fetchedAt;

  File get file => File(localFilePath);

  String get displayId => imageId?.toString() ?? '本地图片';
}
