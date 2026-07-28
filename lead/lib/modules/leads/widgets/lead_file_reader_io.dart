import 'dart:io';

Future<String> readFileFromPath(String path) async {
  try {
    return await File(path).readAsString();
  } catch (_) {
    return '';
  }
}
