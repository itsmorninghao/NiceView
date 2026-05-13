import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../services/quota_service.dart';
import 'history_page.dart';
import 'random_image_controller.dart';
import 'widgets/floating_download_button.dart';
import 'widgets/floating_next_button.dart';
import 'widgets/image_stage.dart';
import 'widgets/server_lockout_overlay.dart';
import 'widgets/side_info_drawer.dart';

class RandomImagePage extends ConsumerStatefulWidget {
  const RandomImagePage({super.key});

  @override
  ConsumerState<RandomImagePage> createState() => _RandomImagePageState();
}

class _RandomImagePageState extends ConsumerState<RandomImagePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drawerController;

  @override
  void initState() {
    super.initState();
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _drawerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
    final quota = ref.watch(quotaControllerProvider);
    final controller = ref.read(randomImageControllerProvider.notifier);

    return PopScope(
      canPop: _drawerController.value == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        if (_drawerController.value > 0) {
          _closeDrawer();
        }
      },
      child: Scaffold(
        backgroundColor: niceBlack,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final drawerWidth = math.min(screenWidth * 0.82, 420.0);
            return AnimatedBuilder(
              animation: _drawerController,
              builder: (context, _) {
                final progress = _drawerController.value;
                final buttonOpacity =
                    (state.isImageZoomed ? 0.38 : 0.60) * (1 - progress * 0.35);
                final padding = MediaQuery.of(context).padding;
                final canNext = !quota.isServerLocked &&
                    !state.isInitialLoading &&
                    !state.isNextLoading &&
                    (state.preloadQueue.isNotEmpty || quota.canAcquire);
                final drawerDragEnabled =
                    !state.isImageZoomed && !quota.isServerLocked;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Transform.translate(
                      offset: Offset(-drawerWidth * progress, 0),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragUpdate: drawerDragEnabled
                            ? (details) => _handleDrawerDragUpdate(
                                  details,
                                  drawerWidth,
                                )
                            : null,
                        onHorizontalDragEnd:
                            drawerDragEnabled ? _handleDrawerDragEnd : null,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ImageStage(
                              image: state.currentImage,
                              isLoading:
                                  state.isInitialLoading || state.isNextLoading,
                              errorMessage: state.lastLoadError,
                              onRetry: controller.retryCurrent,
                              onSwipeLeft: () {
                                if (!quota.isServerLocked &&
                                    !state.isImageZoomed) {
                                  _openDrawer();
                                }
                              },
                              onHorizontalDragUpdate: (details) {
                                _handleDrawerDragUpdate(
                                  details,
                                  drawerWidth,
                                );
                              },
                              onHorizontalDragEnd: _handleDrawerDragEnd,
                              onZoomChanged: controller.setImageZoomed,
                            ),
                            Positioned(
                              left: 22,
                              bottom: padding.bottom + 22,
                              child: FloatingDownloadButton(
                                onPressed: quota.isServerLocked ||
                                        state.currentImage == null
                                    ? null
                                    : controller.downloadCurrentImage,
                                isLoading: state.isDownloading,
                                opacity: buttonOpacity,
                              ),
                            ),
                            Positioned(
                              right: 22,
                              bottom: padding.bottom + 22,
                              child: FloatingNextButton(
                                enabled: canNext,
                                isLoading: state.isNextLoading,
                                opacity: buttonOpacity,
                                onPressed: controller.nextImage,
                                onDisabledPressed: controller.nextImage,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: -drawerWidth * (1 - progress),
                      width: drawerWidth,
                      child: SideInfoDrawer(
                        state: state,
                        quota: quota,
                        onTagSelected: (tag) {
                          _closeDrawer();
                          controller.switchTag(tag);
                        },
                        onAddTag: _showAddTagSheet,
                        onDeleteTag: (tag) => _confirmDeleteTag(tag),
                        onOpenHistory: _openHistory,
                      ),
                    ),
                    if (progress > 0.02)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        left: 0,
                        width: math.max(0, screenWidth - drawerWidth),
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _closeDrawer,
                          onHorizontalDragUpdate: (details) {
                            _handleDrawerDragUpdate(
                              details,
                              drawerWidth,
                            );
                          },
                          onHorizontalDragEnd: _handleDrawerDragEnd,
                        ),
                      ),
                    ServerLockoutOverlay(quota: quota),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _handleDrawerDragUpdate(
    DragUpdateDetails details,
    double drawerWidth,
  ) {
    final primaryDelta = details.primaryDelta;
    if (primaryDelta == null) {
      return;
    }
    final next = (_drawerController.value - primaryDelta / drawerWidth)
        .clamp(0.0, 1.0)
        .toDouble();
    _drawerController.value = next;
  }

  void _handleDrawerDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -420) {
      _openDrawer();
      return;
    }
    if (velocity > 420) {
      _closeDrawer();
      return;
    }
    if (_drawerController.value >= 0.45) {
      _openDrawer();
    } else {
      _closeDrawer();
    }
  }

  void _openDrawer() {
    _drawerController.animateTo(
      1,
      curve: Curves.easeOutCubic,
      duration: const Duration(milliseconds: 220),
    );
  }

  void _closeDrawer() {
    _drawerController.animateTo(
      0,
      curve: Curves.easeOutCubic,
      duration: const Duration(milliseconds: 180),
    );
  }

  Future<void> _showAddTagSheet() async {
    final tag = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF17181A),
      builder: (context) => const _AddTagSheet(),
    );
    if (tag == null || !mounted) {
      return;
    }
    final added =
        await ref.read(randomImageControllerProvider.notifier).addTag(tag);
    if (added) {
      _closeDrawer();
    }
  }

  Future<void> _confirmDeleteTag(String tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF191A1C),
          title: const Text('删除标签'),
          content: Text('删除“$tag”后不会删除任何历史图片。'),
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
      await ref.read(randomImageControllerProvider.notifier).deleteTag(tag);
    }
  }

  Future<void> _openHistory() async {
    _closeDrawer();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const HistoryPage()),
    );
  }
}

class _AddTagSheet extends StatefulWidget {
  const _AddTagSheet();

  @override
  State<_AddTagSheet> createState() => _AddTagSheetState();
}

class _AddTagSheetState extends State<_AddTagSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, bottom + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '添加标签',
            style: TextStyle(
              color: niceText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 60,
            style: const TextStyle(color: niceText),
            decoration: InputDecoration(
              hintText: '标签名',
              errorText: _error,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _submit,
            child: const Text('保存并切换'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final tag = _controller.text.trim();
    if (tag.isEmpty) {
      setState(() => _error = '标签不能为空');
      return;
    }
    if (tag.length > 60) {
      setState(() => _error = '标签最长 60 个字符');
      return;
    }
    Navigator.of(context).pop(tag);
  }
}
