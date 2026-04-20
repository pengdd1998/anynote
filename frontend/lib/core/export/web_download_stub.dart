/// Stub implementation for native platforms.
///
/// Browser download is not available on native platforms; file I/O is used
/// instead. This stub ensures the import resolves cleanly on all platforms.
///
/// See web_download_web.dart for the real web implementation.
library;

/// Trigger a browser file download.
///
/// On native platforms this is never called -- the export service writes files
/// to the filesystem directly.
void triggerBrowserDownload(
  String content,
  String filename,
  String mimeType,
) {
  throw UnsupportedError('Browser download is not available on native');
}
