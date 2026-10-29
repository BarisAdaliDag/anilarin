import 'dart:math';

import 'package:uuid/uuid.dart';

import '../models/catalog.dart';
import '../models/photo_book.dart';

/// Seçilen fotoğraflardan otomatik fotoğraf kitabı oluşturur.
///
/// Akış (Popsa'nın cihaz üstü yerleşimiyle aynı mantık):
/// 1. Fotoğrafları sırala: tarihsizler önce, sonra çekim tarihine göre.
/// 2. Kapak = ilk fotoğraf.
/// 3. İç sayfa sayısını ürün sınırları içinde, sayfa başı ~3 fotoğraf olacak şekilde belirle.
/// 4. Fotoğrafları sayfalara eşit dağıt; artanları ortadan dışa doğru ekle.
/// 5. Her sayfa için fotoğraf sayısına uygun otomatik şablon seç.
/// 6. Fotoğrafları en-boy oranı en iyi eşleşen alanlara yerleştir.
class AutoLayoutService {
  AutoLayoutService(this.catalog, {Random? random}) : _random = random ?? Random();

  final Catalog catalog;
  final Random _random;
  static const _uuid = Uuid();
  static const targetPhotosPerPage = 3;
  static const defaultCoverTemplate = 18; // çerçeveli fotoğraf + altında başlık (Popsa varsayılanı)
  static const defaultInnerTheme = '#FFFFFF';

  PhotoBook create({
    required Product product,
    required List<BookPhoto> photos,
    required String title,
    String subtitle = '',
    ProductOptions? options,
    List<String> palette = const [],
  }) {
    final sorted = sortPhotos(photos);
    final now = DateTime.now().millisecondsSinceEpoch;
    final format = product.format;

    final coverTpl = catalog.template(defaultCoverTemplate);
    final coverPhoto = sorted.isEmpty ? null : sorted.first;
    final cover = PrintPage(
      id: _uuid.v4(),
      tag: 'layout-front',
      templateId: coverTpl.id,
      photos: List<PhotoSlot?>.filled(coverTpl.photoSlots(format).length, null),
      texts: coverTpl.textSlots(format).map((_) => '').toList(),
    );
    if (coverPhoto != null && cover.photos.isNotEmpty) cover.photos[0] = PhotoSlot(photoId: coverPhoto.id);

    final rest = sorted.skip(1).toList();
    final pageCount = pageCountFor(product, rest.length);
    final counts = distribute(rest.length, pageCount, maxPerPage: maxAutoCapacity);
    final unused = <String>[];

    final pages = <PrintPage>[cover];
    var cursor = 0;
    int? previousTemplate;
    for (final n in counts) {
      final pagePhotos = rest.sublist(cursor, cursor + n);
      cursor += n;
      final tpl = pickTemplate(n, avoid: previousTemplate);
      previousTemplate = tpl.id;
      pages.add(buildPage(tpl, format, product.aspect, pagePhotos));
    }
    unused.addAll(rest.sublist(cursor).map((p) => p.id));

    // Kapak fotoğraflardan gelen zengin renkte, iç sayfalar beyaz (Popsa'nın ilk görünümü).
    if (palette.length >= 4) cover.themeOverride = palette[3];
    return PhotoBook(
      id: _uuid.v4(),
      productCode: product.code,
      title: title,
      subtitle: subtitle,
      themeId: defaultInnerTheme,
      textAppearanceId: catalog.textAppearances.first.id,
      pages: pages,
      unusedPhotoIds: unused,
      photos: {for (final p in photos) p.id: p},
      options: options ?? ProductOptions(),
      palette: palette,
      createdAtMs: now,
      updatedAtMs: now,
    );
  }

  static List<BookPhoto> sortPhotos(List<BookPhoto> photos) {
    final undated = photos.where((p) => p.takenAtMs == null).toList();
    final dated = photos.where((p) => p.takenAtMs != null).toList()
      ..sort((a, b) => a.takenAtMs!.compareTo(b.takenAtMs!));
    return [...undated, ...dated];
  }

  Set<int> get autoCounts => {
        for (final t in catalog.templates)
          if (t.automaticUse && !t.isCover) t.photoCount,
      };

  int get maxAutoCapacity => autoCounts.reduce(max);

  /// Sayfa başı hedef fotoğrafa göre çift sayıya yuvarlanmış, ürün sınırlarıyla kısıtlı sayfa sayısı.
  int pageCountFor(Product product, int photoCount) {
    var pages = (photoCount / targetPhotosPerPage).ceil();
    final inc = product.pageIncrement;
    if (pages % inc != 0) pages += inc - pages % inc;
    return pages.clamp(product.pagesDefault, product.pagesMax);
  }

  /// [total] fotoğrafı [pages] sayfaya dağıtır. Artanlar ortadaki sayfalardan başlayarak dışa doğru eklenir.
  /// Hiçbir sayfa [maxPerPage]'i aşmaz; sığmayanlar dağıtılmaz (kullanılmayan fotoğraflara gider).
  static List<int> distribute(int total, int pages, {required int maxPerPage}) {
    if (pages <= 0) return [];
    final base = min(total ~/ pages, maxPerPage);
    final counts = List<int>.filled(pages, base);
    var remaining = total - base * pages;
    final order = middleOutOrder(pages);
    var progressed = true;
    while (remaining > 0 && progressed) {
      progressed = false;
      for (final i in order) {
        if (remaining == 0) break;
        if (counts[i] < maxPerPage) {
          counts[i]++;
          remaining--;
          progressed = true;
        }
      }
    }
    return counts;
  }

  static List<int> middleOutOrder(int n) {
    final mid = (n - 1) / 2;
    final idx = List<int>.generate(n, (i) => i);
    idx.sort((a, b) {
      final c = (a - mid).abs().compareTo((b - mid).abs());
      return c != 0 ? c : a.compareTo(b);
    });
    return idx;
  }

  /// [n] fotoğrafa uygun otomatik şablon. Tam eşleşme yoksa daha büyük en yakın kapasite seçilir.
  PageTemplate pickTemplate(int n, {int? avoid}) {
    final auto = catalog.templates.where((t) => t.automaticUse && !t.isCover).toList();
    var candidates = auto.where((t) => t.photoCount == n).toList();
    if (candidates.isEmpty) {
      final bigger = auto.where((t) => t.photoCount >= n).map((t) => t.photoCount).toList()..sort();
      final cap = bigger.isEmpty ? auto.map((t) => t.photoCount).reduce(max) : bigger.first;
      candidates = auto.where((t) => t.photoCount == cap).toList();
    }
    if (candidates.length > 1 && avoid != null) {
      candidates = candidates.where((t) => t.id != avoid).toList();
    }
    return candidates[_random.nextInt(candidates.length)];
  }

  PrintPage buildPage(PageTemplate tpl, String format, double pageAspect, List<BookPhoto> photos) {
    final slots = tpl.photoSlots(format);
    final assignment = assignToSlots(slots, pageAspect, photos);
    return PrintPage(
      id: _uuid.v4(),
      tag: tpl.tag,
      templateId: tpl.id,
      photos: assignment.map((p) => p == null ? null : PhotoSlot(photoId: p.id)).toList(),
      texts: tpl.textSlots(format).map((_) => '').toList(),
    );
  }

  /// Fotoğrafları alanlara en-boy oranı farkı (log ölçeğinde) toplamı en küçük olacak şekilde dağıtır.
  /// Fotoğraf sırası korunmaz; alan sayısından fazla fotoğraf yerleştirilmez.
  static List<BookPhoto?> assignToSlots(List<TemplateElement> slots, double pageAspect, List<BookPhoto> photos) {
    final n = slots.length;
    final result = List<BookPhoto?>.filled(n, null);
    final list = photos.take(n).toList();
    if (list.isEmpty) return result;
    final slotAspects = slots.map((s) => s.frame.width * pageAspect / s.frame.height).toList();
    double cost(BookPhoto p, int slot) => (log(p.aspect) - log(slotAspects[slot])).abs();
    // Fotoğraf alandan azsa önce en büyük alanlar doldurulur (ör. üst üste şablonda arkadaki büyük alan).
    final usable = List<int>.generate(n, (i) => i)
      ..sort((a, b) => (slots[b].frame.width * slots[b].frame.height)
          .compareTo(slots[a].frame.width * slots[a].frame.height));
    final candidates = list.length < n ? (usable.take(list.length).toList()..sort()) : List<int>.generate(n, (i) => i);

    if (candidates.length <= 6) {
      var best = double.infinity;
      List<int>? bestPerm;
      for (final perm in _permutations(candidates)) {
        var c = 0.0;
        for (var i = 0; i < list.length; i++) {
          c += cost(list[i], perm[i]);
        }
        if (c < best) {
          best = c;
          bestPerm = perm;
        }
      }
      for (var i = 0; i < list.length; i++) {
        result[bestPerm![i]] = list[i];
      }
    } else {
      // Büyük şablonlarda açgözlü eşleştirme.
      final free = [...candidates];
      for (final p in list) {
        free.sort((a, b) => cost(p, a).compareTo(cost(p, b)));
        result[free.removeAt(0)] = p;
      }
    }
    return result;
  }

  static Iterable<List<int>> _permutations(List<int> items) sync* {
    if (items.length <= 1) {
      yield items;
      return;
    }
    for (var i = 0; i < items.length; i++) {
      final rest = [...items]..removeAt(i);
      for (final p in _permutations(rest)) {
        yield [items[i], ...p];
      }
    }
  }

  static const _monthsShort = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];

  /// "Eyl 2024 – Eki 2026" biçiminde tarih aralığı (Popsa kapak alt başlığı).
  static String dateRangeLabel(List<BookPhoto> photos) {
    final dates = photos.map((p) => p.takenAt).whereType<DateTime>().toList()..sort();
    if (dates.isEmpty) return '';
    final a = dates.first, b = dates.last;
    final sa = '${_monthsShort[a.month - 1]} ${a.year}';
    final sb = '${_monthsShort[b.month - 1]} ${b.year}';
    return sa == sb ? sa : '$sa – $sb';
  }

  /// Fotoğrafların tarih aralığına göre başlık önerileri.
  static List<String> titleSuggestions(List<BookPhoto> photos, {DateTime? now}) {
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    String season(int m) => switch (m) {
          12 || 1 || 2 => 'Kış',
          3 || 4 || 5 => 'İlkbahar',
          6 || 7 || 8 => 'Yaz',
          _ => 'Sonbahar',
        };
    final dates = photos.map((p) => p.takenAt).whereType<DateTime>().toList()..sort();
    final out = <String>[];
    if (dates.isNotEmpty) {
      final a = dates.first, b = dates.last;
      if (a.year == b.year && a.month == b.month) {
        out.add('${months[a.month - 1]} ${a.year}');
      } else if (a.year == b.year && season(a.month) == season(b.month)) {
        out.add('${season(a.month)} ${a.year}');
      }
      if (a.year == b.year) {
        out.add('${a.year} Anıları');
      } else {
        out.add('${a.year} – ${b.year}');
      }
    }
    out.addAll(['Anılarımız', 'En Güzel Anlar', 'Birlikte', 'Unutulmaz Günler']);
    return out.toSet().toList();
  }
}
