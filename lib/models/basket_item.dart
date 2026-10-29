import 'photo_book.dart';

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
