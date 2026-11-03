# Firebase kurulumu (sipariş gönderimi)

Uygulama Firebase yapılandırması olmadan da açılır; yalnız sipariş gönderim ekranı
"Sunucu bağlantısı henüz yapılandırılmadı" der. Aşağıdakiler bir kez yapılır.

## 1. Proje ve faturalandırma
1. https://console.firebase.google.com → **Proje ekle** (Analytics gerekmez).
2. **Blaze** planına geç (Storage için zorunlu; küçük kullanımda ücretsiz kotada kalır).
3. Google Cloud Console → Faturalandırma → **Bütçeler ve uyarılar** → aylık 10 $ bütçe, %50/%90/%100 e-posta uyarısı.

## 2. Bölgeler (sonradan değiştirilemez)
| Hizmet | Bölge | Neden |
|---|---|---|
| Firestore | `europe-west1` (Belçika) | Tek bölgeli, ucuz, Türkiye'ye yakın. `eur3` (çok bölgeli) seçme, daha pahalı. |
| Storage (varsayılan bucket) | `us-east1` | Ücretsiz kota (5 GB depolama, ayda 100 GB indirme) yalnız us-central1 / us-east1 / us-west1'de. |
| Cloud Functions (ileride) | `europe-west1` | Firestore ile aynı bölge. |

## 3. Kimlik doğrulama
Authentication → Sign-in method → **Anonymous** etkinleştir.
(Google / Apple / e-posta ile hesap bağlama sonraki adım.)

## 4. Uygulamayı bağla
Yapıldı (proje `anilarin-b29ac`). Yeniden gerekirse:
```bash
flutterfire configure --project=anilarin-b29ac --platforms=android,ios --android-package-name=com.barisadalidag.anilarin --ios-bundle-id=com.barisadalidag.anilarin --out=lib/firebase_options.dart --yes
```
Not: Eski flutterfire sürümü önce sessizce "güncelleyeyim mi?" diye bekler ve komut bir şey
yapmıyor gibi görünür. Önce `dart pub global activate flutterfire_cli` ile güncelle.

Üretilen dosyalar: `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`,
`lib/firebase_options.dart`. `FirebaseSetup.init` bunu `DefaultFirebaseOptions.currentPlatform` ile kullanır.

iOS hedefi Firebase için 15.0'a yükseltildi (`ios/Podfile`, Xcode projesi).

## 5. Güvenlik kuralları
Yüklendi. Kural dosyası değişince:
```bash
firebase deploy --only firestore:rules,storage
```
Kurallar `firebase/firestore.rules` ve `firebase/storage.rules` dosyalarında:
- Kullanıcı yalnız kendi `orders/{uid}/...` klasörüne, dosya başına 25 MB'a kadar JPEG/JSON yazar.
- Sipariş durumu kullanıcı tarafında yalnız `uploading` → `ready`; `downloaded`, `printed`, `deleted` matbaanındır.
- Silme ve diğer kullanıcıların siparişlerini okuma yalnız `admin` claim'li matbaa hesabında.

## 6. 30 gün sonra otomatik silme
```bash
gcloud storage buckets update gs://BUCKET_ADI --lifecycle-file=firebase/storage-lifecycle.json
```
`BUCKET_ADI`: Storage sayfasında görünen ad (ör. `proje-id.firebasestorage.app`).

## 7. Matbaa hesabı (admin claim)
Matbaa kullanıcısını Authentication'da oluşturduktan sonra bir kez çalıştır
(Firebase Admin SDK, hizmet hesabı anahtarıyla):
```js
// node set-admin.js <uid>
const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.applicationDefault() });
admin.auth().setCustomUserClaims(process.argv[2], { admin: true }).then(() => process.exit(0));
```

## Sipariş düzeni
- Firestore `orders/{ref}`: `uid`, `status`, `order` (adres, ürünler, tutar), `fileCount`,
  `uploadedIds`, `totalBytes`, `photos` (dosya adı → galeri kimliği), `updatedAt`.
- Storage `orders/{uid}/{ref}/photos/{dosya}.jpg`: uzun kenar en fazla 4000 px, JPEG kalite 90.
- Storage `orders/{uid}/{ref}/{tasarımId}.json`: tasarım + `qty` + `photoFiles`. En son yüklenir;
  ardından durum `ready` olur.

## Kuralları yerelde test etmek
Firebase emülatörleri Java 21 ister:
```bash
firebase emulators:start --only auth,firestore,storage
```
