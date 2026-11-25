/// Mobil ve masaüstü: uygulamanın belgeler klasörüne yazar (geniş depolama
/// izni gerekmez). Yazılan dosyanın yolunu döndürür.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class Exporter {
  static bool get supported => true;

  static Future<String?> saveText(String name, String text) =>
      saveBytes(name, Uint8List.fromList(utf8.encode('﻿$text')));

  static Future<String?> saveBytes(String name, Uint8List bytes) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final f = File('${dir.path}/$safe');
      await f.writeAsBytes(bytes, flush: true);
      return f.path;
    } catch (_) {
      return null;
    }
  }
}
