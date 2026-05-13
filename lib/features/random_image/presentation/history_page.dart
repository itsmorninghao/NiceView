import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../domain/history_image.dart';
import 'history_preview_page.dart';
import 'random_image_controller.dart';
import 'widgets/history_grid.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(
      randomImageControllerProvider.select((state) => state.errorMessage),
      (previous, next) {
        if (next == null) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next)),
        );
        ref.read(randomImageControllerProvider.notifier).clearMessage();
      },
    );

    final state = ref.watch(randomImageControllerProvider);
    final controller = ref.read(randomImageControllerProvider.notifier);
    return Scaffold(
      backgroundColor: niceBlack,
      appBar: AppBar(
        backgroundColor: niceBlack,
        foregroundColor: niceText,
        title: const Text('浏览历史'),
      ),
      body: HistoryGrid(
        images: state.historyImages,
        onOpen: (image) => _openPreview(context, ref, image),
        onDelete: (image) => _confirmDelete(context, controller, image),
      ),
    );
  }

  Future<void> _openPreview(
    BuildContext context,
    WidgetRef ref,
    HistoryImage image,
  ) async {
    final controller = ref.read(randomImageControllerProvider.notifier);
    if (!await image.file.exists()) {
      await controller.removeMissingHistoryImage(image);
      return;
    }

    final images = [...ref.read(randomImageControllerProvider).historyImages];
    final index =
        images.indexWhere((item) => item.historyId == image.historyId);
    unawaited(controller.touchHistoryImage(image));
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HistoryPreviewPage(
          images: images,
          initialIndex: index < 0 ? 0 : index,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    RandomImageController controller,
    HistoryImage image,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF191A1C),
          title: const Text('删除历史图片'),
          content: const Text('删除后会同时移除本地缓存文件。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await controller.deleteHistoryImage(image);
    }
  }
}
