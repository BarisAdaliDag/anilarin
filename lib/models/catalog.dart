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

  int priceFor(int pages) =>
      priceCents + (pages > pagesDefault ? (pages - pagesDefault) * incrementPriceCents : 0);

  static const giftBoxPriceCents = 14900;
  static const layflatPriceCents = 19900;
  static const foilPriceCents = 9900;

  bool get supportsUpgrades => type == 'hardback';

  int optionsPrice(ProductOptions o) =>
      (o.giftBox ? giftBoxPriceCents : 0) +
      (supportsUpgrades && o.layflat ? layflatPriceCents : 0) +
      (supportsUpgrades && o.foil != null ? foilPriceCents : 0);

  int totalPrice(int pages, ProductOptions o) => priceFor(pages) + optionsPrice(o);

  String get typeLabel => switch (type) {
        'booklet' => S.booklet,
        'softcover' => S.softcover,
        _ => S.hardback,
      };

  String get formatLabel => format == 'square' ? S.square : S.landscape;

  String get sizeLabel => switch (size) {
        'small' => S.small,
        'medium' => S.medium,
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

  const TemplateElement({required this.type, required this.role, required this.frame, required this.align});

  bool get isPhoto => type == 'photo';

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

class BookTheme {
  final String id;
  final String group;
  final String name;
  final Color background;
  final Color title;
  final Color text;
  final Color coverBackground;
  final Color coverText;
  final String preview;

  const BookTheme({
    required this.id,
    required this.group,
    required this.name,
    required this.background,
    required this.title,
    required this.text,
    required this.coverBackground,
    required this.coverText,
    required this.preview,
  });

  factory BookTheme.fromJson(Map<String, dynamic> j) => BookTheme(
        id: j['id'],
        group: j['group'],
        name: j['name'],
        background: hexColor(j['background']),
        title: hexColor(j['title']),
        text: hexColor(j['text']),
        coverBackground: hexColor(j['coverBackground']),
        coverText: hexColor(j['coverText']),
        preview: j['preview'],
      );
}

class ThemeGroup {
  final String id;
  final String name;

  const ThemeGroup(this.id, this.name);
}

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
        titleWeight: FontWeight.values.firstWhere(
          (w) => w.value == j['titleWeight'],
          orElse: () => FontWeight.w400,
        ),
        bodyFont: j['body'],
        uppercase: j['transform'] == 'upper',
        letterSpacing: (j['letterSpacing'] as num?)?.toDouble() ?? 0,
      );

  String apply(String s) => uppercase ? s.toUpperCase() : s;
}

class Catalog {
  final List<Product> products;
  final List<PageTemplate> templates;
  final List<BookTheme> themes;
  final List<ThemeGroup> themeGroups;
  final List<TextAppearance> textAppearances;
  final List<String> preferredThemes;

  Catalog({
    required this.products,
    required this.templates,
    required this.themes,
    required this.themeGroups,
    required this.textAppearances,
    required this.preferredThemes,
  });

  factory Catalog.fromJson(Map<String, dynamic> catalog, Map<String, dynamic> templates) => Catalog(
        products: (catalog['products'] as List).map((e) => Product.fromJson(e)).toList(),
        templates: (templates['templates'] as List).map((e) => PageTemplate.fromJson(e)).toList(),
        themes: (catalog['themes'] as List).map((e) => BookTheme.fromJson(e)).toList(),
        themeGroups: (catalog['themeGroups'] as List).map((e) => ThemeGroup(e['id'], e['name'])).toList(),
        textAppearances: (catalog['textAppearances'] as List).map((e) => TextAppearance.fromJson(e)).toList(),
        preferredThemes: List<String>.from(catalog['preferredThemes']),
      );

  Product product(String code) => products.firstWhere((p) => p.code == code);

  PageTemplate template(int id) => templates.firstWhere((t) => t.id == id, orElse: () => templates.first);

  BookTheme theme(String id) => themes.firstWhere((t) => t.id == id, orElse: () => themes.first);

  TextAppearance textAppearance(String id) =>
      textAppearances.firstWhere((t) => t.id == id, orElse: () => textAppearances.first);

  List<String> get productTypes => const ['booklet', 'softcover', 'hardback'];

  List<Product> productsOfType(String type) => products.where((p) => p.type == type).toList();

  int get lowestPrice => products.map((p) => p.priceCents).reduce((a, b) => a < b ? a : b);
}
