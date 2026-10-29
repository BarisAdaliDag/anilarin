import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/address.dart';
import '../models/basket_item.dart';
import '../models/catalog.dart';
import '../models/order.dart';
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
  Coupon? coupon;
  Address? address;
  List<Order> orders = [];

  Future<void> load() async {
    catalog = await _catalogRepository.load();
    books = await designs.loadBooks();
    basket = await designs.loadBasket();
    coupon = Coupon.byCode(await designs.loadCoupon());
    address = await designs.loadAddress();
    orders = await designs.loadOrders();
    for (final b in books) {
      _syncBasketItem(b);
    }
    loading = false;
    notifyListeners();
  }

  void setTab(int i) {
    tabIndex = i;
    notifyListeners();
  }

  /// Popsa'daki gibi sepetteki ürün tasarımla eşit kalır (tür, boyut, sayfa, seçenekler). Sepetteyse true.
  bool _syncBasketItem(PhotoBook book) {
    final i = basket.indexWhere((b) => b.bookId == book.id);
    if (i < 0) return false;
    basket[i] = BasketItem(
      bookId: book.id,
      title: book.title,
      productCode: book.productCode,
      pages: book.pageCount,
      options: book.options.copy(),
      quantity: basket[i].quantity,
    );
    return true;
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
    final inBasket = _syncBasketItem(book);
    notifyListeners();
    await designs.saveBook(book);
    if (inBasket) await designs.saveBasket(basket);
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

  /// Ürünün ödenecek fiyatı (adet ve indirim kodu dahil).
  int itemPrice(BasketItem item) {
    final full = catalog!.product(item.productCode).totalPrice(item.pages, item.options) * item.quantity;
    return coupon?.apply(full) ?? full;
  }

  /// Üstü çizili fiyat: kampanyasız fiyat (Popsa sepetindeki gibi).
  int itemCompareAt(BasketItem item) =>
      catalog!.product(item.productCode).compareTotal(item.pages, item.options) * item.quantity;

  int get basketTotal => basket.fold(0, (s, i) => s + itemPrice(i));

  /// Toplam indirim: üstü çizili fiyatlarla ödenecek fiyatlar arasındaki fark.
  int get basketDiscount => basket.fold(0, (s, i) => s + itemCompareAt(i) - itemPrice(i));

  /// Kod geçerliyse uygular; değilse false.
  Future<bool> redeem(String code) async {
    final c = Coupon.byCode(code);
    if (c == null) return false;
    coupon = c;
    notifyListeners();
    await designs.saveCoupon(c.code);
    return true;
  }

  Future<void> removeCoupon() async {
    coupon = null;
    notifyListeners();
    await designs.saveCoupon(null);
  }

  Future<void> saveAddress(Address a) async {
    address = a;
    notifyListeners();
    await designs.saveAddress(a);
  }

  /// Siparişi verir (ödeme alınmış sayılır): kaydedilir, sepet ve indirim kodu temizlenir.
  Future<Order> placeOrder(ShippingOption shipping, String paymentMethod) async {
    final now = DateTime.now();
    final order = Order(
      reference: 'AN-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}',
      createdAtMs: now.millisecondsSinceEpoch,
      items: [...basket],
      address: address!,
      shippingId: shipping.id,
      paymentMethod: paymentMethod,
      totalCents: basketTotal + shipping.priceCents,
    );
    orders.insert(0, order);
    basket.clear();
    coupon = null;
    notifyListeners();
    await designs.saveOrders(orders);
    await designs.saveBasket(basket);
    await designs.saveCoupon(null);
    return order;
  }

  Future<void> removeFromBasket(BasketItem item) => setQuantity(item, 0);

  Future<void> clearBasket() async {
    basket.clear();
    notifyListeners();
    await designs.saveBasket(basket);
  }

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
