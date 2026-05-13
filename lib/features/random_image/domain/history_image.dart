import 'dart:convert';
import 'dart:io';

class HistoryImage {
  const HistoryImage({
    required this.historyId,
    required this.localFilePath,
    required this.fetchedAt,
    required this.viewedAt,
    this.imageId,
    this.galleryId,
    this.contentType,
    this.sourceTag,
  });

  final String historyId;
  final String localFilePath;
  final int? imageId;
  final int? galleryId;
  final String? contentType;
  final String? sourceTag;
  final DateTime fetchedAt;
  final DateTime viewedAt;

  File get file => File(localFilePath);

  HistoryImage copyWith({
    String? localFilePath,
    DateTime? fetchedAt,
    DateTime? viewedAt,
    int? imageId,
    int? galleryId,
    String? contentType,
    String? sourceTag,
  }) {
    return HistoryImage(
      historyId: historyId,
      localFilePath: localFilePath ?? this.localFilePath,
      imageId: imageId ?? this.imageId,
      galleryId: galleryId ?? this.galleryId,
      contentType: contentType ?? this.contentType,
      sourceTag: sourceTag ?? this.sourceTag,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      viewedAt: viewedAt ?? this.viewedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'historyId': historyId,
      'localFilePath': localFilePath,
      'imageId': imageId,
      'galleryId': galleryId,
      'contentType': contentType,
      'sourceTag': sourceTag,
      'fetchedAt': fetchedAt.toIso8601String(),
      'viewedAt': viewedAt.toIso8601String(),
    };
  }

  static HistoryImage fromJson(Map<String, Object?> json) {
    return HistoryImage(
      historyId: json['historyId'] as String,
      localFilePath: json['localFilePath'] as String,
      imageId: json['imageId'] as int?,
      galleryId: json['galleryId'] as int?,
      contentType: json['contentType'] as String?,
      sourceTag: json['sourceTag'] as String?,
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      viewedAt: DateTime.parse(json['viewedAt'] as String),
    );
  }

  static List<HistoryImage> listFromJsonString(String? value) {
    if (value == null || value.isEmpty) {
      return <HistoryImage>[];
    }
    final decoded = jsonDecode(value) as List<dynamic>;
    return decoded.map((item) {
      return HistoryImage.fromJson(Map<String, Object?>.from(item as Map));
    }).toList();
  }
}
