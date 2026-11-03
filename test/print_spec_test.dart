import 'package:anilarin/models/print_set.dart';
import 'package:anilarin/print/print_spec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  test('katalog ölçüsü ayrıştırılır', () {
    expect(PrintSpec.parseCm('21 × 29.7'), (21.0, 29.7));
    expect(PrintSpec.parseCm('15 × 15'), (15.0, 15.0));
  });

  test('A4 dikey kitap: iç sayfa 210 × 297 mm net, kapak 3 mm taşmalı 216 × 303 mm', () {
    final product = loadTestCatalog().product('PBK-13');
    final inner = PrintSpec.book(product);
    expect(inner.widthMm, 210);
    expect(inner.heightMm, closeTo(297, 0.1));
    expect(inner.bleedPx, 0);
    expect((inner.fullWidthPx, inner.fullHeightPx), (2480, 3508));
    expect(inner.fullWidthPt, closeTo(595.28, 0.01));

    final cover = PrintSpec.book(product, cover: true);
    expect(cover.bleedPx, 35);
    expect((cover.fullWidthPx, cover.fullHeightPx), (2550, 3578));
    expect(cover.fullWidthMm, 216);
    expect(cover.fullHeightMm, closeTo(303, 0.1));
    expect(cover.fullWidthPt, closeTo(612.28, 0.01));
    expect(cover.label, startsWith('210 × 297 mm + 3 mm taşma = 216 × 303 mm'));
  });

  test('baskı net ölçüde; dikeyde kenarlar yer değiştirir, kare hep kare', () {
    final regular = PrintCatalog.byCode('PRN-R-M');
    final landscape = PrintSpec.print(regular, portrait: false);
    expect(landscape.bleedPx, 0);
    expect((landscape.fullWidthPx, landscape.fullHeightPx), (2126, 1535));
    expect(landscape.label, startsWith('180 × 130 mm net'));
    expect(PrintSpec.print(regular, portrait: true).widthMm, 130);
    final square = PrintCatalog.byCode('PRN-S-M');
    final s = PrintSpec.print(square, portrait: true);
    expect((s.widthMm, s.heightMm), (130.0, 130.0));
  });

  test('baskı klasör adı yönden bağımsız', () {
    expect(PrintSpec.sizeTag(PrintCatalog.byCode('PRN-R-M')), '18x13');
    expect(PrintSpec.sizeTag(PrintCatalog.byCode('PRN-R-XL')), '42x30');
    expect(PrintSpec.sizeTag(PrintCatalog.byCode('PRN-S-S')), '10x10');
  });
}
