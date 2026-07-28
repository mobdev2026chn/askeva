import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Loaded automatically by `flutter test` for every test in this package.
/// Registers the real Poppins font (the app's font, normally fetched at
/// runtime by google_fonts) so text measures realistically — otherwise
/// flutter_test uses a square placeholder glyph that is far wider than
/// Poppins and produces false RenderFlex overflows.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final loader = FontLoader('Poppins');
  for (final path in ['test/fonts/Poppins-Regular.ttf', 'test/fonts/Poppins-Bold.ttf']) {
    final bytes = await File(path).readAsBytes();
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  }
  await loader.load();

  await testMain();
}
