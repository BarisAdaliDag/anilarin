import 'dart:convert';

/// Kitapta kullanılan bir fotoğraf (cihaz galerisindeki asset).
class BookPhoto {
  final String id;
  final int width;
  final int height;
  final int? takenAtMs;

  const BookPhoto({required this.id, required this.width, required this.height, this.takenAtMs});

  double get aspect => height == 0 ? 1 : width / height;

  DateTime? get takenAt => takenAtMs == null ? null : DateTime.fromMillisecondsSinceEpoch(takenAtMs!);

  Map<String, dynamic> toJson() => {'id': id, 'w': width, 'h': height, 't': takenAtMs};

  factory BookPhoto.fromJson(Map<String, dynamic> j) =>
      BookPhoto(id: j['id'], width: j['w'], height: j['h'], takenAtMs: j['t']);
}

/// Şablondaki bir fotoğraf alanına yerleştirilmiş fotoğraf ve kırpma ayarları.
class PhotoSlot {
  String photoId;
  bool fit; // false = Doldur (FILL), true = Sığdır (FIT)
  double scale; // kullanıcı yakınlaştırması (>= 1)
  double dx; // -1..1 kaydırma (FILL modunda taşan kısım içinde)
  double dy;
  int quarterTurns;

  PhotoSlot({
    required this.photoId,
    this.fit = false,
    this.scale = 1,
    this.dx = 0,
    this.dy = 0,
    this.quarterTurns = 0,
  });

  Map<String, dynamic> toJson() =>
      {'p': photoId, 'fit': fit, 's': scale, 'dx': dx, 'dy': dy, 'r': quarterTurns};

  factory PhotoSlot.fromJson(Map<String, dynamic> j) => PhotoSlot(
        photoId: j['p'],
        fit: j['fit'] ?? false,
        scale: (j['s'] as num?)?.toDouble() ?? 1,
        dx: (j['dx'] as num?)?.toDouble() ?? 0,
        dy: (j['dy'] as num?)?.toDouble() ?? 0,
        quarterTurns: j['r'] ?? 0,
      );

  void resetCrop() {
    scale = 1;
    dx = 0;
    dy = 0;
  }
}

class PrintPage {
  String id;
  String tag; // layout-front | layout-regular
  int templateId;
  List<PhotoSlot?> photos; // şablonun fotoğraf alanı sırasına göre
  List<String> texts; // şablonun metin alanı sırasına göre (kapakta başlık kitap başlığından gelir)
  String? themeOverride;
  bool borderless; // kenarlıksız: fotoğraf alanları sayfa kenarına kadar uzar

  PrintPage({
    required this.id,
    required this.tag,
    required this.templateId,
    required this.photos,
    required this.texts,
    this.themeOverride,
    this.borderless = false,
  });

  bool get isCover => tag == 'layout-front';

  Iterable<String> get photoIds => photos.whereType<PhotoSlot>().map((s) => s.photoId);

  Map<String, dynamic> toJson() => {
        'id': id,
        'tag': tag,
        'tpl': templateId,
        'photos': photos.map((p) => p?.toJson()).toList(),
        'texts': texts,
        'theme': themeOverride,
        if (borderless) 'bl': true,
      };

  factory PrintPage.fromJson(Map<String, dynamic> j) => PrintPage(
        id: j['id'],
        tag: j['tag'],
        templateId: j['tpl'],
        photos: (j['photos'] as List).map((e) => e == null ? null : PhotoSlot.fromJson(e)).toList(),
        texts: List<String>.from(j['texts'] ?? const []),
        themeOverride: j['theme'],
        borderless: j['bl'] ?? false,
      );
}

class ProductOptions {
  bool giftBox;
  bool layflat;
  String? foil; // null | gold | silver

  ProductOptions({this.giftBox = false, this.layflat = false, this.foil});

  Map<String, dynamic> toJson() => {'gift': giftBox, 'layflat': layflat, 'foil': foil};

  factory ProductOptions.fromJson(Map<String, dynamic>? j) => ProductOptions(
        giftBox: j?['gift'] ?? false,
        layflat: j?['layflat'] ?? false,
        foil: j?['foil'],
      );

  ProductOptions copy() => ProductOptions(giftBox: giftBox, layflat: layflat, foil: foil);
}

/// Popsa'daki `Print` modelinin karşılığı.
class PhotoBook {
  String id;
  String productCode;
  String title;
  String subtitle;
  String themeId;
  String textAppearanceId;
  List<PrintPage> pages; // [0] kapak, ardından iç sayfalar
  List<String> unusedPhotoIds;
  Map<String, BookPhoto> photos;
  ProductOptions options;
  List<String> palette; // fotoğraflardan çıkarılan dinamik renkler
  int createdAtMs;
  int updatedAtMs;

  PhotoBook({
    required this.id,
    required this.productCode,
    required this.title,
    required this.subtitle,
    required this.themeId,
    required this.textAppearanceId,
    required this.pages,
    required this.unusedPhotoIds,
    required this.photos,
    required this.options,
    this.palette = const [],
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  PrintPage get cover => pages.first;

  List<PrintPage> get innerPages => pages.where((p) => !p.isCover).toList();

  int get pageCount => pages.where((p) => !p.isCover).length;

  String? get coverPhotoId => cover.photoIds.isEmpty ? null : cover.photoIds.first;

  Set<String> get usedPhotoIds => {for (final p in pages) ...p.photoIds};

  Map<String, dynamic> toJson() => {
        'id': id,
        'product': productCode,
        'title': title,
        'subtitle': subtitle,
        'theme': themeId,
        'font': textAppearanceId,
        'pages': pages.map((p) => p.toJson()).toList(),
        'unused': unusedPhotoIds,
        'photos': photos.values.map((p) => p.toJson()).toList(),
        'options': options.toJson(),
        'palette': palette,
        'created': createdAtMs,
        'updated': updatedAtMs,
      };

  factory PhotoBook.fromJson(Map<String, dynamic> j) => PhotoBook(
        id: j['id'],
        productCode: j['product'],
        title: j['title'] ?? '',
        subtitle: j['subtitle'] ?? '',
        themeId: j['theme'],
        textAppearanceId: j['font'],
        pages: (j['pages'] as List).map((e) => PrintPage.fromJson(e)).toList(),
        unusedPhotoIds: List<String>.from(j['unused'] ?? const []),
        photos: {
          for (final p in (j['photos'] as List).map((e) => BookPhoto.fromJson(e))) p.id: p,
        },
        options: ProductOptions.fromJson(j['options']),
        palette: List<String>.from(j['palette'] ?? const []),
        createdAtMs: j['created'],
        updatedAtMs: j['updated'],
      );

  String encode() => jsonEncode(toJson());

  PhotoBook clone() => PhotoBook.fromJson(jsonDecode(encode()));
}
