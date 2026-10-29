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
}
