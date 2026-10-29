import 'dart:math';

import 'package:anilarin/models/photo_book.dart';
import 'package:anilarin/services/auto_layout_service.dart';
import 'package:anilarin/view_model/editor_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  final catalog = loadTestCatalog();

  EditorViewModel make({int photos = 60, String product = 'PBK-11'}) {
    final book = AutoLayoutService(catalog, random: Random(2))
        .create(product: catalog.product(product), photos: testPhotos(photos), title: 'Test');
    return EditorViewModel(book: book, catalog: catalog);
  }

  int firstFilledPage(EditorViewModel vm, {int from = 1}) =>
      List.generate(vm.book.pages.length, (i) => i).firstWhere((i) => i >= from && vm.book.pages[i].photoIds.length >= 2);

  test('swap iki alanı değiştirir ve geri alınabilir', () {
    final vm = make();
    final p = firstFilledPage(vm);
    final a = SlotRef(p, 0), b = SlotRef(p, 1);
    final idA = vm.slotAt(a)!.photoId, idB = vm.slotAt(b)!.photoId;
    vm.swap(a, b);
    expect(vm.slotAt(a)!.photoId, idB);
    expect(vm.slotAt(b)!.photoId, idA);
    vm.undo();
    expect(vm.slotAt(a)!.photoId, idA);
    vm.redo();
    expect(vm.slotAt(a)!.photoId, idB);
  });

  test('kaldırılan fotoğraf tepsiye gider, tepsiden geri yerleşir', () {
    final vm = make();
    final ref = SlotRef(firstFilledPage(vm), 0);
    final id = vm.slotAt(ref)!.photoId;
    vm.removePhoto(ref);
    expect(vm.slotAt(ref), isNull);
    expect(vm.book.unusedPhotoIds.first, id);
    vm.placeUnused(id, ref);
    expect(vm.slotAt(ref)!.photoId, id);
    expect(vm.book.unusedPhotoIds, isNot(contains(id)));
  });

  test('daha az alanlı şablon fazla fotoğrafları tepsiye taşır', () {
    final vm = make();
    final p = firstFilledPage(vm);
    final before = vm.book.pages[p].photoIds.length;
    vm.changeTemplate(p, 3); // tek fotoğraf
    expect(vm.book.pages[p].photoIds.length, 1);
    expect(vm.book.unusedPhotoIds.length, before - 1);
    final total = vm.book.usedPhotoIds.length + vm.book.unusedPhotoIds.length;
    expect(total, 60);
  });

  test('sayfa ekleme/kaldırma ürün sınırlarına uyar', () {
    final vm = make(photos: 30);
    final min = vm.product.pagesMin;
    expect(vm.book.pageCount, min);
    expect(vm.removePages({1}), isFalse);
    expect(vm.addPages(2), isTrue);
    expect(vm.book.pageCount, min + 2);
    expect(vm.removePages({1, 2}), isTrue);
    expect(vm.book.pageCount, min);
  });

  test('kitapçıkta sayfa eklenemez', () {
    final vm = make(product: 'PBK-1');
    expect(vm.canAddPages, isFalse);
    expect(vm.addPages(1), isFalse);
  });

  test('yeniden sıralama kapağı yerinde tutar', () {
    final vm = make();
    final ids = vm.book.innerPages.map((p) => p.id).toList();
    vm.reorderInner(ids.reversed.toList());
    expect(vm.book.pages.first.isCover, isTrue);
    expect(vm.book.pages[1].id, ids.last);
  });

  test('tema kapsamları', () {
    final vm = make();
    vm.setTheme('dark', scope: ThemeScope.page, pageIndex: 2);
    expect(vm.themeOf(2).id, 'dark');
    expect(vm.themeOf(3).id, vm.book.themeId);
    vm.setTheme('rose', scope: ThemeScope.inside);
    expect(vm.themeOf(5).id, 'rose');
    expect(vm.themeOf(0).id, vm.book.themeId);
    vm.setTheme('honey');
    expect(vm.book.pages.every((p) => p.themeOverride == null), isTrue);
  });

  test('çoğaltılan sayfadaki fotoğraf silinince tepsiye eklenmez (hâlâ kullanımda)', () {
    final vm = make();
    final p = firstFilledPage(vm);
    vm.duplicatePage(p);
    final ref = SlotRef(p, 0);
    final id = vm.slotAt(ref)!.photoId;
    vm.removePhoto(ref);
    expect(vm.book.unusedPhotoIds, isNot(contains(id)));
  });

  test('altyazı ve fiyat', () {
    final vm = make(photos: 30);
    final base = vm.price;
    vm.addPages(2);
    expect(vm.price, base + 2 * vm.product.incrementPriceCents);
    final tpl = vm.captionTemplateFor(1);
    expect(tpl, isNotNull);
    vm.changeTemplate(1, tpl!);
    vm.setCaption(1, 0, ' Deniz kenarı ');
    expect(vm.book.pages[1].texts.first, 'Deniz kenarı');
  });

  test('json gidiş-dönüş', () {
    final vm = make();
    final copy = PhotoBook.fromJson(vm.book.toJson());
    expect(copy.encode(), vm.book.encode());
  });
}
