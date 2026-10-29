/// Akıllı albüm için fotoğrafın gereken bilgileri (galeriden bağımsız, test edilebilir).
class SmartPhoto {
  final String id;
  final DateTime takenAt;
  final bool screenshot;

  const SmartPhoto({required this.id, required this.takenAt, this.screenshot = false});
}

/// "Popsa Önerileri / Akıllı Albümler" karşılığı: aynı etkinlikte (birbirine yakın zamanda) çekilmiş fotoğraflar.
class SmartAlbum {
  final String title;
  final String dateLabel;
  final List<String> photoIds; // yeniden eskiye
  final DateTime month;

  const SmartAlbum({required this.title, required this.dateLabel, required this.photoIds, required this.month});

  int get count => photoIds.length;
}

class SmartAlbumService {
  static const minPhotos = 12;
  static const maxAlbums = 12;

  static const _months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  /// Fotoğraflar arasında bu kadardan uzun boşluk varsa yeni bir etkinlik başlar.
  static const eventGap = Duration(hours: 36);

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
    return [
      for (final e in events.where((e) => e.length >= minPhotos).take(maxAlbums))
        SmartAlbum(
          title: titleFor(e.first.takenAt),
          dateLabel: rangeLabel(e.last.takenAt, e.first.takenAt),
          month: DateTime(e.first.takenAt.year, e.first.takenAt.month),
          photoIds: e.map((p) => p.id).toList(),
        ),
    ];
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

  /// Android'de ekran görüntüleri klasör yolundan anlaşılır.
  static bool isScreenshotPath(String? relativePath) =>
      relativePath != null && relativePath.toLowerCase().contains('screenshot');
}
