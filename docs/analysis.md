# Referans analiz notları

Referans: Popsa (`com.popsa.android`) **7.3.1** (versionCode 70301, minSdk 32, targetSdk 36) —
yalnızca akış ve ekran yapısı için incelenir. Çıkarılan APK/görsel/font dosyaları `reference/`
altında yerel tutulur ve repoya eklenmez; uygulamada kendi görsellerimiz kullanılır.

## Teknoloji (orijinal)
- Native Android (Kotlin), çoklu Activity mimarisi (navigation graph yok)
- Kitap önizleme/3D: **Unity** (`libunity.so`, `libil2cpp.so`) → Flutter'da 2D sayfa çevirme / `PageView` ile karşılanabilir
- Fotoğraf seçimi/otomatik düzen: TensorFlow Lite + OpenCV (cihazda ML)
- Ödeme: Stripe (kart, Klarna, PayPal, GPay, iDEAL, EPS, P24…)
- Hata izleme: Sentry

## Ekranlar (Activity'lerden)
**Giriş / ana sayfa**
- `SetUpActivity` — ilk kurulum (onboarding)
- `HomeActivity` (tabbed_home) — sekmeli ana sayfa
- `settings.SettingsActivity`, `LanguageActivity`, `CountryActivity`, `WebViewActivity`

**Yeni baskı oluşturma**
- `ProductsOverviewActivity` → `ProductDetailActivity` → `ProductFormatDetailActivity` — ürün kataloğu
- `PhotoPickerActivity` — fotoğraf seçimi
- `CreatePrintTitleActivity` — başlık

**Düzenleme**
- `PrintLayoutActivity` — ana editör
- `PageTemplateActivity`, `ThemesActivity`, `ProductSizeActivity`
- `ReArrangePagesActivity`, `RemovePagesActivity`
- `EditPhotoActivity`, `TextEditorActivity`, `FontPickerActivity`
- `PreviewActivity` — önizleme (Unity)

**Sipariş**
- `BasketActivity` / `ReadonlyBasketActivity`, `OffersActivity`, `VoucherCodeActivity`
- `AddressListActivity`, `NewAddressActivity`, `OrderSelectAddressActivity`
- `ShippingOptionsActivity`, `ShippingInfoActivity`
- `SelectPaymentActivity`, `CardChooserActivity`, `NewCardActivity`
- `OrderCheckoutActivity` → `TransactionStatusActivity` → `OrderConfirmationActivity`
- `OrderDetailsActivity`, `OrderStatusActivity`

**Paylaşım**
- `LoadingSharedPrintActivity`, `SharedPrintReportActivity`

## Tema / renkler (gündüz)
| Rol | Renk |
|---|---|
| Vurgu (primary accent) | `#00ACC3` (gece `#009DB3`) |
| Başarı | `#00ACC2` |
| Hata | `#FF005A` |
| Uyarı | `#FF9600` |
| Ana metin | `#585858` |
| Gri yüzey | `#EBEBEB` |
| Mor (AI özellikleri) | `#AA58AD` → `#6565BD` gradyan |

## Fontlar
Orijinalde Sharp Grotesk, Apercu Pro, Italian Plate (ticari) + DM Sans, DM Serif, Libre Baskerville,
Quicksand, News Cycle (açık lisans). Flutter tarafında açık lisanslı olanlar `google_fonts`
ile kullanılır; ticari olanların yerine DM Sans / benzeri kullanılır.

## Kaynak boyutu
- ~1400 layout, ~2500 drawable, 430 Türkçe string (`values-tr`)
- Yerel konumlar: `reference/decoded` (apktool), `reference/decoded-xxhdpi` (görseller),
  `reference/decoded-tr` (TR metinler), `reference/jadx` (kod)

## Fotoğraf kitabı akışı (Adım 2'de çıkarıldı)
- Ürün/şablon/tema/fiyat verisi Popsa'da sunucudan protobuf olarak geliyor (`GET /catalog/{ülke}/{para birimi}`).
  Biz yerel `assets/catalog/catalog.json` ve `templates.json` kullanıyoruz.
- Şablon geometrisi: APK'daki `template_icon_template_{id}_{square|landscape}.webp` ikonlarından
  piksel analiziyle çıkarıldı (1–74, yüzde çerçeveler). Kapak şablonları: 1, 18–20, 31–38.
- Otomatik yerleşim Popsa'da cihazda çalışıyor; `lib/services/auto_layout_service.dart` aynı mantığı uygular:
  tarihsizler önce + tarih sırası, kapak = ilk foto, sayfa başı ~3 foto, artanlar ortadan dışa,
  fotoğraf sayısına göre `automaticUse` şablon, en-boy oranı eşleştirmesi.
- Ürün kodları: PBK-1/2 kitapçık, PBK-3–6 yumuşak kapak, PBK-7–12 sert kapak (yatay/kare).
- Ana sayfa videoları APK'da yok (katalog/CDN'den akıyor). Telefondan ekran kaydıyla alınıp
  `reference/screens/media` → `assets/ref/media/promo_*.mp4|jpg` olarak konursa karusel otomatik kullanır.

## Görsel değiştirme
`assets/ref/` altındaki dosyalar yereldir ve repoya girmez (`tool/import_reference_assets.sh` doldurur).
Kendi görsellerinizi aynı adlarla koymanız yeterli; eksik dosyada uygulama yer tutucu gösterir.
