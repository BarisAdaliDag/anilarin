/// Görsel yolları. `assets/ref/` altındakiler yereldir (tool/import_reference_assets.sh ile doldurulur);
/// eksik olduklarında widget'lar yer tutucu gösterir.
class AssetPaths {
  static const heroPhotoBook = 'assets/ref/home/hero_photobooks.jpg';
  static const productPhotoBook = 'assets/ref/home/product_photobook.webp';
  static const onboarding = 'assets/ref/home/onboarding.webp';
  static const memoriesExamples = [
    'assets/ref/home/memories_journeys.webp',
    'assets/ref/home/memories_connections.webp',
    'assets/ref/home/memories_rewinds.webp',
  ];

  static String theme(String id) => 'assets/ref/themes/$id.webp';

  /// Ana sayfa tanıtım karuseli. Video varsa önce o denenir, oynatılamazsa görsel gösterilir.
  static const promos = [
    Promo(
      image: 'assets/ref/media/promo_1.jpg',
      fallback: heroPhotoBook,
      video: 'assets/ref/media/promo_1.mp4',
      title: 'Anılarını kitaba dönüştür',
      body: 'Fotoğraflarını seç; sayfaları senin için tasarlayalım.',
    ),
    Promo(
      image: 'assets/ref/media/promo_2.jpg',
      fallback: onboarding,
      video: 'assets/ref/media/promo_2.mp4',
      title: 'Dakikalar içinde hazır',
      body: 'Akıllı yerleşim, temalar ve yazı tipleriyle kişiselleştir.',
    ),
    Promo(
      image: 'assets/ref/media/promo_3.jpg',
      fallback: productPhotoBook,
      title: 'Sert kapak, yumuşak kapak, kitapçık',
      body: 'Her bütçeye uygun boyut ve cilt seçenekleri.',
    ),
  ];

  static const community = [
    'assets/ref/media/community_1.jpg',
    'assets/ref/media/community_2.jpg',
    'assets/ref/media/community_3.jpg',
    'assets/ref/media/community_4.jpg',
  ];
}

class Promo {
  final String image;
  final String fallback;
  final String? video;
  final String title;
  final String body;

  const Promo({required this.image, required this.fallback, this.video, required this.title, required this.body});
}
