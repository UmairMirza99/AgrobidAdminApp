import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Opens bytes in a new browser tab (used for PDFs, which Flutter cannot render inline).
void openBytesInNewTab(Uint8List bytes, String contentType) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: contentType));
  web.window.open(web.URL.createObjectURL(blob), '_blank');
}
