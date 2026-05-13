import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../domain/history_image.dart';
import 'widgets/history_preview_viewer.dart';

class HistoryPreviewPage extends StatefulWidget {
  const HistoryPreviewPage({
    required this.images,
    required this.initialIndex,
    super.key,
  });

  final List<HistoryImage> images;
  final int initialIndex;

  @override
  State<HistoryPreviewPage> createState() => _HistoryPreviewPageState();
}

class _HistoryPreviewPageState extends State<HistoryPreviewPage> {
  late final PageController _pageController;
  late int _index;

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
        ],
      ),
    );
  }
}
