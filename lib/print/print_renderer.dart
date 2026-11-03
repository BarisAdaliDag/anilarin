import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/catalog.dart';
import '../models/photo_book.dart';
import '../models/print_set.dart';
import '../views/widgets/print_card.dart';
import '../views/widgets/print_page_view.dart';
import 'photo_source.dart';
import 'print_spec.dart';

/// Fotoğrafı en fazla [maxPx] uzun kenarla çözülmüş görüntü olarak verir (galeriden ya da dosyadan).
typedef PrintPhotoLoader = Future<ui.Image> Function(BookPhoto photo, int maxPx);

/// Baskıda yerleştiği ölçüye göre çözünürlüğü düşük kalan fotoğraf.
class LowResPhoto {
  final String place; // "Kapak", "Sayfa 4", "Baskı 12"
  final String photoId;
  final int dpi;

  const LowResPhoto(this.place, this.photoId, this.dpi);
}

/// Tasarımları uygulamadaki sayfa widget'larıyla (PrintPageView / PrintCard) 300 DPI çizer ve PDF'e
/// yazar; yalnız kitap kapağına taşma payı eklenir. Ekranda görülen sayfa ile basılan sayfa aynı koddan çıkar.
class PrintRenderer {
  PrintRenderer({required this.context, required this.catalog, required this.loadPhoto});

  /// Sayfaların çizileceği ekranın bağlamı (Overlay için).
  final BuildContext context;
  final Catalog catalog;
  final PrintPhotoLoader loadPhoto;

  /// Sayfalar bu mantıksal genişlikte yerleştirilir, sonra piksel oranıyla büyütülür.
  static const _layoutWidth = 1000.0;

  /// Bu çözünürlüğün altında kalan fotoğraflar [lowRes] listesine girer.
  static const lowResDpi = 150;

  /// Fotoğraflar en çok bu uzun kenarla çözülür (yakınlaştırılmış kırpımda ayrıntı kaybolmasın diye
  /// sayfanın iki katına kadar; orijinal daha küçükse büyütülmez).
  static const _maxPhotoPx = 5000;

  /// Son çizimlerde düşük çözünürlüklü kalan fotoğraflar; her ürünün başında temizlenir.
  final lowRes = <LowResPhoto>[];

  /// Kitap: `kapak.pdf` (ön kapak, taşma paylı) ve `ic-sayfalar.pdf` (net ölçü). [onPage]: (çizilen, toplam).
  Future<List<File>> renderBook(PhotoBook book, Directory out, {void Function(int, int)? onPage}) async {
    lowRes.clear();
    final product = catalog.product(book.productCode);
    final coverSpec = PrintSpec.book(product, cover: true), innerSpec = PrintSpec.book(product);
    final cover = pw.Document(title: '${book.title} – kapak');
    final inner = pw.Document(title: '${book.title} – iç sayfalar');
    var innerNo = 0;
    for (var i = 0; i < book.pages.length; i++) {
      final page = book.pages[i];
      final spec = page.isCover ? coverSpec : innerSpec;
      final jpeg = await _renderPage(
        spec,
        {for (final id in page.photoIds) id: book.photos[id]},
        PrintPageView(book: book, pageIndex: i, catalog: catalog, thumbSize: spec.fullWidthPx),
        page.isCover ? 'Kapak' : 'Sayfa ${++innerNo}',
      );
      _addPage(page.isCover ? cover : inner, spec, jpeg);
      onPage?.call(i + 1, book.pages.length);
    }
    return [await _save(cover, File('${out.path}/kapak.pdf')), await _save(inner, File('${out.path}/ic-sayfalar.pdf'))];
  }

  /// Baskı seti: her baskı bir sayfa, kendi yönünde, net ölçü (`baskilar.pdf`). Ayrıca baskı makinesine
  /// atılacak JPEG'ler `jpeg/<ölçü>/001_x<adet>.jpg` olarak yazılır; [copies] siparişteki set adedidir.
  Future<List<File>> renderPrintSet(
    PrintSet set,
    Directory out, {
    int copies = 1,
    void Function(int, int)? onPage,
  }) async {
    lowRes.clear();
    final doc = pw.Document(title: set.title);
    final jpegDir = Directory('${out.path}/jpeg/${PrintSpec.sizeTag(set.product)}');
    await jpegDir.create(recursive: true);
    for (var i = 0; i < set.items.length; i++) {
      final item = set.items[i];
      final spec = PrintSpec.print(set.product, portrait: set.product.square ? false : item.portrait);
      final jpeg = await _renderPage(
        spec,
        {item.photo.id: item.photo},
        PrintCard(set: set, index: i, fonts: catalog.textAppearances, thumbSize: spec.fullWidthPx),
        'Baskı ${i + 1}',
      );
      _addPage(doc, spec, jpeg);
      await File('${jpegDir.path}/${'${i + 1}'.padLeft(3, '0')}_x$copies.jpg').writeAsBytes(jpeg);
      onPage?.call(i + 1, set.items.length);
    }
    return [await _save(doc, File('${out.path}/baskilar.pdf'))];
  }

  Future<Uint8List> _renderPage(PrintSpec spec, Map<String, BookPhoto?> photos, Widget page, String place) async {
    final maxPx = math.min<int>(_maxPhotoPx, 2 * math.max(spec.fullWidthPx, spec.fullHeightPx));
    final images = <String, ui.Image>{
      for (final e in photos.entries)
        if (e.value != null) e.key: await loadPhoto(e.value!, maxPx),
    };
    try {
      final logical = Size(_layoutWidth, _layoutWidth * spec.heightMm / spec.widthMm);
      final pixelRatio = spec.trimWidthPx / logical.width;
      final dpi = <String, double>{};
      final trim = await _capture(
        PhotoSourceScope(
          images: images,
          pixelRatio: pixelRatio,
          onDpi: (id, d) => dpi[id] = math.min(dpi[id] ?? double.infinity, d),
          child: page,
        ),
        logical,
        pixelRatio,
      );
      for (final e in dpi.entries) {
        if (e.value < lowResDpi) lowRes.add(LowResPhoto(place, e.key, e.value.round()));
      }
      final full = spec.bleedPx == 0 ? trim : await _addBleed(trim, spec);
      if (!identical(full, trim)) trim.dispose();
      final rgba = (await full.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final (w, h) = (full.width, full.height);
      full.dispose();
      return Isolate.run(() => _encodeJpeg(rgba, w, h));
    } finally {
      for (final i in images.values) {
        i.dispose();
      }
    }
  }

  /// Widget'ı ekran dışında (Overlay'de görünmeyen konumda) çizip görüntüsünü alır.
  Future<ui.Image> _capture(Widget child, Size size, double pixelRatio) async {
    final key = GlobalKey();
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: -size.width - 1000,
        top: 0,
        width: size.width,
        height: size.height,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: RepaintBoundary(
            key: key,
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    try {
      // İlk karede yerleşim, ikincide fotoğraflı boya hazır olur.
      for (var i = 0; i < 3; i++) {
        WidgetsBinding.instance.scheduleFrame();
        await WidgetsBinding.instance.endOfFrame;
      }
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return await boundary.toImage(pixelRatio: pixelRatio);
    } finally {
      entry.remove();
    }
  }

  /// Kesim ölçüsündeki sayfayı ortaya koyar, kenar piksellerini taşma payı kadar dışa uzatır.
  static Future<ui.Image> _addBleed(ui.Image trim, PrintSpec spec) {
    final b = spec.bleedPx.toDouble();
    final w = trim.width.toDouble(), h = trim.height.toDouble();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final paint = Paint()..filterQuality = FilterQuality.none;
    void strip(Rect src, Rect dst) => c.drawImageRect(trim, src, dst, paint);
    c.drawImage(trim, Offset(b, b), paint);
    strip(Rect.fromLTWH(0, 0, 1, h), Rect.fromLTWH(0, b, b, h)); // sol
    strip(Rect.fromLTWH(w - 1, 0, 1, h), Rect.fromLTWH(b + w, b, b, h)); // sağ
    strip(Rect.fromLTWH(0, 0, w, 1), Rect.fromLTWH(b, 0, w, b)); // üst
    strip(Rect.fromLTWH(0, h - 1, w, 1), Rect.fromLTWH(b, b + h, w, b)); // alt
    strip(const Rect.fromLTWH(0, 0, 1, 1), Rect.fromLTWH(0, 0, b, b));
    strip(Rect.fromLTWH(w - 1, 0, 1, 1), Rect.fromLTWH(b + w, 0, b, b));
    strip(Rect.fromLTWH(0, h - 1, 1, 1), Rect.fromLTWH(0, b + h, b, b));
    strip(Rect.fromLTWH(w - 1, h - 1, 1, 1), Rect.fromLTWH(b + w, b + h, b, b));
    return rec.endRecording().toImage(spec.fullWidthPx, spec.fullHeightPx);
  }

  static Uint8List _encodeJpeg(ByteData rgba, int w, int h) {
    final image = img.Image.fromBytes(
      width: w,
      height: h,
      bytes: rgba.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    return img.encodeJpg(image, quality: 95);
  }

  static void _addPage(pw.Document doc, PrintSpec spec, Uint8List jpeg) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(spec.fullWidthPt, spec.fullHeightPt),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(pw.MemoryImage(jpeg), fit: pw.BoxFit.fill),
      ),
    );
  }

  static Future<File> _save(pw.Document doc, File file) async {
    await file.parent.create(recursive: true);
    return file.writeAsBytes(await doc.save());
  }
}

/// Çözülmüş fotoğrafı uzun kenarı en fazla [maxPx] olacak biçimde verir.
Future<ui.Image> decodePhoto(Uint8List bytes, int maxPx) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final long = math.max(descriptor.width, descriptor.height);
  final k = long > maxPx ? maxPx / long : 1.0;
  final codec = await descriptor.instantiateCodec(
    targetWidth: (descriptor.width * k).round(),
    targetHeight: (descriptor.height * k).round(),
  );
  final frame = await codec.getNextFrame();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  return frame.image;
}
