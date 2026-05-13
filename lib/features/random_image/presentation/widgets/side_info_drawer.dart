import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/quota_state.dart';
import '../random_image_controller.dart';
import 'quota_bar.dart';
import 'tag_strip.dart';

class SideInfoDrawer extends StatelessWidget {
  const SideInfoDrawer({
    required this.state,
    required this.quota,
    required this.onTagSelected,
    required this.onAddTag,
    required this.onDeleteTag,
    required this.onOpenHistory,
    super.key,
  });

  final RandomImageViewState state;
  final QuotaState quota;
  final ValueChanged<String?> onTagSelected;
  final VoidCallback onAddTag;
  final ValueChanged<String> onDeleteTag;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final image = state.currentImage;
    return Material(
      color: const Color(0xFF151618),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          children: [
            _SectionTitle(
              title: '当前筛选',
              trailing: state.selectedTag ?? '全部',
            ),
            const SizedBox(height: 16),
            QuotaBar(quota: quota),
            const SizedBox(height: 26),
            const _SectionLabel('标签'),
            const SizedBox(height: 10),
            TagStrip(
              tags: state.userTags,
              selectedTag: state.selectedTag,
              onSelected: onTagSelected,
              onDelete: onDeleteTag,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAddTag,
              icon: const Icon(Icons.add_rounded),
              label: const Text('添加标签'),
              style: OutlinedButton.styleFrom(
                foregroundColor: niceText,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 22),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_rounded, color: niceMuted),
              title: const Text('浏览历史'),
              subtitle: Text('${state.historyImages.length} / 30'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onOpenHistory,
              textColor: niceText,
              iconColor: niceMuted,
            ),
            const SizedBox(height: 20),
            const _SectionLabel('当前图片'),
            const SizedBox(height: 10),
            _InfoRow(label: '筛选', value: state.selectedTag ?? '全部'),
            _InfoRow(label: 'Image ID', value: image?.imageId?.toString()),
            _InfoRow(label: 'Gallery ID', value: image?.galleryId?.toString()),
            _InfoRow(label: 'Content-Type', value: image?.contentType),
            _InfoRow(label: '获取时间', value: _formatTime(image?.fetchedAt)),
            if (state.isPreloading) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(minHeight: 2),
            ],
          ],
        ),
      ),
    );
  }

  String? _formatTime(DateTime? value) {
    if (value == null) {
      return null;
    }
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.trailing,
  });

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: niceText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              trailing,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: niceAmber, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: niceText,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: niceMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '-',
              textAlign: TextAlign.right,
              style: const TextStyle(color: niceText, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
