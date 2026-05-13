import 'package:flutter/material.dart';

class FloatingNextButton extends StatelessWidget {
  const FloatingNextButton({
    required this.onPressed,
    required this.onDisabledPressed,
    required this.enabled,
    required this.isLoading,
    required this.opacity,
    super.key,
  });

  final VoidCallback onPressed;
  final VoidCallback onDisabledPressed;
  final bool enabled;
  final bool isLoading;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final effectiveOpacity = enabled ? opacity : 0.22;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: effectiveOpacity,
      child: SizedBox.square(
        dimension: 56,
        child: Material(
          color: Colors.black.withValues(alpha: 0.62),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : onDisabledPressed,
            child: Center(
              child: isLoading
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
