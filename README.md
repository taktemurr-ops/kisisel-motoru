# kisisel-motoru

Kişiselleştirme ailesinin motoru: 5 aracın gerçek uygulamaları, 33 dilde metinleri ve merkez
görünümü (onaylı oyun merkezi tasarımının gece moru tonu). Bütün görseller ve sesler **kodla
üretilir**; üçüncü taraf görsel, ses, marka veya logo yoktur.

| Araç | Bu sürümde | Bu sürümde yok (yerel kod gerekir) |
|---|---|---|
| Canlı duvar kağıdı | 6 özgün hareketli sahne, palet ve hız; tam ekran; PNG kaydetme | Android `WallpaperService` (Kotlin + OpenGL/Canvas) ile sistem canlı duvar kağıdı |
| Widget paketi | Saat, tarih, geri sayım, not, pil kutucuklarından pano; tam ekran masa ekranı; PNG | Ana ekran widget'ı (`home_widget` + Android AppWidget + iOS WidgetKit uzantısı) |
| Özgün ikon paketi | 16 GENEL kategori ikonu (telefon, mesaj, kamera…), 4 biçim × 6 palet, PNG (512 px) | Başlatıcı ikon paketi entegrasyonu (`appfilter.xml`) — **bilerek yok**: marka eşlemesi ticari marka riski taşır (PLAN.md §6) |
| Bildirim ve zil sesi paketi | 15 özgün melodi, cihazda sentez (WAV), perde/hız; sistem "Farklı kaydet" ile kaydetme | Sistem zil sesini doğrudan atama (`WRITE_SETTINGS`) — **bilerek yok**; kullanıcı Ayarlar'dan seçer |
| Şarj saati (eski: kilit ekranı saati) | Tam ekran dijital/analog saat, şarjda ekranı açık tutma, gece kırmızısı, karartma, yanma koruması | Android `DreamService` (sistem ekran koruyucusu) kaydı. Kilit ekranı **değiştirilmez** (Play politikası) |

- İzin istenmez (kamera, konum, depolama yok). Dosya kaydetme sistem "Farklı kaydet" penceresiyle
  (`file_picker` `saveFile`) yapılır; olmazsa uygulamanın kendi belgeler klasörüne yazılır.
- Ekstralar (son 2 sahne, son 3 palet, 4 ses): ödüllü reklamla bugünlük ya da Premium/Reklamsız ile.
- Web: sahneler, pano, ikonlar ve sesler çalışır; pil bilgisi ve dosyaya kaydetme tarayıcıya bağlıdır,
  yoksa "bu özellik yok" denir.

Metinler `proto/apps/kisisel_titles.py` ve `kisisel_labels.py` dosyalarından
`proto/apps/kisisel/mkengine.py` ile üretilir (`lib/src/tx.dart`, `lib/src/registry.dart`).
