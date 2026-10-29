import 'package:flutter/material.dart';

import '../constants/strings_tr.dart';
import 'photo_book.dart';

Color hexColor(String hex) => Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

String formatPrice(int cents, {String currency = 'TRY'}) {
  final whole = cents ~/ 100;
  final frac = cents % 100;
  final s = whole.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return frac == 0 ? '₺$s' : '₺$s,${frac.toString().padLeft(2, '0')}';
}

class ProductLayout {
  final String tag;
  final int minimum;
  final int maximum;

  const ProductLayout({required this.tag, required this.minimum, required this.maximum});

  factory ProductLayout.fromJson(Map<String, dynamic> j) =>
      ProductLayout(tag: j['tag'], minimum: j['minimum'], maximum: j['maximum']);
}

class Product {
  final String code;
  final String type; // booklet | softcover | hardback
  final String format; // landscape | square
  final String size; // small | medium | large
  final int priceCents;
  final int compareAtCents; // üstü çizili fiyat
  final bool mostPopular;
  final int incrementPriceCents;
  final int pagesMin;
  final int pagesMax;
  final int pagesDefault;
  final int pageIncrement;
  final int photoMin;
  final int photoRecommend;
  final int photosPerExtraPage;
  final int photoMaxBase;
  final double aspect;
  final String dimensionsCm;
  final List<int> deliveryDays;
  final List<ProductLayout> layouts;

  const Product({
    required this.code,
    required this.type,
    required this.format,
    required this.size,
    required this.priceCents,
    required this.compareAtCents,
    required this.mostPopular,
    required this.incrementPriceCents,
    required this.pagesMin,
    required this.pagesMax,
    required this.pagesDefault,
    required this.pageIncrement,
    required this.photoMin,
    required this.photoRecommend,
    required this.photosPerExtraPage,
    required this.photoMaxBase,
    required this.aspect,
    required this.dimensionsCm,
    required this.deliveryDays,
    required this.layouts,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    code: j['code'],
    type: j['type'],
    format: j['format'],
    size: j['size'],
    priceCents: j['priceCents'],
    compareAtCents: j['compareAtCents'] ?? j['priceCents'],
    mostPopular: j['mostPopular'] ?? false,
    incrementPriceCents: j['incrementPriceCents'],
    pagesMin: j['pagesMin'],
    pagesMax: j['pagesMax'],
    pagesDefault: j['pagesDefault'],
    pageIncrement: j['pageIncrement'],
    photoMin: j['photoMin'],
    photoRecommend: j['photoRecommend'],
    photosPerExtraPage: j['photosPerExtraPage'],
    photoMaxBase: j['photoMaxBase'],
    aspect: (j['aspect'] as num).toDouble(),
    dimensionsCm: j['dimensionsCm'],
    deliveryDays: List<int>.from(j['deliveryDays']),
    layouts: (j['layouts'] as List).map((e) => ProductLayout.fromJson(e)).toList(),
  );

  /// Popsa'daki gibi: taban maksimum + (eklenebilecek sayfa × sayfa başı ek fotoğraf).
  int get photoMax => photoMaxBase + (pagesMax - pagesDefault) * photosPerExtraPage;

  bool get canChangePages => pagesMax > pagesMin;

  int priceFor(int pages) => priceCents + (pages > pagesDefault ? (pages - pagesDefault) * incrementPriceCents : 0);

  static const giftBoxPriceCents = 14900;
  static const layflatPriceCents = 19900;
  static const foilPriceCents = 9900;

  bool get supportsUpgrades => type == 'hardback';

  /// Parlak kâğıt farkı: Popsa'da kitap fiyatının ~%19'u (Büyük Sert Kapak: 1.800 → +345).
  int get glossPriceCents => (priceCents * 19 / 100 / 100).round() * 100;

  int optionsPrice(ProductOptions o) =>
      (o.gloss ? glossPriceCents : 0) +
      (o.giftBox ? giftBoxPriceCents : 0) +
      (supportsUpgrades && o.layflat ? layflatPriceCents : 0) +
      (supportsUpgrades && o.foil != null ? foilPriceCents : 0);

  int totalPrice(int pages, ProductOptions o) => priceFor(pages) + optionsPrice(o);

  /// Üstü çizili toplam: indirimsiz kitap fiyatı + aynı ekler.
  int compareTotal(int pages, ProductOptions o) => totalPrice(pages, o) + compareAtCents - priceCents;

  int get extraPagesPrice => incrementPriceCents;

  /// Ölçü etiketi: "27cm × 21cm" ya da inç.
  String dimensionsLabel({bool inches = false}) {
    final parts = dimensionsCm.split('×').map((s) => double.parse(s.trim())).toList();
    String f(double v) => inches ? '${(v / 2.54).toStringAsFixed(1)}in' : '${v.round()}cm';
    return parts.map(f).join(' × ');
  }

  String get typeLabel => switch (type) {
    'booklet' => S.booklet,
    'softcover' => S.softcover,
    _ => S.hardback,
  };

  /// Popsa'daki kalite basamağı: Sert Kapak Premium, Yumuşak Kapak Standart, Kitapçık Ekonomik.
  String get tierLabel => switch (type) {
    'booklet' => S.tierEconomy,
    'softcover' => S.tierStandard,
    _ => S.tierPremium,
  };

  String get formatLabel => format == 'square' ? S.square : S.landscape;

  String get sizeLabel => switch (size) {
    'small' => S.small,
    'medium' => S.medium,
    'xlarge' => S.xlarge,
    _ => S.large,
  };

  String get title => '$typeLabel ${S.photoBook}';

  /// Mockup katman adı (assets/ref/mockups/topdown).
  String get mockupKey => switch (type) {
    'booklet' => 'PHOTOBOOKLET',
    'softcover' => format == 'square' ? 'SOFTCOVER_SQUARE' : 'SOFTCOVER',
    _ => format == 'square' ? 'HARDBACK_SQUARE' : 'HARDBACK',
  };
}

class TemplateElement {
  final String type; // photo | text
  final String role; // title | caption (yalnız text)
  final Rect frame; // yüzde (0-100)
  final TextAlign align;
  final bool border; // fotoğraf etrafında beyaz çerçeve (Popsa kapak görünümü)
  final bool vertical; // yazı 90° döndürülmüş (aşağıdan yukarı)
  final bool scrim; // fotoğraf üstündeki yazının arkasında koyu geçiş
  final bool overlay; // üst üste şablonlarda öndeki fotoğraf: sayfa renginde çerçeve alır

  const TemplateElement({
    required this.type,
    required this.role,
    required this.frame,
    required this.align,
    this.border = false,
    this.vertical = false,
    this.scrim = false,
    this.overlay = false,
  });

  bool get isPhoto => type == 'photo';

  TemplateElement withFrame(Rect f) => TemplateElement(
    type: type,
    role: role,
    frame: f,
    align: align,
    border: border,
    vertical: vertical,
    scrim: scrim,
    overlay: overlay,
  );

  factory TemplateElement.fromJson(Map<String, dynamic> j) {
    final f = (j['frame'] as List).map((e) => (e as num).toDouble()).toList();
    return TemplateElement(
      type: j['type'],
      role: j['role'] ?? '',
      frame: Rect.fromLTWH(f[0], f[1], f[2], f[3]),
      align: switch (j['align']) {
        'left' => TextAlign.left,
        'right' => TextAlign.right,
        _ => TextAlign.center,
      },
      border: j['border'] ?? false,
      vertical: j['vertical'] ?? false,
      scrim: j['scrim'] ?? false,
      overlay: j['overlay'] ?? false,
    );
  }
}

class PageTemplate {
  final int id;
  final String tag; // layout-front | layout-regular
  final int photoCount;
  final bool automaticUse;
  final List<String> categories;
  final Map<String, List<TemplateElement>> shapes;

  const PageTemplate({
    required this.id,
    required this.tag,
    required this.photoCount,
    required this.automaticUse,
    required this.categories,
    required this.shapes,
  });

  factory PageTemplate.fromJson(Map<String, dynamic> j) => PageTemplate(
    id: j['id'],
    tag: j['tag'],
    photoCount: j['photoCount'],
    automaticUse: j['automaticUse'],
    categories: List<String>.from(j['categories']),
    shapes: (j['shapes'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as List).map((e) => TemplateElement.fromJson(e)).toList()),
    ),
  );

  bool get isCover => tag == 'layout-front';

  List<TemplateElement> elementsFor(String format) => shapes[format] ?? shapes['square']!;

  List<TemplateElement> photoSlots(String format) => elementsFor(format).where((e) => e.isPhoto).toList();

  List<TemplateElement> textSlots(String format) => elementsFor(format).where((e) => !e.isPhoto).toList();
}

/// Sayfa teması: arka plan rengi ve ondan türetilen yazı renkleri.
/// Popsa'daki gibi temalar birer renktir; kimlikleri `#RRGGBB` biçimindedir.
class BookTheme {
  final String id;
  final Color background;
  final Color title;
  final Color text;

  const BookTheme({required this.id, required this.background, required this.title, required this.text});

  factory BookTheme.fromHex(String hex, {String? id}) {
    final bg = hexColor(hex);
    final light = bg.computeLuminance() > 0.45;
    return BookTheme(
      id: id ?? hex.toUpperCase(),
      background: bg,
      title: light ? const Color(0xFF3A3A3A) : Colors.white,
      text: light ? const Color(0xFF555555) : const Color(0xFFE6E6E6),
    );
  }

  // Kapak ve iç sayfalar aynı kuralı kullanır; ayrı alanlar eski kodla uyum için.
  Color get coverBackground => background;
  Color get coverText => title;
}

String colorHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

class TextAppearance {
  final String id;
  final String name;
  final String titleFont;
  final FontWeight titleWeight;
  final String bodyFont;
  final bool uppercase;
  final double letterSpacing;

  const TextAppearance({
    required this.id,
    required this.name,
    required this.titleFont,
    required this.titleWeight,
    required this.bodyFont,
    required this.uppercase,
    required this.letterSpacing,
  });

  factory TextAppearance.fromJson(Map<String, dynamic> j) => TextAppearance(
    id: j['id'],
    name: j['name'],
    titleFont: j['title'],
    titleWeight: FontWeight.values.firstWhere((w) => w.value == j['titleWeight'], orElse: () => FontWeight.w400),
    bodyFont: j['body'],
    uppercase: j['transform'] == 'upper',
    letterSpacing: (j['letterSpacing'] as num?)?.toDouble() ?? 0,
  );

  String apply(String s) => uppercase ? s.toUpperCase() : s;
}

class Catalog {
  final List<Product> products;
  final List<PageTemplate> templates;
  final List<String> neutralColors;
  final List<TextAppearance> textAppearances;

  Catalog({
    required this.products,
    required this.templates,
    required this.neutralColors,
    required this.textAppearances,
  });

  factory Catalog.fromJson(Map<String, dynamic> catalog, Map<String, dynamic> templates) => Catalog(
    products: (catalog['products'] as List).map((e) => Product.fromJson(e)).toList(),
    templates: (templates['templates'] as List).map((e) => PageTemplate.fromJson(e)).toList(),
    neutralColors: List<String>.from(catalog['neutralColors']),
    textAppearances: (catalog['textAppearances'] as List).map((e) => TextAppearance.fromJson(e)).toList(),
  );

  Product product(String code) => products.firstWhere((p) => p.code == code);

  PageTemplate template(int id) => templates.firstWhere((t) => t.id == id, orElse: () => templates.first);

  BookTheme theme(String id) => BookTheme.fromHex(id.startsWith('#') ? id : neutralColors.first);

  /// Popsa tema grupları (renkler Popsa'nın tema panelinden ölçüldü). Dinamik grup fotoğraflardan gelir.
  static const themeGroups = <String, List<String>>{
    'neutral': ['#FFFFFF', '#FAFAFA', '#ECF0F3', '#9E9E9E', '#5F7D8C', '#283238', '#212121'],
    'pastel': ['#FFEAED', '#FBE5EC', '#F3E5F5', '#EEE8F5', '#E8EAF7', '#E4F2FD', '#E2F4FE'],
    'deep': ['#AF1919', '#880E50', '#4A148D', '#301B91', '#1B237E', '#0D47A3', '#00579B'],
    'vivid': ['#F44235', '#E91F63', '#9C29B2', '#663BB7', '#3F51B6', '#2196F3', '#04A9F5'],
  };

  /// Bir sayfanın teması: `#RRGGBB` düz renk, `dyn:N` sayfanın kendi fotoğraflarından çıkan paletin N'inci rengi
  /// ([PaletteService] sırası); sayfa paleti yoksa kitabınki. Eski `tex:` kimlikleri düz renk olarak okunur.
  BookTheme resolve(String id, {List<String> pagePalette = const [], List<String> bookPalette = const []}) {
    if (id.startsWith('dyn:')) {
      final n = int.tryParse(id.substring(4)) ?? 0;
      final pal = pagePalette.length > n ? pagePalette : bookPalette;
      if (pal.length > n) return BookTheme.fromHex(pal[n], id: id);
      return theme(neutralColors.first);
    }
    if (id.startsWith('tex:')) return BookTheme.fromHex(id.substring(4), id: id);
    return theme(id);
  }

  TextAppearance textAppearance(String id) =>
      textAppearances.firstWhere((t) => t.id == id, orElse: () => textAppearances.first);

  List<String> get productTypes => const ['hardback', 'softcover', 'booklet'];

  List<Product> productsOfType(String type) => products.where((p) => p.type == type).toList();

  static const sizeOrder = ['small', 'medium', 'large', 'xlarge'];

  /// Aynı biçimde (yatay/kare) [type] türündeki ürünler, küçükten büyüğe.
  List<Product> sizesOf(String type, String format) =>
      products.where((p) => p.type == type && p.format == format).toList()
        ..sort((a, b) => sizeOrder.indexOf(a.size).compareTo(sizeOrder.indexOf(b.size)));

  /// Tür değişince: aynı boyut varsa o, yoksa en yakın boyut (Popsa Yükseltmeler > Tür).
  Product? closestOfType(Product from, String type) {
    final options = sizesOf(type, from.format);
    if (options.isEmpty) return null;
    final want = sizeOrder.indexOf(from.size);
    return options.reduce(
      (a, b) => (sizeOrder.indexOf(a.size) - want).abs() <= (sizeOrder.indexOf(b.size) - want).abs() ? a : b,
    );
  }

  int get lowestPrice => products.map((p) => p.priceCents).reduce((a, b) => a < b ? a : b);

  int get lowestCompareAt => products.map((p) => p.compareAtCents).reduce((a, b) => a < b ? a : b);
}
