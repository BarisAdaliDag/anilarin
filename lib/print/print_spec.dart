import '../models/catalog.dart';
import '../models/print_set.dart';

/// Bir baskı sayfasının fiziksel ölçüsü, 300 DPI. Yalnız kitap kapağında her kenara taşma payı eklenir;
/// iç sayfalar ve tek baskılar net (kesim) ölçüsündedir.
///
/// Ölçüler katalogdan türetilir; matbaanın gerçek ölçüleriyle onaylanmalıdır.
class PrintSpec {
  final double widthMm;
  final double heightMm;
  final double bleedMm;

  const PrintSpec(this.widthMm, this.heightMm, {this.bleedMm = 0});

  static const dpi = 300;

  /// Kapakta kesim için her kenara eklenen pay (A4: 210 × 297 → 216 × 303 mm).
  static const coverBleedMm = 3.0;

  static int mmToPx(double mm) => (mm / 25.4 * dpi).round();

  static double mmToPt(double mm) => mm / 25.4 * 72;

  int get trimWidthPx => mmToPx(widthMm);
  int get trimHeightPx => mmToPx(heightMm);
  int get bleedPx => mmToPx(bleedMm);
  int get fullWidthPx => trimWidthPx + 2 * bleedPx;
  int get fullHeightPx => trimHeightPx + 2 * bleedPx;
  double get fullWidthMm => widthMm + 2 * bleedMm;
  double get fullHeightMm => heightMm + 2 * bleedMm;
  double get fullWidthPt => mmToPt(fullWidthMm);
  double get fullHeightPt => mmToPt(fullHeightMm);

  /// Kitap: genişlik katalogdaki "21 × 15" ölçüsünün ilki; yükseklik tasarımın oranından
  /// (sayfa düzeni bu orana göre çizildiği için). Kapakta [coverBleedMm] taşma payı vardır.
  factory PrintSpec.book(Product p, {bool cover = false}) {
    final width = parseCm(p.dimensionsCm).$1 * 10;
    return PrintSpec(width, width / p.aspect, bleedMm: cover ? coverBleedMm : 0);
  }

  /// Baskı: ürün ölçüsü, taşmasız; dikey baskıda kenarlar yer değiştirir. Kare baskı her zaman kare.
  factory PrintSpec.print(PrintProduct p, {required bool portrait}) {
    final long = p.widthCm * 10, short = p.heightCm * 10;
    if (p.square) return PrintSpec(long, long);
    return portrait ? PrintSpec(short, long) : PrintSpec(long, short);
  }

  /// Baskı ölçüsünün klasör adı, yönden bağımsız: "18x13", "13x13".
  static String sizeTag(PrintProduct p) => '${_fmt(p.widthCm)}x${_fmt(p.heightCm)}';

  /// "21 × 29.7" → (21, 29.7).
  static (double, double) parseCm(String s) {
    final n = RegExp(r'[\d.,]+').allMatches(s).map((m) => double.parse(m.group(0)!.replaceAll(',', '.'))).toList();
    return (n[0], n.length > 1 ? n[1] : n[0]);
  }

  /// Bilgi metninde kullanılan özet: "210 × 297 mm net, 300 DPI (2480 × 3508 px)" ya da kapakta
  /// "210 × 297 mm + 3 mm taşma = 216 × 303 mm, 300 DPI (2550 × 3578 px)".
  String get label {
    final trim = '${_fmt(widthMm)} × ${_fmt(heightMm)} mm';
    final size = bleedMm == 0
        ? '$trim net'
        : '$trim + ${_fmt(bleedMm)} mm taşma = ${_fmt(fullWidthMm)} × ${_fmt(fullHeightMm)} mm';
    return '$size, $dpi DPI ($fullWidthPx × $fullHeightPx px)';
  }

  /// Bir ondalığa yuvarlar, tam sayıysa ondalığı yazmaz: 296.99 → "297", 160.73 → "160.7".
  static String _fmt(double v) {
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble() ? r.toInt().toString() : r.toStringAsFixed(1);
  }
}
