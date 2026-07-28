import 'package:flutter/material.dart';

/// Shows a snackbar in the upper area of the screen so it stays visible
/// above keyboard, forms, and bottom navigation.
void showSnackBarAbove(BuildContext context, String message, {bool isError = false}) {
  if (!context.mounted) return;
  final height = MediaQuery.of(context).size.height;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(top: 72, left: 16, right: 16, bottom: height - 200),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
    ),
  );
}
