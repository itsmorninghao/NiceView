import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/history_image.dart';

class HistoryPreviewViewer extends StatefulWidget {
  const HistoryPreviewViewer({
    required this.image,
    super.key,
  });

  final HistoryImage image;

  @override
  State<HistoryPreviewViewer> createState() => _HistoryPreviewViewerState();
}

class _HistoryPreviewViewerState extends State<HistoryPreviewViewer>
    with SingleTickerProviderStateMixin {
  late final TransformationController _controller;
  late final AnimationController _resetAnimationController;
  Animation<Matrix4>? _resetAnimation;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController()..addListener(_syncZoomState);
    _resetAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() {
        final animation = _resetAnimation;
        if (animation != null) {
          _controller.value = animation.value;
        }
      });
  }

  @override
  void didUpdateWidget(covariant HistoryPreviewViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.localFilePath != widget.image.localFilePath) {
      _controller.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _resetAnimationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: _reset,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            transformationController: _controller,
            minScale: 1,
            maxScale: 4,
            panEnabled: _isZoomed,
            boundaryMargin: const EdgeInsets.all(96),
            child: SizedBox.expand(
              child: Image.file(
                File(widget.image.localFilePath),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: niceMuted,
                      size: 32,
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: AnimatedOpacity(
                opacity: _isZoomed ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: IgnorePointer(
                  ignoring: !_isZoomed,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(8),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _reset,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.restart_alt_rounded, size: 18),
                              SizedBox(width: 6),
                              Text(
                                '还原',
                                style: TextStyle(
                                  color: niceText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _syncZoomState() {
    final value = _controller.value.storage;
    final zoomed =
        value[0] > 1.01 || value[12].abs() > 0.5 || value[13].abs() > 0.5;
    if (zoomed != _isZoomed) {
      setState(() => _isZoomed = zoomed);
    }
  }

  void _reset() {
    _resetAnimation = Matrix4Tween(
      begin: _controller.value,
      end: Matrix4.identity(),
    ).animate(
      CurvedAnimation(
        parent: _resetAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _resetAnimationController.forward(from: 0);
  }
}
