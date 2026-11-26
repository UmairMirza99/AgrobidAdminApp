import 'dart:typed_data';

/// Non-web builds (tests) cannot open browser tabs.
void openBytesInNewTab(Uint8List bytes, String contentType) {
  throw UnsupportedError('Opening files in a new tab is only available in the browser');
}
