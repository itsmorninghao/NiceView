import 'package:flutter/material.dart';

class FloatingDownloadButton extends StatelessWidget {
  const FloatingDownloadButton({
    required this.onPressed,
    required this.isLoading,
    required this.opacity,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: onPressed == null ? 0.24 : opacity,
      child: SizedBox.square(
        dimension: 56,
        child: Material(
          color: Colors.black.withValues(alpha: 0.62),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            child: Center(
              child: isLoading
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_outlined, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}
