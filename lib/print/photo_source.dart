import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Baskı çiziminde fotoğrafları galeriden değil, önceden yüklenmiş tam çözünürlüklü görüntülerden verir.
/// Altındaki [PhotoImage]'lar bu kapsamda galeriyi hiç kullanmaz; böylece aynı sayfa widget'ı hem
/// telefonda hem matbaa uygulamasında (indirilen dosyalarla) çizilir.
class PhotoSourceScope extends InheritedWidget {
  const PhotoSourceScope({super.key, required this.images, this.pixelRatio = 1, this.onDpi, required super.child});

  /// Fotoğraf kimliği → çözülmüş görüntü.
  final Map<String, ui.Image> images;

  /// Sayfanın mantıksal biriminin baskıdaki piksel karşılığı (300 DPI).
  final double pixelRatio;

  /// Her fotoğrafın baskıdaki efektif çözünürlüğü (DPI) raporlanır.
  final void Function(String photoId, double dpi)? onDpi;

  /// [image], baskıda mantıksal [size] kadar yer kaplarsa kaç DPI'a denk gelir.
  double dpiOf(ui.Image image, Size size) {
    final w = size.width * pixelRatio, h = size.height * pixelRatio;
    if (w <= 0 || h <= 0) return double.infinity;
    return 300 * math.min(image.width / w, image.height / h);
  }

  static PhotoSourceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PhotoSourceScope>();

  @override
  bool updateShouldNotify(PhotoSourceScope oldWidget) => images != oldWidget.images;
}
