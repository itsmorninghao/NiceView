import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../features/random_image/domain/random_image.dart';
import '../features/random_image/data/random_image_repository.dart';
import 'app_exceptions.dart';

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return const DownloadService();
});

class DownloadService {
  const DownloadService();

  static const _channel = MethodChannel('nice_view/downloads');

  Future<String> saveImage(RandomImage image) async {
    final file = File(image.localFilePath);
    if (!await file.exists()) {
      throw const NiceViewException('当前图片已经不在本机了');
    }

    final bytes = await file.readAsBytes();
    final fileName = _fileNameFor(image);
    final mimeType = image.contentType?.split(';').first.trim() ?? 'image/jpeg';

    if (Platform.isAndroid) {
      try {
        return await _saveAndroid(bytes, fileName, mimeType);
      } on PlatformException {
        await _requestAndroidPermissionBestEffort();
        return _saveAndroid(bytes, fileName, mimeType);
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final output = File(p.join(directory.path, fileName));
    await output.writeAsBytes(bytes, flush: true);
    return output.path;
  }

  Future<String> _saveAndroid(
    List<int> bytes,
    String fileName,
    String mimeType,
  ) async {
    final uri = await _channel.invokeMethod<String>('saveImage', {
      'bytes': Uint8List.fromList(bytes),
      'fileName': fileName,
      'mimeType': mimeType,
    });
    return uri ?? fileName;
  }

  Future<void> _requestAndroidPermissionBestEffort() async {
    final photos = await Permission.photos.request();
    if (photos.isGranted || photos.isLimited) {
      return;
    }
    await Permission.storage.request();
  }

  String _fileNameFor(RandomImage image) {
    final id = image.imageId?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();
    return 'nice_view_$id${extensionForContentType(image.contentType)}';
  }
}
