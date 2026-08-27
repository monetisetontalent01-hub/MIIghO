import 'dart:io';

/// Helper to delete a file by path on native platforms.
Future<void> tryDeleteFile(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}
