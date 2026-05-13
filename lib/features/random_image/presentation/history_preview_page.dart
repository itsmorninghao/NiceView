import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../services/download_service.dart';
import '../domain/history_image.dart';
import '../domain/random_image.dart';
import 'widgets/history_preview_viewer.dart';

class HistoryPreviewPage extends ConsumerStatefulWidget {
  const HistoryPreviewPage({
    required this.images,
    required this.initialIndex,
    super.key,
  });

  final List<HistoryImage> images;
  final int initialIndex;

  @override
  ConsumerState<HistoryPreviewPage> createState() => _HistoryPreviewPageState();
}

class _HistoryPreviewPageState extends ConsumerState<HistoryPreviewPage> {
  late final PageController _pageController;
  late int _index;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final maxIndex = widget.images.isEmpty ? 0 : widget.images.length - 1;
    _index = widget.initialIndex.clamp(0, maxIndex).toInt();
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: niceText,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              return HistoryPreviewViewer(image: widget.images[index]);
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: IconButton.filled(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.42),
                    foregroundColor: niceText,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 18, top: 20),
                child: Text(
                  '${_index + 1} / ${widget.images.length}',
                  style: const TextStyle(color: niceMuted, fontSize: 13),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 22, bottom: 22),
                child: IconButton.filled(
                  tooltip: '保存图片',
                  onPressed: _isSaving ? null : _saveCurrentImage,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.50),
                    foregroundColor: niceText,
                    disabledBackgroundColor:
                        Colors.black.withValues(alpha: 0.32),
                    disabledForegroundColor: niceText.withValues(alpha: 0.58),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCurrentImage() async {
    if (_isSaving || widget.images.isEmpty) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      final image = widget.images[_index];
      await ref.read(downloadServiceProvider).saveImage(
            RandomImage(
              localFilePath: image.localFilePath,
              imageId: image.imageId,
              galleryId: image.galleryId,
              contentType: image.contentType,
              sourceTag: image.sourceTag,
              fetchedAt: image.fetchedAt,
            ),
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存到系统相册')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败，图片可能已经不在本机了')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
