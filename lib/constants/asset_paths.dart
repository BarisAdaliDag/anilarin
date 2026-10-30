/// Görsel yolları. `assets/ref/` altındakiler yereldir (tool/import_reference_assets.sh ile doldurulur);
/// eksik olduklarında widget'lar yer tutucu gösterir.
class AssetPaths {
  static const heroPhotoBook = 'assets/ref/home/hero_photobooks.jpg';
  static const productPhotoBook = 'assets/ref/home/product_photobook.webp';
  static const productPrints = 'assets/ref/home/product_prints.webp';
  static const onboarding = 'assets/ref/home/onboarding.webp';
  static const memoriesExamples = [
    'assets/ref/home/memories_journeys.webp',
    'assets/ref/home/memories_connections.webp',
    'assets/ref/home/memories_rewinds.webp',
  ];

  /// Format detayındaki medya karuseli: önce video, sonra görseller.
  static const productVideo = 'assets/ref/media/promo_1.mp4';
  static const productCarousel = [
    'assets/ref/media/carousel_1.jpg',
    'assets/ref/media/carousel_2.jpg',
    'assets/ref/media/carousel_3.jpg',
    'assets/ref/media/carousel_4.jpg',
    'assets/ref/media/carousel_5.jpg',
    'assets/ref/media/carousel_6.jpg',
  ];

  /// Cilt tipi + format kart görselleri.
  static String productCover(String type, String format) => switch ((type, format)) {
    ('hardback', 'square') => 'assets/ref/media/cover_hardback_square.jpg',
    ('softcover', 'square') => 'assets/ref/media/cover_softcover_square.jpg',
    ('softcover', _) => 'assets/ref/media/cover_softcover_landscape.jpg',
    ('booklet', 'square') => 'assets/ref/media/cover_softcover_square.jpg',
    ('booklet', _) => 'assets/ref/media/cover_booklet_landscape.jpg',
    _ => 'assets/ref/media/cover_hardback_landscape.jpg',
  };
}
