import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/basket_item.dart';
import '../models/catalog.dart';
import '../models/photo_book.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/design_repository.dart';

/// Uygulama genelindeki durum: katalog, kayıtlı tasarımlar ve sepet.
class AppViewModel extends ChangeNotifier {
  AppViewModel({CatalogRepository? catalogRepository, DesignRepository? designRepository})
    : _catalogRepository = catalogRepository ?? CatalogRepository(),
      designs = designRepository ?? DesignRepository();

  final CatalogRepository _catalogRepository;
  final DesignRepository designs;

  Catalog? catalog;
  List<PhotoBook> books = [];
  List<BasketItem> basket = [];
  bool loading = true;
  int tabIndex = 0;

  Future<void> load() async {
    catalog = await _catalogRepository.load();
    books = await designs.loadBooks();
    basket = await designs.loadBasket();
    loading = false;
    notifyListeners();
  }

  void setTab(int i) {
    tabIndex = i;
    notifyListeners();
  }

  PhotoBook? book(String id) {
    for (final b in books) {
      if (b.id == id) return b;
    }
    return null;
  }

  Future<void> saveBook(PhotoBook book) async {
    book.updatedAtMs = DateTime.now().millisecondsSinceEpoch;
    final i = books.indexWhere((b) => b.id == book.id);
    if (i >= 0) {
      books[i] = book;
    } else {
      books.insert(0, book);
    }
    books.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    notifyListeners();
    await designs.saveBook(book);
  }

  Future<PhotoBook?> duplicateBook(String id) async {
    final original = book(id);
    if (original == null) return null;
    final copy = original.clone()
      ..id = const Uuid().v4()
      ..title = '${original.title} (kopya)'
      ..createdAtMs = DateTime.now().millisecondsSinceEpoch;
    await saveBook(copy);
    return copy;
  }

  Future<void> deleteBook(String id) async {
    books.removeWhere((b) => b.id == id);
    basket.removeWhere((b) => b.bookId == id);
    notifyListeners();
    await designs.deleteBook(id);
    await designs.saveBasket(basket);
  }

  int get basketCount => basket.fold(0, (s, i) => s + i.quantity);

  int itemPrice(BasketItem item) =>
      catalog!.product(item.productCode).totalPrice(item.pages, item.options) * item.quantity;

  int get basketTotal => basket.fold(0, (s, i) => s + itemPrice(i));

  Future<void> addToBasket(PhotoBook book) async {
    final existing = basket.indexWhere((b) => b.bookId == book.id);
    final item = BasketItem(
      bookId: book.id,
      title: book.title,
      productCode: book.productCode,
      pages: book.pageCount,
      options: book.options.copy(),
      quantity: existing >= 0 ? basket[existing].quantity : 1,
    );
    if (existing >= 0) {
      basket[existing] = item;
    } else {
      basket.add(item);
    }
    notifyListeners();
    await designs.saveBasket(basket);
  }

  Future<void> setQuantity(BasketItem item, int quantity) async {
    if (quantity <= 0) {
      basket.remove(item);
    } else {
      item.quantity = quantity;
    }
    notifyListeners();
    await designs.saveBasket(basket);
  }
}
