/// Web implementation of browser file download.
///
/// Uses the `package:web` API (dart:js_interop + DOM) to create a Blob from
/// the file content and trigger a download via a hidden anchor element.  The
/// object URL is revoked immediately after the click to release memory.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Trigger a browser file download for [content] with the given [filename]
/// and MIME [mimeType].
void triggerBrowserDownload(
  String content,
  String filename,
  String mimeType,
) {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
