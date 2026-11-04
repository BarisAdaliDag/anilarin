import 'dart:math';

import 'package:anilarin/models/photo_book.dart';
import 'package:anilarin/services/auto_layout_service.dart';
import 'package:anilarin/view_model/editor_view_model.dart';
import 'package:anilarin/views/widgets/print_page_view.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  final catalog = loadTestCatalog();

  EditorViewModel make({int photos = 60, String product = 'PBK-11'}) {
    final book = AutoLayoutService(
      catalog,
      random: Random(2),
    ).create(product: catalog.product(product), photos: testPhotos(photos), title: 'Test');
    return EditorViewModel(book: book, catalog: catalog);
  }

  int firstFilledPage(EditorViewModel vm, {int from = 1}) => List.generate(
    vm.book.pages.length,
    (i) => i,
  ).firstWhere((i) => i >= from && vm.book.pages[i].photoIds.length >= 2);

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

  test('azami sayfada sayfa eklenemez', () {
    final vm = make(product: 'PBK-1', photos: 200);
    expect(vm.book.pageCount, vm.product.pagesMax);
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

  test('sürüklenen sayfa araya girer, diğerleri kayar', () {
    const ids = ['1', '2', '3', '4', '5'];
    expect(EditorViewModel.movedOrder(ids, '5', 1), ['1', '5', '2', '3', '4']);
    expect(EditorViewModel.movedOrder(ids, '2', 2), ['1', '3', '2', '4', '5']);
    expect(EditorViewModel.movedOrder(ids, '1', 9), ['2', '3', '4', '5', '1']);
  });

  test('yükseltmeler: tür ve boyut değişir, sayfa sınırı aşılmaz, kâğıt kaydedilir', () {
    final vm = make(product: 'PBK-8');
    final soft = vm.catalog.closestOfType(vm.product, 'softcover')!;
    expect(soft.code, 'PBK-4'); // aynı boyut (büyük) korunur
    expect(vm.changeProduct(soft.code), isTrue);
    expect(vm.product.type, 'softcover');
    // Kitapçıkta büyük yok, en yakın orta seçilir
    expect(vm.catalog.closestOfType(vm.product, 'booklet')!.code, 'PBK-1');
    vm.addPages(vm.product.pagesMax - vm.book.pageCount);
    expect(vm.changeProduct('PBK-1'), isFalse); // 40 sayfayı aşıyor
    expect(vm.catalog.sizesOf('hardback', 'landscape').map((p) => p.size), ['medium', 'large', 'xlarge']);
    vm.setGloss(true);
    expect(vm.book.options.gloss, isTrue);
    vm.undo();
    expect(vm.book.options.gloss, isFalse);
  });

  test('sipariş ayrıntıları: parlak kâğıt fiyatı, üstü çizili toplam, ölçü etiketi', () {
    final vm = make(product: 'PBK-8');
    final p = vm.product;
    final base = p.totalPrice(vm.book.pageCount, vm.book.options);
    vm.setGloss(true);
    expect(p.totalPrice(vm.book.pageCount, vm.book.options), base + p.glossPriceCents);
    expect(p.glossPriceCents, 17100); // 900 TL'nin ~%19'u
    expect(p.compareTotal(20, vm.book.options) - p.totalPrice(20, vm.book.options), p.compareAtCents - p.priceCents);
    expect(p.dimensionsLabel(), '27cm × 21cm');
    expect(p.dimensionsLabel(inches: true), '10.6in × 8.3in');
  });

  test('tema kapsamları', () {
    final vm = make();
    vm.setTheme('#1E1E1E', scope: ThemeScope.page, pageIndex: 2);
    expect(vm.themeOf(2).id, '#1E1E1E');
    expect(vm.themeOf(2).title, const Color(0xFFFFFFFF));
    expect(vm.themeOf(3).id, vm.book.themeId);
    vm.setTheme('#F7F3EC', scope: ThemeScope.inside);
    expect(vm.themeOf(5).id, '#F7F3EC');
    vm.setTheme('#AA0000', scope: ThemeScope.cover);
    expect(vm.themeOf(0).id, '#AA0000');
    vm.setTheme('#FFFFFF');
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
    final tplBefore = vm.book.pages[1].templateId;
    vm.setPageCaption(1, ' Deniz kenarı ');
    expect(vm.book.pages[1].caption, 'Deniz kenarı');
    expect(vm.book.pages[1].templateId, tplBefore); // altyazı düzeni değiştirmez
  });

  test('kenarlıksız sayfa ve tümü', () {
    final vm = make();
    vm.toggleBorderless(1);
    expect(vm.book.pages[1].borderless, isTrue);
    vm.setAllBorderless(true);
    expect(vm.allBorderless, isTrue);
    vm.undo();
    expect(vm.allBorderless, isFalse);
  });

  test('ızgara şablonlarında boşluklar daralır, altyazı fotoğrafları yukarı sıkıştırır', () {
    final tpl = catalog.template(5); // 2x2 ızgara
    final tight = tightenGutters(tpl.elementsFor('square')).map((e) => e.frame).toList();
    expect(tight[0].left, closeTo(4.5, 0.01));
    expect(tight[1].left - tight[0].right, closeTo(1.8, 0.01));
    expect(tight[2].top - tight[0].bottom, closeTo(2.4, 0.01));
    // Dikey (A4) sayfada üst/alt boşluk oranla incelir: gerçek kalınlık kare sayfadakiyle aynı.
    final a4 = tightenGutters(tpl.elementsFor('portrait'), aspect: 0.7071).map((e) => e.frame).toList();
    expect(a4[0].left, closeTo(4.5, 0.01));
    expect(a4[0].top, closeTo(6 * 0.7071, 0.01));
    // 3 sıra / 3 sütun: her komşu arasında aynı ince boşluk; uzaktaki komşu fotoğrafları üst üste bindirmez.
    final rows = tightenGutters(catalog.template(78).elementsFor('portrait'), aspect: 0.7071).map((e) => e.frame);
    final r = rows.toList();
    expect(r[1].top - r[0].bottom, closeTo(2.4 * 0.7071, 0.01));
    expect(r[2].top - r[1].bottom, closeTo(2.4 * 0.7071, 0.01));
    final cols = tightenGutters(catalog.template(16).elementsFor('square')).map((e) => e.frame).toList();
    expect(cols[1].left - cols[0].right, closeTo(1.8, 0.01));
    expect(cols[2].left - cols[1].right, closeTo(1.8, 0.01));
    final page = PrintPage(id: 'x', tag: 'layout-regular', templateId: 5, photos: [], texts: [], caption: 'Merhaba');
    // Dikeyde üstteki yazı kenara yapışmaz; şerit büyür, fotoğraflar şeridin altından başlar. Karede değişmez.
    final topPage = PrintPage(
      id: 'y',
      tag: 'layout-regular',
      templateId: 76,
      photos: [],
      texts: [],
      caption: 'Merhaba',
      captionTop: true,
    );
    expect(captionTopInset(1), 0);
    expect(captionTopInset(0.7071), greaterThan(1));
    final topBand = captionBandFor(topPage, 0.7071);
    final topLaid = pageLayout(topPage, catalog.template(76), 'portrait', 0.7071);
    expect(topLaid.map((e) => e.frame.top).reduce(min), greaterThanOrEqualTo(topBand));
    final laid = pageLayout(page, tpl, 'square', 1);
    final band = captionBandFor(page, 1);
    final bottom = laid.map((e) => e.frame.bottom).reduce((a, b) => a > b ? a : b);
    expect(bottom, lessThanOrEqualTo(100 - band));
    // Gövde stili başlıktan daha dar şerit kaplar; üstteki yazı fotoğrafları aşağı iter.
    page.captionStyle = TextStyleId.heading2;
    expect(captionBandFor(page, 1), greaterThan(band));
    page.captionTop = true;
    final top = pageLayout(page, tpl, 'square', 1).map((e) => e.frame.top).reduce((a, b) => a < b ? a : b);
    expect(top, greaterThanOrEqualTo(captionBandFor(page, 1)));
  });

  test('altyazı stili, hizalama ve yazı tipi kaydedilir', () {
    final vm = make();
    vm.setPageCaption(1, 'Merhaba', style: TextStyleId.heading3, align: TextAlign.center, font: 'classic');
    final p = PrintPage.fromJson(vm.book.pages[1].toJson());
    expect(p.captionStyle, TextStyleId.heading3);
    expect(p.captionAlign, TextAlign.center);
    expect(p.captionFont, 'classic');
    vm.setPageCaption(1, 'Merhaba', clearFont: true);
    expect(vm.book.pages[1].captionFont, isNull);
    expect(TextStyleId.heading3.charLimit, 24);
  });

  test('şablon yazı alanı biçimi kaydedilir', () {
    final vm = make();
    vm.changeTemplate(1, 41); // fotoğraf + yazı sütunu
    vm.setCaption(
      1,
      0,
      'Merhaba',
      style: TextSlotStyle(style: TextStyleId.heading4, align: TextAlign.right, valign: TextVAlign.center),
    );
    final p = PrintPage.fromJson(vm.book.pages[1].toJson());
    expect(p.texts.first, 'Merhaba');
    expect(p.textStyles[0]!.style, TextStyleId.heading4);
    expect(p.textStyles[0]!.valign, TextVAlign.center);
    expect(p.textStyles[0]!.align, TextAlign.right);
  });

  test('kapak başlığı biçimi kaydedilir', () {
    final vm = make();
    vm.setTitle(
      'Yaz 2026',
      'Haz – Ağu 2026',
      style: TextSlotStyle(style: TextStyleId.heading2, align: TextAlign.left, valign: TextVAlign.bottom),
    );
    final b = PhotoBook.fromJson(vm.book.toJson());
    expect(b.title, 'Yaz 2026');
    expect(b.cover.textStyles[0]!.style, TextStyleId.heading2);
    expect(b.cover.textStyles[0]!.valign, TextVAlign.bottom);
    vm.undo();
    expect(vm.book.cover.textStyles[0], isNull);
  });

  test('dinamik tema her sayfada o sayfanın paletini kullanır', () async {
    final vm = make();
    await vm.refreshPagePalettes(
      (ids) async => [
        '#111111',
        '#222222',
        ids.first == vm.book.pages[1].photoIds.first ? '#AA0000' : '#00AA00',
        '#333333',
        '#444444',
      ],
      minLength: 5,
    );
    vm.setTheme('dyn:2', scope: ThemeScope.inside);
    expect(vm.themeOf(1).background, const Color(0xFFAA0000));
    expect(vm.themeOf(2).background, const Color(0xFF00AA00));
    // fotoğraflar değişince palet yeniden hesaplanır
    final key = vm.book.pages[1].paletteKey;
    vm.swap(SlotRef(1, 0), SlotRef(2, 0));
    await Future<void>.delayed(Duration.zero);
    expect(vm.book.pages[1].paletteKey, isNot(key));
  });

  test('kenarlıksız: boşluklar kapanır, kenarlara uzanır, yazı sütunu korunur', () {
    final catalog = loadTestCatalog();
    // 2x2 ızgara: boşluk kalmaz, sayfayı kaplar
    final grid = borderlessElements(catalog.template(5).elementsFor('square')).map((e) => e.frame).toList();
    final u = grid.reduce((a, b) => a.expandToInclude(b));
    expect(u, const Rect.fromLTRB(0, 0, 100, 100));
    expect(grid[1].left - grid[0].right, closeTo(0, 0.01));
    // yazı sütunlu şablon (41): fotoğraf yazının üstüne taşmaz
    final els = borderlessElements(catalog.template(41).elementsFor('square'));
    final photo = els.firstWhere((e) => e.isPhoto).frame;
    final text = els.firstWhere((e) => !e.isPhoto).frame;
    expect(photo.overlaps(text), isFalse);
    expect(photo.right, closeTo(100, 0.01));
  });

  test('json gidiş-dönüş', () {
    final vm = make();
    final copy = PhotoBook.fromJson(vm.book.toJson());
    expect(copy.encode(), vm.book.encode());
  });
}
