/// Stub for file reading when dart:io is not available (e.g. web).
Future<String> readFileFromPath(String path) async {
  return '';
}
