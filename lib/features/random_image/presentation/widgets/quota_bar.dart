import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/quota_state.dart';

class QuotaBar extends StatelessWidget {
  const QuotaBar({
    required this.quota,
    super.key,
  });

  final QuotaState quota;

  @override
  Widget build(BuildContext context) {
    final status = _quotaStatus(quota);
    final color = quota.progress >= 0.9
        ? niceDanger
        : quota.progress >= 0.7
            ? niceAmber
            : niceMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '请求额度',
              style: TextStyle(
                color: niceText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${quota.used} / ${quota.limit} 次',
              style: const TextStyle(color: niceMuted, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: quota.progress.clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          status,
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }

  String _quotaStatus(QuotaState quota) {
    final serverLockout = quota.serverLockoutRemaining;
    if (serverLockout > Duration.zero) {
      return '${serverLockout.inSeconds}s 后解除服务器冷却';
    }

    final wait = quota.timeUntilNextAvailable;
    if (wait != null) {
      return '约 ${wait.inSeconds}s 后恢复';
    }

    final remaining = quota.remaining;
    if (quota.progress >= 0.9) {
      return '剩余 $remaining 次，快到上限';
    }
    if (quota.progress >= 0.7) {
      return '剩余 $remaining 次，注意节奏';
    }
    return '剩余 $remaining 次';
  }
}
