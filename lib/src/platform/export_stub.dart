/// Web: dosya yazılamaz; çağıran metni panoya kopyalar.
library;

import 'dart:typed_data';

class Exporter {
  static bool get supported => false;
  static Future<String?> saveText(String name, String text) async => null;
  static Future<String?> saveBytes(String name, Uint8List bytes) async => null;
}
