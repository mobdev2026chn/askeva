import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Standard loading / error / empty / data states for a Future.
class AsyncView<T> extends StatelessWidget {
  final Future<T>? future;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;
  final String emptyMessage;
  final IconData emptyIcon;

  const AsyncView({
    super.key,
    required this.future,
    required this.builder,
    this.onRetry,
    this.isEmpty,
    this.emptyMessage = 'Nothing here yet',
    this.emptyIcon = Icons.inbox_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Centered(child: CircularProgressIndicator(color: AppColors.evaGreen));
        }
        if (snap.hasError) {
          return _Centered(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.ink4),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    snap.error.toString().replaceFirst('Exception: ', ''),
                    textAlign: TextAlign.center,
                    style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink3),
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: onRetry,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.evaGreen),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Retry', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                  ),
                ],
              ],
            ),
          );
        }
        final data = snap.data as T;
        if (isEmpty != null && isEmpty!(data)) {
          return _Centered(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(emptyIcon, size: 40, color: AppColors.ink4),
                const SizedBox(height: 12),
                Text(emptyMessage, style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink3)),
              ],
            ),
          );
        }
        return builder(data);
      },
    );
  }
}

class _Centered extends StatelessWidget {
  final Widget child;
  const _Centered({required this.child});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 80), child: Center(child: child));
}
