import 'package:flutter/material.dart';
import 'theme_service.dart';

class ThemeProvider extends InheritedNotifier<ThemeService> {
  const ThemeProvider({
    super.key,
    required ThemeService themeService,
    required super.child,
  }) : super(notifier: themeService);

  static ThemeService of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<ThemeProvider>();
    assert(provider != null, 'No ThemeProvider found in context');
    return provider!.notifier!;
  }
}
