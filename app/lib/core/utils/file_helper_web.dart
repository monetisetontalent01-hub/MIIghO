/// Helper to delete a file by path on native platforms.
/// On web, this is a no-op.
Future<void> tryDeleteFile(String path) async {
  // No-op on web — this stub is used when dart.library.io is not available
}
