# kisisel-motoru

Kişiselleştirme ailesinin motoru: 13 aracın gerçek uygulamaları, 33 dilde metinleri ve merkez
görünümü (onaylı oyun merkezi tasarımının gece moru tonu). Bütün görseller ve sesler **kodla
üretilir**; üçüncü taraf görsel, ses, marka veya logo yoktur.

| Araç | Uygulama içinde | Sistem entegrasyonu / bilerek olmayanlar |
|---|---|---|
| Canlı duvar kağıdı | 6 özgün hareketli sahne, palet ve hız; tam ekran; PNG kaydetme | Android: sistem canlı duvar kağıdı (`SceneWallpaperService`, aynı 6 sahne Canvas ile, yalnız görünürken çizer). iOS uygulamalara canlı duvar kağıdı izni vermez: PNG |
| Widget paketi | Saat, tarih, geri sayım, not, pil kutucuklarından pano; tam ekran masa ekranı; PNG | Android: 5 ana ekran widget'ı (AppWidget; saat/tarih sistem saatiyle canlı, diğerleri 30 dk), "Ana ekrana ekle" (sabitleme). iOS: WidgetKit kaynakları merkezde `ios_widget/` (App Group açılınca) |
| Özgün ikon paketi | 16 GENEL kategori ikonu (telefon, mesaj, kamera…), 4 biçim × 6 palet, PNG (512 px) | Başlatıcı ikon paketi entegrasyonu (`appfilter.xml`) — **bilerek yok**: marka eşlemesi ticari marka riski taşır (PLAN.md §6) |
| Bildirim ve zil sesi paketi | 15 özgün melodi, cihazda sentez (WAV), perde/hız; sistem "Farklı kaydet" ile kaydetme | Sistem zil sesini doğrudan atama (`WRITE_SETTINGS`) — **bilerek yok**; kullanıcı Ayarlar'dan seçer |
| Şarj saati (eski: kilit ekranı saati) | Tam ekran dijital/analog saat, şarjda ekranı açık tutma, gece kırmızısı, karartma, yanma koruması | Android: sistem ekran koruyucusu (`ClockDreamService`, aynı ayarlar) + "Ekran koruyucu ayarları" düğmesi. Kilit ekranı **değiştirilmez** (Play politikası) |
| Tema ve renk paleti üretici | 7 renk uyumu (benzer, tamamlayıcı, bölünmüş, üçlü, dörtlü, tek renk, rastgele), renk sabitleme, HSL/HEX düzenleme, WCAG kontrast denetimi, Material açık/koyu tema önizlemesi, HEX/CSS/JSON kopyalama, PNG, kayıtlı paletler | — |
| Şık yazı ve sembol üretici | 28 Unicode stili (matematik harf blokları, daire/kare, tam genişlik, küçük büyük harf, üst simge, ters, çizgili…), aksanlı harfler temel harf + işaretle, 20 süsleme, 12 kategoride sembol ve yüz ifadesi, son kullanılanlar | Yazı tipi indirilmez; hepsi standart Unicode |
| Kenar ışıklandırma | 4 biçim (akış, nabız, gökkuşağı, kuyruklu yıldız), kalınlık/köşe/hız/süre, palet; önizleme ve tam ekran | Android: bildirim gelince (ekran açıkken) diğer uygulamaların üzerinde kenar ışığı (`EdgeNotificationService` + `EdgeOverlay`, `TYPE_APPLICATION_OVERLAY`). Kullanıcı "Bildirim erişimi" ve "Diğer uygulamaların üzerinde göster"i kendisi açar; bildirim içeriği okunmaz/saklanmaz. iOS/web: yalnız uygulama içi |
| Şarj animasyonu | 4 biçim (sıvı, halka, kabarcıklar, çubuklar), pil yüzdesi, saat, şarjdan çıkınca kapanma, ekranı açık tutma | Android: sistem ekran koruyucusu (`ChargeDreamService`, "Şarj olurken"). Sistem şarj/kilit ekranı değiştirilmez. iOS: uygulama içi tam ekran |
| Dinamik bildirim adası | Canlı önizleme (genişleyen hap), genişlik/yükseklik/üst boşluk/süre, palet, şarjda göster, boştayken küçük hap, başlık göster (varsayılan kapalı) | Android: `IslandNotificationService` (bildirim dinleyici) + `IslandOverlay` (`TYPE_APPLICATION_OVERLAY`); simge + uygulama adı, dokununca bildirimin kendi `contentIntent`'i. Kilit ekranında gösterilmez, içerik saklanmaz. **Erişilebilirlik hizmeti bilerek yok** (Play AccessibilityService politikası) → hap durum çubuğunun altında çizilir. iOS/web: önizleme + açıklama. Apple'ın "Dynamic Island" adı kullanılmaz |
| Her zaman açık ekran | 3 yüz (alt alta rakam, pil halkası, sade kadran), tarih, pil, sonraki alarm, kısa not, kayma (yanma koruması), karartma, pil eşiğinde kendiliğinden kapanma; tam ekran | Android: `AodDreamService` (sistem ekran koruyucusu, şarjda/yuvada). Ekran kapalıyken çizim üçüncü taraflara kapalıdır: dürüstçe söylenir, pil uyarısı. Sonraki alarm `AlarmManager.getNextAlarmClock()` (izinsiz). iOS: uygulama içi masa saati + sistem AOD yolu |
| Gelen aramada flaş | 3 ritim (düzenli, kalp atışı, hızlı), hız, ekran flaşı önizlemesi, sessiz/titreşimde kapalı, pil eşiği, ekran kenarı rengi | Android: `CallFlashService` (bildirim dinleyici) + `CallFlasher` (fener `CameraManager.setTorchMode`, isteğe bağlı kenar kaplaması). Ayrıntı aşağıda (Play politikası). iOS: uygulamalar aramayı algılayamaz → iOS "Uyarılar için LED Flaşı" ayarı anlatılır |
| Estetik ana ekran | 8 tema (4 ücretsiz), 4 biçim, 16 genel simge + baş harf, kısayol adı, uygulamaya göre simge önerisi (genel sözcük + sistem kategorisi; marka eşlemesi yok), PNG | Android: başlatıcı uygulama listesi (`<queries>` LAUNCHER) ve `ShortcutManager.requestPinShortcut` (Android 8+, izin gerekmez). iOS/web: PNG + Kestirmeler ile "Ana Ekrana Ekle" adımları |

- Kamera, konum, depolama izni istenmez. Tek ek izin `SYSTEM_ALERT_WINDOW`'dur (kenar ışığı, bildirim adası, arama flaşının ekran kenarı; kullanıcı açar). Dosya kaydetme sistem "Farklı kaydet" penceresiyle
  (`file_picker` `saveFile`) yapılır; olmazsa uygulamanın kendi belgeler klasörüne yazılır.
- Ekstralar (son 2 sahne, son 3 palet, 4 ses): ödüllü reklamla bugünlük ya da Premium/Reklamsız ile.
- Web: sahneler, pano, ikonlar ve sesler çalışır; pil bilgisi ve dosyaya kaydetme tarayıcıya bağlıdır,
  yoksa "bu özellik yok" denir.

## Play politikası: en az yetki (4. tur)

| Özellik | Kullanılan | Bilerek KULLANILMAYAN ve neden |
|---|---|---|
| Arama flaşı | Bildirim dinleyici (yalnız `CATEGORY_CALL` + `android.callType`/ses modu), `setTorchMode` | `READ_PHONE_STATE`: tehlikeli çalışma zamanı izni ve motor tüm uygulamalara birleştiği için bütün ince uygulamalara bulaşırdı; arama bildirimi yeterli. `READ_CALL_LOG`/`READ_CONTACTS`/`ANSWER_PHONE_CALLS`: Play "Arama kaydı ve SMS" kısıtlı izinleri, varsayılan arama uygulaması olmayanlara verilmez. `CAMERA`: fener için gerekmez. Ön plan hizmeti: dinleyici sistem tarafından bağlı tutulur |
| Bildirim adası | Bildirim dinleyici + `SYSTEM_ALERT_WINDOW` | `BIND_ACCESSIBILITY_SERVICE` (durum çubuğunun üstüne çizmek için gerekirdi): Play, erişilebilirlik dışı amaçlı kullanımı kısıtlar. Başlık varsayılan kapalı; kilit ekranında gösterilmez |
| Her zaman açık ekran | `DreamService`, uygulama içi tam ekran (wakelock) | Kilit ekranı değiştirme / ekran kapalıyken çizim: mümkün değil ve politikaya aykırı; pil uyarısı |
| Estetik ana ekran | `<queries>` LAUNCHER + `requestPinShortcut` | `QUERY_ALL_PACKAGES` (Play kısıtlı izni), `INSTALL_SHORTCUT` (eski, gereksiz) |

Bildirim dinleyiciler ayrı sınıflardır (kenar, ada, arama) ve `enabled="false"` gelir: her ince uygulamada
yalnız kullanıcının açtığı araç "Bildirim erişimi" listesinde görünür. Android 11+ ilgili dinleyicinin
ayrıntı sayfası doğrudan açılır. Gizlilik metni (merkez `PRIVACY.md`) her birini ayrı açıklar.

## Android yerel kodu (`android/`)

Motor bir Flutter **eklentisidir** (yalnız Android): `KisiselMotoruPlugin` (kanal `kisisel_motoru/native`),
`SceneWallpaperService` + `SceneRenderer`, `ClockDreamService`, `KisiselWidgetProvider` ve 5 alt sınıf.
Bileşenler manifestte `enabled="false"` gelir; kullanıcı aracı açınca `PackageManager` ile açılır
(duvar kağıdı seçicide / widget listesinde / ekran koruyucularda ancak o zaman görünür). Ek izin yoktur.
Widget verisi `home_widget` ile `HomeWidgetPreferences` içine `w_<tür>` JSON olarak yazılır.
Sistemde görünen adlar 33 dilde: `proto/apps/kisisel/mknative_res.py` üretir.

Metinler `proto/apps/kisisel_titles.py` ve `kisisel_labels.py` dosyalarından
`proto/apps/kisisel/mkengine.py` ile üretilir (`lib/src/tx.dart`, `lib/src/registry.dart`).
