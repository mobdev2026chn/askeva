import 'package:flutter/material.dart';

/// Shows a modern styled confirmation dialog with gradient accent.
/// Returns true if user confirmed, false otherwise.
Future<bool?> showModernConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  bool isDestructive = false,
}) async {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: Theme.of(ctx).textTheme.titleLarge),
      content: Text(message, style: Theme.of(ctx).textTheme.bodyMedium),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(cancelText),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: isDestructive
              ? ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(confirmText),
          ),
        ),
      ],
    ),
  );
}
