import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/history_image.dart';

class HistoryGrid extends StatelessWidget {
  const HistoryGrid({
    required this.images,
    required this.onOpen,
    required this.onDelete,
    super.key,
  });

  final List<HistoryImage> images;
  final ValueChanged<HistoryImage> onOpen;
  final ValueChanged<HistoryImage> onDelete;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const Center(
        child: Text(
          '暂无历史',
          style: TextStyle(color: niceMuted),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        return GestureDetector(
          onTap: () => onOpen(image),
          onLongPress: () => onDelete(image),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ColoredBox(
              color: Colors.white.withValues(alpha: 0.06),
              child: Image.file(
                File(image.localFilePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: niceMuted,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
