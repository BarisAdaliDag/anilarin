import 'dart:io';

import 'package:anilarin/models/photo_book.dart';
import 'package:anilarin/models/print_set.dart';
import 'package:anilarin/repositories/design_repository.dart';
import 'package:flutter_test/flutter_test.dart';

PrintSet _set(int n, {String code = 'PRN-R-M'}) => PrintSet(
  id: 's1',
  title: 'Düğün',
  subtitle: 'Kas 2025',
  productCode: code,
  updatedAtMs: 1,
  items: [
    for (var i = 0; i < n; i++)
      PrintItem(
        id: 'p$i',
        photo: BookPhoto(id: 'a$i', width: i.isOdd ? 900 : 1600, height: 1200),
      ),
  ],
);

void main() {
  test('birim fiyat kademeleri Popsa pencereyle aynı (Normal Orta)', () {
    final p = PrintCatalog.byCode('PRN-R-M');
    expect(p.listCents, 1600);
    expect([30, 100, 200, 400].map((n) => PrintProduct.unitCents(p.listCents, n)), [1600, 1440, 1280, 1120]);
    expect(PrintProduct.discountPercent(29), 0);
    expect(PrintProduct.discountPercent(150), 10);
    expect(PrintProduct.discountPercent(500), 30);
  });

  test('toplam ve üstü çizili fiyat, başlık fiyatı', () {
    final p = PrintCatalog.byCode('PRN-R-M');
    expect(p.totalCents(100), 1440 * 100);
    expect(p.compareCents(100), 1600 * 100);
    expect(p.headlineCents, 1280);
    expect(PrintCatalog.byCode('PRN-R-S').headlineCents, 1360);
    expect(PrintCatalog.byCode('PRN-R-L').headlineCents, 5600);
    expect(PrintCatalog.byCode('PRN-R-XL').headlineCents, 9600);
    expect(PrintCatalog.byCode('PRN-S-S').headlineCents, 960);
  });

  test('ölçü etiketi ve yön', () {
    final p = PrintCatalog.byCode('PRN-R-M');
    expect(p.dimensions(), '18cm × 13cm');
    expect(p.dimensions(inches: true), '7.1in × 5.1in');
    expect(PrintCatalog.isPrintCode('PRN-S-L'), isTrue);
    expect(PrintCatalog.isPrintCode('PBK-8'), isFalse);
    final s = _set(2);
    expect(s.items[0].portrait, isFalse); // yatay fotoğraf
    expect(s.items[1].portrait, isTrue); // dik fotoğraf
  });

  test('baskı seti kaydedilip yüklenir, silinir', () async {
    final dir = await Directory.systemTemp.createTemp('anilarin_prints');
    final repo = DesignRepository(root: dir);
    final set = _set(3)
      ..colorHex = '#7A1F2B'
      ..items[1].caption = 'Gelin'
      ..items[2].border = false;
    await repo.savePrintSet(set);
    final back = (await repo.loadPrintSets()).single;
    expect(back.title, 'Düğün');
    expect(back.colorHex, '#7A1F2B');
    expect(back.items[1].caption, 'Gelin');
    expect(back.items[2].border, isFalse);
    expect(back.count, 3);
    await repo.deletePrintSet('s1');
    expect(await repo.loadPrintSets(), isEmpty);
    await dir.delete(recursive: true);
  });
}
