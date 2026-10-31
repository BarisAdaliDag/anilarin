import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../constants/strings_tr.dart';
import '../models/address.dart';
import '../models/basket_item.dart';
import '../models/catalog.dart';
import '../models/order.dart';
import '../models/photo_book.dart';
import '../models/print_set.dart';
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
  List<PrintSet> printSets = [];
  List<BasketItem> basket = [];
  bool loading = true;
  int tabIndex = 0;
  Coupon? coupon;
  Address? address;
  List<Order> orders = [];

  Future<void> load() async {
    catalog = await _catalogRepository.load();
    books = await designs.loadBooks();
    printSets = await designs.loadPrintSets();
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
    final full = item.isPrints
        ? PrintCatalog.byCode(item.productCode).totalCents(item.pages) * item.quantity
        : catalog!.product(item.productCode).totalPrice(item.pages, item.options) * item.quantity;
    return coupon?.apply(full) ?? full;
  }

  /// Üstü çizili fiyat: kampanyasız fiyat (Popsa sepetindeki gibi).
  int itemCompareAt(BasketItem item) => item.isPrints
      ? PrintCatalog.byCode(item.productCode).compareCents(item.pages) * item.quantity
      : catalog!.product(item.productCode).compareTotal(item.pages, item.options) * item.quantity;

  /// Teslimat gün aralığı (kitaplar için ürünün, baskılar için sabit 5–8 gün).
  List<int> deliveryDaysOf(BasketItem item) =>
      item.isPrints ? const [5, 8] : catalog!.product(item.productCode).deliveryDays;

  /// Sepet ve özet kartlarında ürün satırları.
  List<String> itemLines(BasketItem item) {
    if (item.isPrints) {
      final p = PrintCatalog.byCode(item.productCode);
      return [
        '${p.square ? S.squarePrints : S.regularPrints} (${S.sizeName(p.size)})',
        S.printsN(item.pages),
        if (printSet(item.bookId)?.matte ?? false) S.matteFinish,
      ];
    }
    final p = catalog!.product(item.productCode);
    final extra = (item.pages - p.pagesDefault).clamp(0, 999);
    return [
      '${p.title} (${p.sizeLabel})',
      if (extra > 0) S.extraPages(extra),
      if (item.options.gloss) S.glossFinish,
      if (item.options.layflat) S.layflat,
      if (item.options.foil != null) '${S.foil} (${item.options.foil == 'gold' ? S.foilGold : S.foilSilver})',
      if (item.options.giftBox) S.giftBox,
    ];
  }

  // ---- baskı setleri ----

  PrintSet? printSet(String id) {
    for (final s in printSets) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> savePrintSet(PrintSet set) async {
    set.updatedAtMs = DateTime.now().millisecondsSinceEpoch;
    final i = printSets.indexWhere((s) => s.id == set.id);
    if (i >= 0) {
      printSets[i] = set;
    } else {
      printSets.insert(0, set);
    }
    printSets.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    final b = basket.indexWhere((e) => e.bookId == set.id);
    if (b >= 0) {
      basket[b] = BasketItem(
        bookId: set.id,
        title: set.title.isEmpty ? S.printTitleDefault : set.title,
        productCode: set.productCode,
        pages: set.count,
        options: ProductOptions(),
        quantity: basket[b].quantity,
      );
    }
    notifyListeners();
    await designs.savePrintSet(set);
    if (b >= 0) await designs.saveBasket(basket);
  }

  Future<void> deletePrintSet(String id) async {
    printSets.removeWhere((s) => s.id == id);
    basket.removeWhere((b) => b.bookId == id);
    notifyListeners();
    await designs.deletePrintSet(id);
    await designs.saveBasket(basket);
  }

  Future<PrintSet?> duplicatePrintSet(String id) async {
    final original = printSet(id);
    if (original == null) return null;
    final copy = original.clone()
      ..id = const Uuid().v4()
      ..title = '${original.title} (kopya)';
    for (var i = 0; i < copy.items.length; i++) {
      copy.items[i] = copy.items[i].copyWith(id: const Uuid().v4());
    }
    await savePrintSet(copy);
    return copy;
  }

  Future<void> addPrintSetToBasket(PrintSet set) async {
    final existing = basket.indexWhere((b) => b.bookId == set.id);
    final item = BasketItem(
      bookId: set.id,
      title: set.title.isEmpty ? S.printTitleDefault : set.title,
      productCode: set.productCode,
      pages: set.count,
      options: ProductOptions(),
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
