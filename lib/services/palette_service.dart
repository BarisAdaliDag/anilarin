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

  /// [rgb]: art arda r,g,b değerleri. Ton (hue) histogramında doygunlukla ağırlıklandırılmış en baskın tonu bulur.
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
    final hasColor = weight[best] > 0;
    final hue = hasColor ? (best + 0.5) * 360 / buckets : 30.0;
    final sat = hasColor ? min(0.85, max(0.35, satSum[best] / max(1, weight[best]) * 0.6)) : 0.2;

    String h(double s, double l) => colorHex(HSLColor.fromAHSL(1, hue, s.clamp(0, 1), l).toColor());
    return [
      h(sat * 0.45, 0.93), // açık
      h(sat * 0.25, 0.78), // yumuşak
      h(sat, 0.50), // canlı
      h(sat * 0.9, 0.30), // zengin
      h(sat * 0.3, 0.13), // koyu
    ];
  }
}
