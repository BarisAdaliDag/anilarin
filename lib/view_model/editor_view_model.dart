import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show TextAlign;
import 'package:uuid/uuid.dart';

import '../models/catalog.dart';
import '../models/photo_book.dart';
import '../services/auto_layout_service.dart';
import '../services/palette_service.dart';

/// Bir sayfadaki fotoğraf alanının adresi.
@immutable
class SlotRef {
  final int page;
  final int slot;

  const SlotRef(this.page, this.slot);

  @override
  bool operator ==(Object other) => other is SlotRef && other.page == page && other.slot == slot;

  @override
  int get hashCode => Object.hash(page, slot);
}

enum ThemeScope { all, page, inside, cover }

/// Fotoğraf kitabı editörü. Her değişiklik geri alınabilir ve otomatik kaydedilir.
class EditorViewModel extends ChangeNotifier {
  EditorViewModel({
    required PhotoBook book,
    required this.catalog,
    this.onSave,
    this.saveDelay = const Duration(milliseconds: 400),
  }) : _book = book;

  final Catalog catalog;
  final Future<void> Function(PhotoBook book)? onSave;
  final Duration saveDelay;
  static const _uuid = Uuid();
  static const maxHistory = 50;

  PhotoBook _book;
  final List<String> _undo = [];
  final List<String> _redo = [];
  Timer? _saveTimer;
  String? message;

  PhotoBook get book => _book;

  Product get product => catalog.product(_book.productCode);

  String get format => product.format;

  bool get canUndo => _undo.isNotEmpty;

  bool get canRedo => _redo.isNotEmpty;

  bool get canAddPages => _book.pageCount < product.pagesMax;

  bool get canRemovePages => _book.pageCount > product.pagesMin;

  int get price => product.priceFor(_book.pageCount);

  /// Baskıdaki sayfa yüksekliği (cm), ör. "27 × 21" → 21.
  double get pageHeightCm => double.tryParse(product.dimensionsCm.split('×').last.trim()) ?? 21;

  PageTemplate templateOf(int pageIndex) => catalog.template(_book.pages[pageIndex].templateId);

  BookTheme themeOf(int pageIndex) => catalog.resolve(
    _book.themeIdOf(pageIndex),
    pagePalette: _book.pages[pageIndex].palette,
    bookPalette: _book.palette,
  );

  /// Fotoğrafları değişen sayfaların dinamik paletini arka planda yeniden hesaplar (geri al geçmişine girmez).
  /// Popsa'da dinamik tema her sayfada o sayfanın fotoğraflarının renklerini alır.
  /// [minLength]: bundan kısa (eski sürümde kaydedilmiş) paletler de yeniden hesaplanır.
  Future<void> refreshPagePalettes(
    Future<List<String>> Function(List<String> photoIds) compute, {
    int minLength = PaletteService.size,
  }) async {
    _paletteCompute = compute;
    if (_paletteBusy) {
      _paletteDirty = true; // çalışma bitince yeniden bakılır
      return;
    }
    _paletteBusy = true;
    var changed = false;
    try {
      if (_book.palette.length < minLength) {
        final ids = _book.pages.expand((p) => p.photoIds).take(PaletteService.maxPhotos).toList();
        if (ids.isNotEmpty) {
          _book.palette = await compute(ids);
          changed = true;
          notifyListeners();
        }
      }
      for (var i = 0; i < _book.pages.length; i++) {
        final page = _book.pages[i];
        final key = page.photoKey;
        if (key.isEmpty || (key == page.paletteKey && page.palette.length >= minLength)) continue;
        final pal = await compute(page.photoIds.toList());
        if (i >= _book.pages.length || _book.pages[i].id != page.id || _disposed) continue;
        page
          ..palette = pal
          ..paletteKey = key;
        changed = true;
        notifyListeners();
      }
      if (changed && onSave != null && !_disposed) await onSave!(_book);
    } finally {
      _paletteBusy = false;
    }
    if (_paletteDirty && !_disposed) {
      _paletteDirty = false;
      await refreshPagePalettes(compute, minLength: minLength);
    }
  }

  bool _paletteBusy = false;
  bool _paletteDirty = false;
  Future<List<String>> Function(List<String>)? _paletteCompute;
  bool _disposed = false;

  TextAppearance get textAppearance => catalog.textAppearance(_book.textAppearanceId);

  PhotoSlot? slotAt(SlotRef r) => _book.pages[r.page].photos[r.slot];

  BookPhoto? photo(String id) => _book.photos[id];

  // ---- geçmiş ----

  void _mutate(void Function(PhotoBook b) change) {
    _undo.add(_book.encode());
    if (_undo.length > maxHistory) _undo.removeAt(0);
    _redo.clear();
    change(_book);
    _changed();
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(_book.encode());
    _book = _decode(_undo.removeLast());
    _changed();
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(_book.encode());
    _book = _decode(_redo.removeLast());
    _changed();
  }

  PhotoBook _decode(String s) => PhotoBook.fromJson(jsonDecode(s) as Map<String, dynamic>);

  void _changed() {
    notifyListeners();
    final compute = _paletteCompute;
    if (compute != null) refreshPagePalettes(compute);
    if (onSave == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, () => onSave!(_book));
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    if (onSave != null) await onSave!(_book);
  }

  String? takeMessage() {
    final m = message;
    message = null;
    return m;
  }

  @override
  void dispose() {
    _disposed = true;
    // Bekleyen kaydı, ağaç kapanırken dinleyicileri tetiklememek için bir sonraki mikro göreve bırak.
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      final book = _book;
      Future.microtask(() => onSave?.call(book));
    }
    super.dispose();
  }

  // ---- fotoğraflar ----

  void swap(SlotRef a, SlotRef b) {
    if (a == b) return;
    _mutate((book) {
      final pa = book.pages[a.page].photos;
      final pb = book.pages[b.page].photos;
      final tmp = pa[a.slot];
      pa[a.slot] = pb[b.slot]?..resetCrop();
      pb[b.slot] = tmp?..resetCrop();
    });
  }

  void placeUnused(String photoId, SlotRef target) {
    _mutate((book) {
      final slots = book.pages[target.page].photos;
      final old = slots[target.slot];
      book.unusedPhotoIds.remove(photoId);
      if (old != null) book.unusedPhotoIds.insert(0, old.photoId);
      slots[target.slot] = PhotoSlot(photoId: photoId);
    });
  }

  void removePhoto(SlotRef r) {
    _mutate((book) {
      final old = book.pages[r.page].photos[r.slot];
      if (old == null) return;
      book.pages[r.page].photos[r.slot] = null;
      _returnToUnused(book, old.photoId);
    });
  }

  void replacePhoto(SlotRef r, BookPhoto photo) {
    _mutate((book) {
      book.photos[photo.id] = photo;
      book.unusedPhotoIds.remove(photo.id);
      final old = book.pages[r.page].photos[r.slot];
      book.pages[r.page].photos[r.slot] = PhotoSlot(photoId: photo.id);
      if (old != null && old.photoId != photo.id) _returnToUnused(book, old.photoId);
    });
  }

  void updateSlot(SlotRef r, PhotoSlot updated) {
    _mutate((book) => book.pages[r.page].photos[r.slot] = updated);
  }

  void addPhotos(List<BookPhoto> photos) {
    _mutate((book) {
      final used = book.usedPhotoIds;
      for (final p in photos) {
        book.photos[p.id] = p;
        if (!used.contains(p.id) && !book.unusedPhotoIds.contains(p.id)) book.unusedPhotoIds.add(p.id);
      }
    });
  }

  void discardUnused() {
    _mutate((book) {
      for (final id in book.unusedPhotoIds) {
        book.photos.remove(id);
      }
      book.unusedPhotoIds.clear();
    });
  }

  /// Fotoğraf hâlâ başka bir sayfada kullanılıyorsa (çoğaltılmış sayfa) tepsiye eklemez.
  void _returnToUnused(PhotoBook book, String photoId) {
    if (book.usedPhotoIds.contains(photoId) || book.unusedPhotoIds.contains(photoId)) return;
    book.unusedPhotoIds.insert(0, photoId);
  }

  // ---- şablon ----

  void changeTemplate(int pageIndex, int templateId) {
    final tpl = catalog.template(templateId);
    _mutate((book) {
      final page = book.pages[pageIndex];
      final current = page.photos.whereType<PhotoSlot>().toList();
      final slots = tpl.photoSlots(format);
      final keep = current.take(slots.length).toList();
      final assigned = AutoLayoutService.assignToSlots(
        slots,
        product.aspect,
        keep.map((s) => book.photos[s.photoId]!).toList(),
      );
      page.templateId = tpl.id;
      page.photos = assigned.map((p) => p == null ? null : PhotoSlot(photoId: p.id)).toList();
      final textCount = tpl.textSlots(format).length;
      page.texts = List<String>.generate(textCount, (i) => i < page.texts.length ? page.texts[i] : '');
      for (final s in current.skip(slots.length)) {
        _returnToUnused(book, s.photoId);
      }
    });
  }

  /// Popsa'nın kapak şablonu sırası; 25 (tam sayfa fotoğraf) ve 39 (yalnız başlık) iç sayfalarda da kullanılır.
  static const coverOrder = [1, 18, 19, 20, 25, 31, 32, 33, 34, 35, 39, 36, 37, 38];

  List<PageTemplate> templatesFor(int pageIndex) {
    if (_book.pages[pageIndex].isCover) {
      return [for (final id in coverOrder) catalog.template(id)];
    }
    return catalog.templates.where((t) => !t.isCover).toList();
  }

  // ---- tema / yazı ----

  void setTheme(String themeId, {ThemeScope scope = ThemeScope.all, int? pageIndex}) {
    _mutate((book) {
      switch (scope) {
        case ThemeScope.all:
          book.themeId = themeId;
          for (final p in book.pages) {
            p.themeOverride = null;
          }
        case ThemeScope.inside:
          for (final p in book.pages.where((p) => !p.isCover)) {
            p.themeOverride = themeId;
          }
        case ThemeScope.page:
          book.pages[pageIndex!].themeOverride = themeId;
        case ThemeScope.cover:
          book.cover.themeOverride = themeId;
      }
    });
  }

  void resetThemes() {
    _mutate((book) {
      for (final p in book.pages) {
        p.themeOverride = null;
      }
    });
  }

  bool get allBorderless => _book.pages.every((p) => p.borderless);

  void toggleBorderless(int pageIndex) =>
      _mutate((book) => book.pages[pageIndex].borderless = !book.pages[pageIndex].borderless);

  void setAllBorderless(bool value) => _mutate((book) {
    for (final p in book.pages) {
      p.borderless = value;
    }
  });

  void setTextAppearance(String id) => _mutate((book) => book.textAppearanceId = id);

  /// Kapak başlığı ve alt başlığı; [style] verilirse kapaktaki başlığın biçimi de değişir.
  void setTitle(String title, String subtitle, {TextSlotStyle? style}) {
    _mutate((book) {
      book.title = title.trim();
      book.subtitle = subtitle.trim();
      if (style != null) book.cover.textStyles[0] = style;
    });
  }

  void setCaption(int pageIndex, int textIndex, String text, {TextSlotStyle? style}) {
    _mutate((book) {
      final page = book.pages[pageIndex];
      while (page.texts.length <= textIndex) {
        page.texts.add('');
      }
      page.texts[textIndex] = text.trim();
      if (style != null) page.textStyles[textIndex] = style;
    });
  }

  /// Sayfa altyazısı: düzeni değiştirmez, sayfanın altına şerit olarak eklenir.
  void setPageCaption(
    int pageIndex,
    String text, {
    TextStyleId? style,
    TextAlign? align,
    String? font,
    bool clearFont = false,
    bool? top,
  }) => _mutate((book) {
    final p = book.pages[pageIndex];
    p.caption = text.trim();
    if (style != null) p.captionStyle = style;
    if (align != null) p.captionAlign = align;
    if (font != null || clearFont) p.captionFont = font;
    if (top != null) p.captionTop = top;
  });

  /// Sayfanın, varsa yazı alanı olan aynı fotoğraf sayısındaki şablona geçerek altyazı eklemesi.
  int? captionTemplateFor(int pageIndex) {
    final tpl = templateOf(pageIndex);
    if (tpl.textSlots(format).isNotEmpty) return tpl.id;
    final candidates = catalog.templates
        .where((t) => !t.isCover && t.photoCount == tpl.photoCount && t.textSlots(format).isNotEmpty)
        .toList();
    return candidates.isEmpty ? null : candidates.first.id;
  }

  // ---- sayfalar ----

  PrintPage _blankPage() {
    final tpl = catalog.template(3);
    return PrintPage(
      id: _uuid.v4(),
      tag: tpl.tag,
      templateId: tpl.id,
      photos: List<PhotoSlot?>.filled(tpl.photoSlots(format).length, null),
      texts: tpl.textSlots(format).map((_) => '').toList(),
    );
  }

  bool addPages(int count, {int? afterIndex}) {
    final room = product.pagesMax - _book.pageCount;
    if (room <= 0) {
      message = 'Kitap en fazla ${product.pagesMax} sayfa olabilir.';
      notifyListeners();
      return false;
    }
    _mutate((book) {
      final n = count.clamp(1, room);
      final at = (afterIndex ?? book.pages.length - 1) + 1;
      book.pages.insertAll(at, List.generate(n, (_) => _blankPage()));
    });
    return true;
  }

  bool removePages(Set<int> indices) {
    final valid = indices.where((i) => i > 0 && i < _book.pages.length).toSet();
    if (_book.pageCount - valid.length < product.pagesMin) {
      message = 'Kitap en az ${product.pagesMin} sayfa olmalı.';
      notifyListeners();
      return false;
    }
    _mutate((book) {
      final removed = [for (final i in valid) book.pages[i]];
      book.pages.removeWhere(removed.contains);
      for (final p in removed) {
        for (final id in p.photoIds) {
          _returnToUnused(book, id);
        }
      }
    });
    return true;
  }

  bool deletePage(int index) => removePages({index});

  bool duplicatePage(int index) {
    if (!canAddPages) {
      message = 'Kitap en fazla ${product.pagesMax} sayfa olabilir.';
      notifyListeners();
      return false;
    }
    _mutate((book) {
      final copy = PrintPage.fromJson(jsonDecode(jsonEncode(book.pages[index].toJson())) as Map<String, dynamic>);
      copy.id = _uuid.v4();
      book.pages.insert(index + 1, copy);
    });
    return true;
  }

  /// İç sayfa sırasını değiştirir. Kapak (0) taşınamaz. [from]/[to] `pages` listesindeki indekslerdir.
  void movePage(int from, int to) {
    if (from <= 0 || to <= 0 || from == to) return;
    _mutate((book) {
      final p = book.pages.removeAt(from);
      book.pages.insert(to.clamp(1, book.pages.length), p);
    });
  }

  /// [id]'yi [to] konumuna taşır; aradaki sayfalar birer kayar (sürükle-bırak önizlemesi).
  static List<String> movedOrder(List<String> ids, String id, int to) {
    final list = [...ids]..remove(id);
    list.insert(to.clamp(0, list.length), id);
    return list;
  }

  /// Yeniden sıralama ekranından gelen yeni iç sayfa sırası (sayfa kimlikleri).
  void reorderInner(List<String> innerIds) {
    _mutate((book) {
      final byId = {for (final p in book.pages) p.id: p};
      book.pages = [book.cover, ...innerIds.map((id) => byId[id]!)];
    });
  }

  /// Kitabı aynı biçimde başka bir ürüne (tür/boyut) taşır. Sayfa sayısı yeni ürünün sınırını aşıyorsa olmaz.
  bool changeProduct(String code) {
    final next = catalog.product(code);
    if (code == _book.productCode || next.format != product.format) return false;
    if (_book.pageCount > next.pagesMax) return false;
    _mutate((book) => book.productCode = code);
    return true;
  }

  void setGloss(bool gloss) {
    if (_book.options.gloss == gloss) return;
    _mutate((book) => book.options = book.options.copy()..gloss = gloss);
  }

  void setOptions(ProductOptions options) => _mutate((book) => book.options = options.copy());
}
