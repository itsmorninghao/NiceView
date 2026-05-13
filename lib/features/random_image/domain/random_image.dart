import 'dart:convert';
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

  RandomImage copyWith({
    String? localFilePath,
    int? imageId,
    int? galleryId,
    String? contentType,
    String? sourceTag,
    DateTime? fetchedAt,
  }) {
    return RandomImage(
      localFilePath: localFilePath ?? this.localFilePath,
      imageId: imageId ?? this.imageId,
      galleryId: galleryId ?? this.galleryId,
      contentType: contentType ?? this.contentType,
      sourceTag: sourceTag ?? this.sourceTag,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'localFilePath': localFilePath,
      'imageId': imageId,
      'galleryId': galleryId,
      'contentType': contentType,
      'sourceTag': sourceTag,
      'fetchedAt': fetchedAt.toIso8601String(),
    };
  }

  static RandomImage fromJson(Map<String, Object?> json) {
    return RandomImage(
      localFilePath: json['localFilePath'] as String,
      imageId: json['imageId'] as int?,
      galleryId: json['galleryId'] as int?,
      contentType: json['contentType'] as String?,
      sourceTag: json['sourceTag'] as String?,
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
    );
  }

  static List<RandomImage> listFromJsonString(String? value) {
    if (value == null || value.isEmpty) {
      return <RandomImage>[];
    }
    final decoded = jsonDecode(value) as List<dynamic>;
    return decoded.map((item) {
      return RandomImage.fromJson(Map<String, Object?>.from(item as Map));
    }).toList();
  }
}
