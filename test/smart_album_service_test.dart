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

  test('yalnız kamera klasörü kabul edilir, tekrar eden başlıklar değişir', () {
    expect(SmartAlbumService.isCameraPath('DCIM/Camera/'), isTrue);
    expect(SmartAlbumService.isCameraPath('Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/'), isFalse);
    expect(SmartAlbumService.isCameraPath('Download/'), isFalse);
    expect(SmartAlbumService.isCameraPath(null), isTrue);
    final albums = SmartAlbumService.build([
      ...event(DateTime(2026, 10, 20), 15),
      ...event(DateTime(2026, 10, 5), 15),
    ]);
    expect(albums[0].title, isNot(albums[1].title));
  });

  test('kapak ortaya en yakın kamera fotoğrafı, en fazla 6 öneri', () {
    final e = [
      for (var i = 0; i < 12; i++)
        SmartPhoto(id: 'p$i', takenAt: DateTime(2026, 10, 1, 12, i), camera: i == 2 || i == 9),
    ];
    final album = SmartAlbumService.build(e).single;
    expect(album.coverId, anyOf('p2', 'p9'));
    final many = [for (var d = 0; d < 10; d++) ...event(DateTime(2026, 1, 1 + d * 2), 15)];
    expect(SmartAlbumService.build(many).length, 6);
  });

  test('ekran görüntüsü yolu tanınır', () {
    expect(SmartAlbumService.isScreenshotPath('Pictures/Screenshots/'), isTrue);
    expect(SmartAlbumService.isScreenshotPath('DCIM/Camera/'), isFalse);
    expect(SmartAlbumService.isScreenshotPath(null), isFalse);
  });
}
