import 'photo_book.dart';

/// Fotoğraf baskısı ürünü (Popsa "Regular Prints" / "Square Prints"): boyut başına tek birim fiyat,
/// miktar arttıkça artan indirim. Kitaplardan ayrı tutulur; sayfa, şablon ve cilt yoktur.
class PrintProduct {
  final String code;
  final String format; // regular | square
  final String size; // small | medium | large | xlarge
  final int listCents; // 30+ baskıda birim fiyat (üstü çizili fiyat)
  final double widthCm;
  final double heightCm;

  const PrintProduct(this.code, this.format, this.size, this.listCents, this.widthCm, this.heightCm);

  static const minPrints = 30;
  static const maxPrints = 500;

  /// Popsa'nın "Bir seçenek seç" penceresi: en az baskı sayısı ve indirim yüzdesi.
  static const tiers = [(30, 0), (100, 10), (200, 20), (400, 30)];

  /// Popsa'da başlıkta gösterilen kampanya birim fiyatı (liste fiyatın %80'i).
  int get headlineCents => (listCents * 0.8).round();

  double get aspect => widthCm / heightCm;

  bool get square => format == 'square';

  /// Seçilen kademe için birim fiyat.
  static int unitCents(int listCents, int count) => (listCents * (100 - discountPercent(count)) / 100).round();

  static int discountPercent(int count) {
    var p = 0;
    for (final (min, percent) in tiers) {
      if (count >= min) p = percent;
    }
    return p;
  }

  int totalCents(int count) => unitCents(listCents, count) * count;

  int compareCents(int count) => listCents * count;

  String dimensions({bool inches = false}) {
    String f(double v) => inches ? '${(v / 2.54).toStringAsFixed(1)}in' : '${v % 1 == 0 ? v.toInt() : v}cm';
    return '${f(widthCm)} × ${f(heightCm)}';
  }
}

/// Test sürümü baskı kataloğu. Regular Medium = 18 × 13 cm ve fiyatlar Popsa'dan alındı;
/// diğer boyut ölçüleri ve Square Medium/Large fiyatları tahminidir.
class PrintCatalog {
  static const all = [
    PrintProduct('PRN-R-S', 'regular', 'small', 1700, 15, 10),
    PrintProduct('PRN-R-M', 'regular', 'medium', 1600, 18, 13),
    PrintProduct('PRN-R-L', 'regular', 'large', 7000, 30, 20),
    PrintProduct('PRN-R-XL', 'regular', 'xlarge', 12000, 42, 30),
    PrintProduct('PRN-S-S', 'square', 'small', 1200, 10, 10),
    PrintProduct('PRN-S-M', 'square', 'medium', 1800, 15, 15),
    PrintProduct('PRN-S-L', 'square', 'large', 6000, 20, 20),
  ];

  static bool isPrintCode(String code) => code.startsWith('PRN-');

  static PrintProduct byCode(String code) => all.firstWhere((p) => p.code == code, orElse: () => all[1]);

  static List<PrintProduct> ofFormat(String format) => all.where((p) => p.format == format).toList();
}

/// Setteki tek bir baskı: fotoğraf, altına yazı, beyaz çerçeve ve yön.
class PrintItem {
  String id;
  BookPhoto photo;
  String caption;
  bool border; // anında kamera çerçevesi
  bool portrait; // true: baskı dik duruyor

  PrintItem({required this.id, required this.photo, this.caption = '', this.border = true, bool? portrait})
    : portrait = portrait ?? photo.aspect < 1;

  Map<String, dynamic> toJson() => {
    'id': id,
    'photo': photo.toJson(),
    'caption': caption,
    'border': border,
    'portrait': portrait,
  };

  factory PrintItem.fromJson(Map<String, dynamic> j) => PrintItem(
    id: j['id'],
    photo: BookPhoto.fromJson(j['photo']),
    caption: j['caption'] ?? '',
    border: j['border'] ?? true,
    portrait: j['portrait'],
  );

  PrintItem copyWith({required String id}) =>
      PrintItem(id: id, photo: photo, caption: caption, border: border, portrait: portrait);
}

/// Bir baskı seti (Popsa'daki "A Wedding Day" gibi tasarım): kapak baskısı + baskılar.
class PrintSet {
  String id;
  String title;
  String subtitle;
  String productCode;
  String colorHex; // baskı zemin rengi
  List<PrintItem> items; // [0] kapak baskısı
  int updatedAtMs;

  PrintSet({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.productCode,
    required this.items,
    this.colorHex = '#1F2F38',
    required this.updatedAtMs,
  });

  PrintProduct get product => PrintCatalog.byCode(productCode);

  int get count => items.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'product': productCode,
    'color': colorHex,
    'items': items.map((e) => e.toJson()).toList(),
    'updated': updatedAtMs,
  };

  factory PrintSet.fromJson(Map<String, dynamic> j) => PrintSet(
    id: j['id'],
    title: j['title'] ?? '',
    subtitle: j['subtitle'] ?? '',
    productCode: j['product'],
    colorHex: j['color'] ?? '#1F2F38',
    items: (j['items'] as List).map((e) => PrintItem.fromJson(e)).toList(),
    updatedAtMs: j['updated'] ?? 0,
  );

  PrintSet clone() => PrintSet.fromJson(toJson());
}
