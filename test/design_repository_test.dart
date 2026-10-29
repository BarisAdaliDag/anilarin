import 'package:anilarin/models/address.dart';
import 'package:anilarin/models/basket_item.dart';
import 'package:anilarin/models/order.dart';
import 'dart:io';
import 'dart:math';

import 'package:anilarin/models/photo_book.dart';
import 'package:anilarin/repositories/design_repository.dart';
import 'package:anilarin/services/auto_layout_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  test('kitap ve sepet kaydedilip yüklenir', () async {
    final dir = await Directory.systemTemp.createTemp('anilarin_test');
    addTearDown(() => dir.delete(recursive: true));
    final repo = DesignRepository(root: dir);
    final catalog = loadTestCatalog();
    final book = AutoLayoutService(catalog, random: Random(3)).create(
      product: catalog.product('PBK-8'),
      photos: testPhotos(40),
      title: 'Tatil',
      options: ProductOptions(giftBox: true),
    );

    await repo.saveBook(book);
    final loaded = await repo.loadBooks();
    expect(loaded.single.encode(), book.encode());

    await repo.deleteBook(book.id);
    expect(await repo.loadBooks(), isEmpty);
  });

  test('fiyat: taban + ek sayfa + yükseltmeler', () {
    final catalog = loadTestCatalog();
    final p = catalog.product('PBK-8');
    final o = ProductOptions(giftBox: true, layflat: true, foil: 'gold');
    expect(p.totalPrice(p.pagesDefault + 4, o), p.priceCents + 4 * p.incrementPriceCents + 14900 + 19900 + 9900);
    final soft = catalog.product('PBK-3');
    expect(soft.optionsPrice(o), 14900); // yumuşak kapakta yalnız hediye kutusu
  });

  test('indirim kodu: hoş geldin %20, geçersiz kod reddedilir', () {
    expect(Coupon.byCode('hosgeldin'), Coupon.welcome);
    expect(Coupon.byCode('YANLIS'), isNull);
    expect(Coupon.welcome.apply(129800), 103840); // Popsa: 1.298 → 1.038,40
    expect(Coupon.welcome.discountOf(129800), 25960);
  });

  test('teslimat adresi kaydedilip yüklenir', () async {
    final dir = await Directory.systemTemp.createTemp('anilarin_address');
    final repo = DesignRepository(root: dir);
    expect(await repo.loadAddress(), isNull);
    await repo.saveAddress(
      Address(firstName: 'Ali', lastName: 'Veli', line1: 'Sultan Ahmet', postCode: '34122', city: 'İstanbul'),
    );
    final back = await repo.loadAddress();
    expect(back!.fullName, 'Ali Veli');
    expect(back.lines, contains('34122 İstanbul'));
    await dir.delete(recursive: true);
  });

  test('sipariş kaydedilip yüklenir', () async {
    final dir = await Directory.systemTemp.createTemp('anilarin_orders');
    final repo = DesignRepository(root: dir);
    final order = Order(
      reference: 'AN-1',
      createdAtMs: 1,
      items: [BasketItem(bookId: 'b', title: 'K', productCode: 'PBK-8', pages: 20, options: ProductOptions())],
      address: Address(firstName: 'Ali', lastName: 'Veli'),
      shippingId: ShippingOption.tracked.id,
      paymentMethod: 'gpay',
      totalCents: 100,
    );
    await repo.saveOrders([order]);
    final back = (await repo.loadOrders()).single;
    expect(back.reference, 'AN-1');
    expect(back.paymentMethod, 'gpay');
    expect(ShippingOption.byId(back.shippingId), ShippingOption.tracked);
    await dir.delete(recursive: true);
  });
}
