/// Arama için metin katlama: büyük/küçük harf ve Türkçe i/ı/İ/I farkı yok
/// sayılır ("istanbul" → "İstanbul", "kirmizi" → "Kırmızı" bulunur).
library;

extension SearchFold on String {
  String get folded => replaceAll(RegExp('[İIı]'), 'i').toLowerCase().replaceAll('\u0307', '');
}
