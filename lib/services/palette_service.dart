import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/catalog.dart';
import '../repositories/photo_repository.dart';

/// Fotoğraflardaki baskın renkten beş tonlu "dinamik" tema paleti üretir:
/// açık, yumuşak, canlı, zengin, koyu (Popsa'nın dynamic light/muted/vibrant/rich/dark temaları).
class PaletteService {
  static const sampleSize = 40;
  static const maxPhotos = 12;

  static Future<List<String>> forPhotos(List<String> photoIds) async {
    final pixels = <int>[];
    for (final id in photoIds.take(maxPhotos)) {
      try {
        final e = await PhotoRepository.entity(id);
        final bytes = await e?.thumbnailDataWithSize(const ThumbnailSize.square(sampleSize));
        if (bytes == null) continue;
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: sampleSize, targetHeight: sampleSize);
        final frame = await codec.getNextFrame();
        final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data == null) continue;
        final list = data.buffer.asUint8List();
        for (var i = 0; i + 3 < list.length; i += 4) {
          pixels
            ..add(list[i])
            ..add(list[i + 1])
            ..add(list[i + 2]);
        }
      } catch (_) {
        // okunamayan fotoğrafı atla
      }
    }
    return fromRgb(pixels);
  }

  /// Palet sırası (kimlikler `dyn:N` olarak saklandığı için ilk beşin anlamı değişmez):
  /// 0 açık, 1 yumuşak, 2 canlı, 3 zengin, 4 koyu, 5 pastel, 6 toprak (sessiz orta ton), 7 derin,
  /// 8 ikinci renk açık, 9 ikinci renk canlı.
  static const size = 10;

  /// Panelde açıktan koyuya doğru gösterim sırası.
  static const displayOrder = [0, 5, 8, 1, 6, 2, 9, 3, 7, 4];

  /// [rgb]: art arda r,g,b değerleri. Ton (hue) histogramında doygunlukla ağırlıklandırılmış en baskın tonu ve
  /// ondan en az 60° uzaktaki ikinci tonu bulur.
  static List<String> fromRgb(List<int> rgb) {
    const buckets = 24;
    final weight = List<double>.filled(buckets, 0);
    final satSum = List<double>.filled(buckets, 0);
    for (var i = 0; i + 2 < rgb.length; i += 3) {
      final hsl = HSLColor.fromColor(Color.fromARGB(255, rgb[i], rgb[i + 1], rgb[i + 2]));
      if (hsl.lightness < 0.12 || hsl.lightness > 0.92 || hsl.saturation < 0.15) continue;
      final b = (hsl.hue / 360 * buckets).floor() % buckets;
      final w = hsl.saturation * (1 - (hsl.lightness - 0.5).abs());
      weight[b] += w;
      satSum[b] += hsl.saturation;
    }
    var best = 0;
    for (var b = 1; b < buckets; b++) {
      if (weight[b] > weight[best]) best = b;
    }
    int dist(int a, int b) => min((a - b).abs(), buckets - (a - b).abs());
    int? second;
    for (var b = 0; b < buckets; b++) {
      if (dist(b, best) < 4 || weight[b] <= 0) continue;
      if (second == null || weight[b] > weight[second]) second = b;
    }
    final hasColor = weight[best] > 0;
    final hue = hasColor ? (best + 0.5) * 360 / buckets : 30.0;
    final sat = hasColor ? min(0.85, max(0.35, satSum[best] / max(1, weight[best]) * 0.6)) : 0.2;
    // İkinci baskın renk yoksa ana tonun 150° ötesindeki uyumlu ton kullanılır.
    final hue2 = second != null ? (second + 0.5) * 360 / buckets : (hue + 150) % 360;
    final sat2 = second != null ? min(0.75, max(0.3, satSum[second] / max(1, weight[second]) * 0.6)) : sat * 0.7;

    String h(double hu, double s, double l) => colorHex(HSLColor.fromAHSL(1, hu, s.clamp(0, 1), l).toColor());
    return [
      h(hue, sat * 0.45, 0.93), // 0 açık
      h(hue, sat * 0.25, 0.78), // 1 yumuşak
      h(hue, sat, 0.50), // 2 canlı
      h(hue, sat * 0.9, 0.30), // 3 zengin
      h(hue, sat * 0.3, 0.13), // 4 koyu
      h(hue, sat * 0.7, 0.87), // 5 pastel
      h(hue, sat * 0.35, 0.55), // 6 toprak
      h(hue, sat * 0.75, 0.21), // 7 derin
      h(hue2, sat2 * 0.55, 0.88), // 8 ikinci renk açık
      h(hue2, sat2, 0.48), // 9 ikinci renk canlı
    ];
  }
}
