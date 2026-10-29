import 'package:anilarin/services/smart_album_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<SmartPhoto> event(DateTime start, int n, {bool screenshot = false, String prefix = ''}) => [
        for (var i = 0; i < n; i++)
          SmartPhoto(
            id: '$prefix${start.toIso8601String()}-$i',
            takenAt: start.add(Duration(minutes: 30 * i)),
            screenshot: screenshot,
          ),
      ];

  test('zamana göre etkinliklere ayırır, küçük etkinlikleri ve ekran görüntülerini atar', () {
    final albums = SmartAlbumService.build([
      ...event(DateTime(2026, 10, 29, 10), 20), // tek gün
      ...event(DateTime(2026, 10, 3, 9), 100), // 3–5 Ekim (30 dk arayla ~50 saat)
      ...event(DateTime(2026, 9, 10), 5), // az
      ...event(DateTime(2026, 8, 1), 40, screenshot: true, prefix: 's'),
    ]);
    expect(albums.map((a) => a.dateLabel), ['29 Ekim 2026', '3 – 5 Ekim 2026']);
    expect(albums.first.count, 20);
    expect(albums.first.title, 'Sonbahar Renkleri');
  });

  test('tarih aralığı etiketleri', () {
    expect(SmartAlbumService.rangeLabel(DateTime(2026, 9, 28), DateTime(2026, 10, 2)), '28 Eylül – 2 Ekim 2026');
    expect(
      SmartAlbumService.rangeLabel(DateTime(2025, 12, 30), DateTime(2026, 1, 2)),
      '30 Aralık 2025 – 2 Ocak 2026',
    );
  });

  test('ekran görüntüsü yolu tanınır', () {
    expect(SmartAlbumService.isScreenshotPath('Pictures/Screenshots/'), isTrue);
    expect(SmartAlbumService.isScreenshotPath('DCIM/Camera/'), isFalse);
    expect(SmartAlbumService.isScreenshotPath(null), isFalse);
  });
}
