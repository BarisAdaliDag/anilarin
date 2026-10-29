import 'dart:math';

import 'package:anilarin/models/photo_book.dart';
import 'package:anilarin/services/auto_layout_service.dart';
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

    test('kitapçık sabit sayfa sayısında kalır, sığmayanlar kullanılmayanlara gider', () {
      final product = catalog.product('PBK-1');
      final book = service.create(product: product, photos: testPhotos(250), title: 'x');
      expect(book.pageCount, 20);
      expect(book.usedPhotoIds.length + book.unusedPhotoIds.length, 250);
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
