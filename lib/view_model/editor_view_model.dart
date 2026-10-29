import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/catalog.dart';
import '../models/photo_book.dart';
import '../services/auto_layout_service.dart';

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

  PageTemplate templateOf(int pageIndex) => catalog.template(_book.pages[pageIndex].templateId);

  BookTheme themeOf(int pageIndex) =>
      catalog.theme(_book.pages[pageIndex].themeOverride ?? _book.themeId);

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

  List<PageTemplate> templatesFor(int pageIndex) {
    final cover = _book.pages[pageIndex].isCover;
    return catalog.templates.where((t) => t.isCover == cover).toList();
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

  void setTitle(String title, String subtitle) {
    _mutate((book) {
      book.title = title.trim();
      book.subtitle = subtitle.trim();
    });
  }

  void setCaption(int pageIndex, int textIndex, String text) {
    _mutate((book) {
      final page = book.pages[pageIndex];
      while (page.texts.length <= textIndex) {
        page.texts.add('');
      }
      page.texts[textIndex] = text.trim();
    });
  }

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

  /// Yeniden sıralama ekranından gelen yeni iç sayfa sırası (sayfa kimlikleri).
  void reorderInner(List<String> innerIds) {
    _mutate((book) {
      final byId = {for (final p in book.pages) p.id: p};
      book.pages = [book.cover, ...innerIds.map((id) => byId[id]!)];
    });
  }

  void setOptions(ProductOptions options) => _mutate((book) => book.options = options.copy());
}
