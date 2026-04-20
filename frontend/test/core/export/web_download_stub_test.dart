import 'package:flutter_test/flutter_test.dart';
import 'package:anynote/core/export/web_download_stub.dart';

void main() {
  test('triggerBrowserDownload throws UnsupportedError on native', () {
    expect(
      () => triggerBrowserDownload('content', 'test.txt', 'text/plain'),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
