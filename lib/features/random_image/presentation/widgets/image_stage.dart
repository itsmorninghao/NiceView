import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/random_image.dart';

class ImageStage extends StatefulWidget {
  const ImageStage({
    required this.image,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.onSwipeLeft,
    required this.onHorizontalDragUpdate,
    required this.onHorizontalDragEnd,
    required this.onZoomChanged,
    super.key,
  });

  final RandomImage? image;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onSwipeLeft;
  final ValueChanged<DragUpdateDetails> onHorizontalDragUpdate;
  final ValueChanged<DragEndDetails> onHorizontalDragEnd;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<ImageStage> createState() => _ImageStageState();
}

class _ImageStageState extends State<ImageStage>
    with SingleTickerProviderStateMixin {
  late final TransformationController _controller;
  late final AnimationController _resetAnimationController;
  Animation<Matrix4>? _resetAnimation;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
    _controller.addListener(_handleTransformChanged);
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
  void didUpdateWidget(covariant ImageStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image?.localFilePath != widget.image?.localFilePath) {
      _resetNow();
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
    final image = widget.image;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: _animateReset,
      onHorizontalDragUpdate: _isZoomed ? null : widget.onHorizontalDragUpdate,
      onHorizontalDragEnd: _isZoomed ? null : _handleHorizontalDragEnd,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image == null)
            _EmptyStage(
              isLoading: widget.isLoading,
              errorMessage: widget.errorMessage,
              onRetry: widget.onRetry,
            )
          else
            InteractiveViewer(
              transformationController: _controller,
              minScale: 1,
              maxScale: 4,
              panEnabled: _isZoomed,
              scaleEnabled: true,
              boundaryMargin: const EdgeInsets.all(96),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: SizedBox.expand(
                  key: ValueKey(image.localFilePath),
                  child: Image.file(
                    File(image.localFilePath),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) {
                      return _ImageError(onRetry: widget.onRetry);
                    },
                  ),
                ),
              ),
            ),
          if (widget.isLoading && image != null)
            const Center(
              child: SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 150),
                scale: _isZoomed ? 1 : 0.92,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _isZoomed ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_isZoomed,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.52),
                        borderRadius: BorderRadius.circular(8),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _animateReset,
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
          ),
        ],
      ),
    );
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    widget.onHorizontalDragEnd(details);
    if ((details.primaryVelocity ?? 0) < -260) {
      widget.onSwipeLeft();
    }
  }

  void _handleTransformChanged() {
    final value = _controller.value.storage;
    final scale = value[0];
    final dx = value[12].abs();
    final dy = value[13].abs();
    final isZoomed = scale > 1.01 || dx > 0.5 || dy > 0.5;
    if (isZoomed == _isZoomed) {
      return;
    }
    setState(() => _isZoomed = isZoomed);
    widget.onZoomChanged(isZoomed);
  }

  void _animateReset() {
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

  void _resetNow() {
    _resetAnimationController.stop();
    _controller.value = Matrix4.identity();
    if (_isZoomed) {
      setState(() => _isZoomed = false);
      widget.onZoomChanged(false);
    }
  }
}

class _EmptyStage extends StatelessWidget {
  const _EmptyStage({
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
  });

  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: SizedBox.square(
          dimension: 32,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    return _ImageError(
      message: errorMessage,
      onRetry: onRetry,
    );
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError({
    required this.onRetry,
    this.message,
  });

  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message != null && message!.isNotEmpty) ...[
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: niceMuted, fontSize: 13),
              ),
              const SizedBox(height: 14),
            ],
            IconButton.filled(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.10),
                foregroundColor: niceText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
