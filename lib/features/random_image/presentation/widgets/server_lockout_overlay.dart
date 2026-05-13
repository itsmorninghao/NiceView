import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/quota_state.dart';

class ServerLockoutOverlay extends StatelessWidget {
  const ServerLockoutOverlay({
    required this.quota,
    super.key,
  });

  final QuotaState quota;

  @override
  Widget build(BuildContext context) {
    if (!quota.isServerLocked) {
      return const SizedBox.shrink();
    }

    final seconds = quota.serverLockoutRemaining.inSeconds.clamp(0, 60).toInt();
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ModalBarrier(color: Colors.black, dismissible: false),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${seconds}s',
                  style: const TextStyle(
                    color: niceText,
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '歇 60 秒，让服务器也喝口水。',
                  style: TextStyle(color: niceMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
