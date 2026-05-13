import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

class TagStrip extends StatelessWidget {
  const TagStrip({
    required this.tags,
    required this.selectedTag,
    required this.onSelected,
    required this.onDelete,
    super.key,
  });

  final List<String> tags;
  final String? selectedTag;
  final ValueChanged<String?> onSelected;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final allTags = <String?>[null, ...tags];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: allTags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tag = allTags[index];
          final selected = tag == selectedTag;
          return GestureDetector(
            onLongPress: tag == null ? null : () => onDelete(tag),
            child: ChoiceChip(
              label: Text(tag ?? '全部'),
              selected: selected,
              showCheckmark: false,
              onSelected: (_) => onSelected(tag),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              selectedColor: niceAmber.withValues(alpha: 0.24),
              side: BorderSide(
                color:
                    selected ? niceAmber : Colors.white.withValues(alpha: 0.12),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              labelStyle: TextStyle(
                color: selected ? niceText : niceMuted,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }
}
