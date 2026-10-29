/// Akıllı albüm için fotoğrafın gereken bilgileri (galeriden bağımsız, test edilebilir).
class SmartPhoto {
  final String id;
  final DateTime takenAt;
  final bool screenshot;
  final bool camera; // kamera klasöründen (kapak için tercih edilir)

  const SmartPhoto({required this.id, required this.takenAt, this.screenshot = false, this.camera = true});
}

/// "Popsa Önerileri / Akıllı Albümler" karşılığı: aynı etkinlikte (birbirine yakın zamanda) çekilmiş fotoğraflar.
class SmartAlbum {
  final String title;
  final String dateLabel;
  final List<String> photoIds; // yeniden eskiye
  final String coverId;
  final DateTime month;

  const SmartAlbum({
    required this.title,
    required this.dateLabel,
    required this.photoIds,
    required this.coverId,
    required this.month,
  });

  int get count => photoIds.length;
}

class SmartAlbumService {
  static const minPhotos = 12;
  static const maxAlbums = 6; // Popsa seçicide en fazla 6 öneri gösterir (uce.java: take 6)

  static const _months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  /// Fotoğraflar arasında bu kadardan uzun boşluk varsa yeni bir etkinlik başlar.
  static const eventGap = Duration(hours: 8);

  /// Ekran görüntülerini atar, fotoğrafları zamana göre etkinliklere ayırır (aralarında [eventGap]'ten uzun
  /// boşluk yoksa aynı etkinlik); en az [minPhotos] fotoğraflı etkinlikleri yeniden eskiye döndürür.
  static List<SmartAlbum> build(List<SmartPhoto> photos) {
    final sorted = photos.where((p) => !p.screenshot).toList()..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    final events = <List<SmartPhoto>>[];
    for (final p in sorted) {
      if (events.isEmpty || events.last.last.takenAt.difference(p.takenAt) > eventGap) {
        events.add([p]);
      } else {
        events.last.add(p);
      }
    }
    final used = <String, int>{};
    String uniqueTitle(DateTime d) {
      final base = titleFor(d);
      final n = used[base] = (used[base] ?? 0) + 1;
      return n == 1 ? base : _alternates[(n - 2) % _alternates.length];
    }

    return [
      for (final e in events.where((e) => e.length >= minPhotos).take(maxAlbums))
        SmartAlbum(
          title: uniqueTitle(e.first.takenAt),
          dateLabel: rangeLabel(e.last.takenAt, e.first.takenAt),
          month: DateTime(e.first.takenAt.year, e.first.takenAt.month),
          photoIds: e.map((p) => p.id).toList(),
          coverId: coverFor(e),
        ),
    ];
  }

  /// Kapak: etkinliğin ortasına en yakın kamera fotoğrafı (Popsa sunucusu yüz içeren gerçek bir fotoğraf
  /// seçiyor; yüz tanıma olmadığı için kamera fotoğrafı, metinli WhatsApp görsellerinden iyi bir yaklaşım).
  static String coverFor(List<SmartPhoto> e) {
    final mid = e.length ~/ 2;
    final order = List<int>.generate(e.length, (i) => i)..sort((a, b) => (a - mid).abs().compareTo((b - mid).abs()));
    for (final i in order) {
      if (e[i].camera) return e[i].id;
    }
    return e[mid].id;
  }

  /// "29 Ekim 2026", "3 – 5 Ekim 2026", "28 Eylül – 2 Ekim 2026", "30 Aralık 2025 – 2 Ocak 2026".
  static String rangeLabel(DateTime a, DateTime b) {
    final m = _months;
    if (a.year == b.year && a.month == b.month && a.day == b.day) return '${a.day} ${m[a.month - 1]} ${a.year}';
    if (a.year == b.year && a.month == b.month) return '${a.day} – ${b.day} ${m[a.month - 1]} ${a.year}';
    if (a.year == b.year) return '${a.day} ${m[a.month - 1]} – ${b.day} ${m[b.month - 1]} ${b.year}';
    return '${a.day} ${m[a.month - 1]} ${a.year} – ${b.day} ${m[b.month - 1]} ${b.year}';
  }

  /// Mevsime göre kısa bir başlık (Popsa'daki "Let's Celebrate!" gibi).
  static String titleFor(DateTime m) => switch (m.month) {
    12 => 'Yılın Son Ayı',
    1 || 2 => 'Kış Günleri',
    3 || 4 || 5 => 'Bahar Esintisi',
    6 || 7 || 8 => 'Yaz Anıları',
    _ => 'Sonbahar Renkleri',
  };

  static const _alternates = ['Güzel Bir Gün', 'Birlikte', 'Unutulmaz Anlar', 'Küçük Kaçamak', 'Anılar Defteri'];

  /// Android'de ekran görüntüleri klasör yolundan anlaşılır.
  static bool isScreenshotPath(String? relativePath) =>
      relativePath != null && relativePath.toLowerCase().contains('screenshot');

  /// Fotoğraf kamera klasöründen mi (DCIM)? Yalnız kapak seçiminde kullanılır; WhatsApp ağırlıklı
  /// galerilerde gruplamadan çıkarmak öneri sayısını çok düşürüyor.
  /// Yol bilinmiyorsa (iOS) fotoğraf kabul edilir.
  static bool isCameraPath(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return true;
    final p = relativePath.toLowerCase();
    return p.contains('dcim') && !p.contains('screenshot');
  }
}
