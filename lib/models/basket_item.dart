import 'photo_book.dart';
import 'print_set.dart';

class BasketItem {
  final String bookId;
  final String title;
  final String productCode;
  final int pages;
  final ProductOptions options;
  int quantity;

  BasketItem({
    required this.bookId,
    required this.title,
    required this.productCode,
    required this.pages,
    required this.options,
    this.quantity = 1,
  });

  /// Baskı seti mi (kitap değil)? Bu durumda [bookId] set kimliği, [pages] baskı sayısıdır.
  bool get isPrints => PrintCatalog.isPrintCode(productCode);

  Map<String, dynamic> toJson() => {
    'book': bookId,
    'title': title,
    'product': productCode,
    'pages': pages,
    'options': options.toJson(),
    'qty': quantity,
  };

  factory BasketItem.fromJson(Map<String, dynamic> j) => BasketItem(
    bookId: j['book'],
    title: j['title'] ?? '',
    productCode: j['product'],
    pages: j['pages'],
    options: ProductOptions.fromJson(j['options']),
    quantity: j['qty'] ?? 1,
  );
}

/// İndirim kodu (test sürümünde sabit liste; Popsa'da sunucudan gelir).
class Coupon {
  final String code;
  final int percent;

  const Coupon(this.code, this.percent);

  static const welcome = Coupon('HOSGELDIN', 20);
  static const all = [welcome];

  static Coupon? byCode(String? code) {
    final c = code?.trim().toUpperCase();
    for (final k in all) {
      if (k.code == c) return k;
    }
    return null;
  }

  int apply(int cents) => cents - discountOf(cents);

  int discountOf(int cents) => (cents * percent / 100).round();
}
