import 'dart:math';

import 'package:anilarin/models/photo_book.dart';
import 'package:anilarin/services/auto_layout_service.dart';
import 'package:anilarin/services/palette_service.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  final catalog = loadTestCatalog();
  final service = AutoLayoutService(catalog, random: Random(1));

  group('distribute', () {
    test('eşit dağıtır, artanları ortadan dışa ekler', () {
      expect(AutoLayoutService.distribute(10, 4, maxPerPage: 9), [2, 3, 3, 2]);
      expect(AutoLayoutService.distribute(7, 5, maxPerPage: 9), [1, 2, 2, 1, 1]);
    });

    test('sayfa başı sınırı aşmaz', () {
      final counts = AutoLayoutService.distribute(100, 4, maxPerPage: 9);
      expect(counts.every((c) => c <= 9), isTrue);
      expect(counts.reduce((a, b) => a + b), 36);
    });

    test('ortadan dışa sıra', () {
      expect(AutoLayoutService.middleOutOrder(5), [2, 1, 3, 0, 4]);
    });
  });

  group('sortPhotos', () {
    test('tarihsizler önce, sonra tarih sırası', () {
      final photos = [
        BookPhoto(id: 'b', width: 1, height: 1, takenAtMs: 200),
        BookPhoto(id: 'u', width: 1, height: 1),
        BookPhoto(id: 'a', width: 1, height: 1, takenAtMs: 100),
      ];
      expect(AutoLayoutService.sortPhotos(photos).map((p) => p.id), ['u', 'a', 'b']);
    });
  });

  group('create', () {
    test('kapak + ürün sınırları içinde iç sayfalar, tüm fotoğraflar yerleşir', () {
      final product = catalog.product('PBK-11');
      final photos = testPhotos(60);
      final book = service.create(product: product, photos: photos, title: 'Yaz');

      expect(book.cover.isCover, isTrue);
      expect(book.pageCount, greaterThanOrEqualTo(product.pagesMin));
      expect(book.pageCount, lessThanOrEqualTo(product.pagesMax));
      expect(book.pageCount.isEven, isTrue);
      final placed = book.usedPhotoIds.length + book.unusedPhotoIds.length;
      expect(placed, 60);
      expect(book.unusedPhotoIds, isEmpty);
      expect(book.coverPhotoId, 'p0');
    });

    test('her sayfa şablon kapasitesine uyar', () {
      final product = catalog.product('PBK-3');
      final book = service.create(product: product, photos: testPhotos(90), title: 'x');
      for (final page in book.pages) {
        final tpl = catalog.template(page.templateId);
        expect(page.photos.length, tpl.photoSlots(product.format).length);
      }
    });

    test('azami sayfa sayısını aşmaz, sığmayanlar kullanılmayanlara gider', () {
      final product = catalog.product('PBK-1');
      final book = service.create(product: product, photos: testPhotos(400), title: 'x');
      expect(book.pageCount, product.pagesMax);
      expect(book.usedPhotoIds.length + book.unusedPhotoIds.length, 400);
      expect(book.unusedPhotoIds, isNotEmpty);
    });

    test('fotoğraflar en-boy oranına uygun alanlara yerleşir', () {
      final tpl = catalog.template(4); // iki dikey alan
      final slots = tpl.photoSlots('square');
      final portrait = BookPhoto(id: 'v', width: 3000, height: 4000);
      final landscape = BookPhoto(id: 'h', width: 4000, height: 3000);
      final result = AutoLayoutService.assignToSlots(slots, 1, [landscape, portrait]);
      expect(result.whereType<BookPhoto>().length, 2);
    });
  });

  test('fotoğraf alandan azsa en büyük alan doldurulur', () {
    final tpl = catalog.template(53); // üst üste: büyük arka + küçük ön
    final slots = tpl.photoSlots('landscape');
    final result = AutoLayoutService.assignToSlots(slots, 1.3, [BookPhoto(id: 'a', width: 4000, height: 3000)]);
    final big = slots[0].frame.width * slots[0].frame.height > slots[1].frame.width * slots[1].frame.height ? 0 : 1;
    expect(result[big]?.id, 'a');
  });

  test('tarih aralığı etiketi', () {
    final photos = [
      BookPhoto(id: 'a', width: 1, height: 1, takenAtMs: DateTime(2024, 9, 3).millisecondsSinceEpoch),
      BookPhoto(id: 'b', width: 1, height: 1, takenAtMs: DateTime(2026, 10, 20).millisecondsSinceEpoch),
    ];
    expect(AutoLayoutService.dateRangeLabel(photos), 'Eyl 2024 – Eki 2026');
  });

  test('palet kapağa uygulanır, iç sayfalar beyaz', () {
    final palette = PaletteService.fromRgb([200, 30, 30, 180, 20, 20, 240, 240, 240]);
    expect(palette.length, 5);
    final book = service.create(product: catalog.product('PBK-8'), photos: testPhotos(30), title: 'x', palette: palette);
    expect(book.cover.themeOverride, 'dyn:3');
    expect(catalog.resolve('dyn:3', bookPalette: book.palette).background, catalog.theme(palette[3]).background);
    expect(book.themeId, '#FFFFFF');
    // baskın ton kırmızı olmalı
    final vibrant = HSLColor.fromColor(catalog.theme(palette[2]).background);
    expect(vibrant.hue < 20 || vibrant.hue > 340, isTrue);
  });

  test('başlık önerileri tarih aralığından üretilir', () {
    final photos = [
      BookPhoto(id: 'a', width: 1, height: 1, takenAtMs: DateTime(2025, 7, 3).millisecondsSinceEpoch),
      BookPhoto(id: 'b', width: 1, height: 1, takenAtMs: DateTime(2025, 7, 20).millisecondsSinceEpoch),
    ];
    final s = AutoLayoutService.titleSuggestions(photos);
    expect(s.first, 'Temmuz 2025');
    expect(s, contains('2025 Anıları'));
  });
}
