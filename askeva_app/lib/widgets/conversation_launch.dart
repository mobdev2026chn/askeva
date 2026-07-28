import 'package:flutter/material.dart';

import '../screens/conversation_screen.dart';
import 'dashboard_sheets.dart' show appToast;

/// Opens the conversation surface for a contact/lead by phone number.
/// Returns `true` when a template was sent (history chat re-opened as live).
/// If no number is available, shows a brief notice instead of a dead screen.
Future<bool?> openConversationByNumber(
  BuildContext context, {
  required String name,
  required String number,
  bool isHistory = false,
}) async {
  final digits = number.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.isEmpty) {
    appToast(context, 'No WhatsApp number on file for this contact', isError: true);
    return null;
  }
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => ConversationScreen(name: name, number: digits, isHistory: isHistory)),
  );
  return result;
}
