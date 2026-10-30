import 'package:flutter/material.dart';

import '../../models/catalog.dart';
import '../../models/print_set.dart';
import 'photo_image.dart';
import 'print_page_view.dart' show photoRect;

/// Setteki bir baskının görünümü (Popsa baskı editörü). Baskı bir kâğıttır; kâğıt rengi baskının rengidir.
/// Kenarlıda fotoğrafın dört yanında eşit ince kenar kalır, yazı varsa altta şerit açılır; kenarsızda fotoğraf
/// baskıyı kaplar. Kapak baskısı (indeks 0) setin [CoverLayout] düzenine göre çizilir.
class PrintCard extends StatelessWidget {
  const PrintCard({
    super.key,
    required this.set,
    required this.index,
    required this.fonts,
    this.thumbSize = 700,
    this.layout,
  });

  final PrintSet set;
  final int index;
  final List<TextAppearance> fonts;
  final int thumbSize;

  /// Şablon seçicide önizleme için setin düzeninin yerine geçer.
  final CoverLayout? layout;

  static const _duration = Duration(milliseconds: 280);

  PrintItem get item => set.items[index];

  bool get _cover => index == 0;

  static double aspectOf(PrintSet set, PrintItem item) =>
      set.product.square ? 1.0 : (item.portrait ? 1 / set.product.aspect : set.product.aspect);

  static ({Rect photo, Rect? text, TextAlign align, bool overlay, bool band}) _g(
    Rect photo,
    Rect? text,
    TextAlign align, {
    bool overlay = false,
    bool band = false,
  }) => (photo: photo, text: text, align: align, overlay: overlay, band: band);

  /// Kâğıt üzerindeki fotoğraf ve yazı alanları (0..1 oranları). [overlay]: yazı fotoğrafın üstünde (koyu geçişli),
  /// [band]: yazı fotoğrafın üstünde kâğıt renginde yarı saydam şeritte.
  static ({Rect photo, Rect? text, TextAlign align, bool overlay, bool band}) geometry(
    PrintSet set,
    int index, {
    CoverLayout? layout,
  }) {
    final item = set.items[index];
    final aspect = aspectOf(set, item);
    const ex = 0.04; // kenar kalınlığı (genişliğin oranı)
    final ey = ex * aspect; // aynı kalınlık, yüksekliğin oranı olarak
    if (index != 0) {
      final e = item.border;
      final band = item.caption.isEmpty ? 0.0 : 0.1 * aspect;
      return _g(
        e ? Rect.fromLTRB(ex, ey, 1 - ex, 1 - ey - band) : Rect.fromLTRB(0, 0, 1, 1 - band),
        band == 0 ? null : Rect.fromLTRB(ex, 1 - band - (e ? ey : 0), 1 - ex, 1 - (e ? ey * 0.4 : 0)),
        item.align,
      );
    }
    final textH = (set.subtitle.isNotEmpty ? 0.14 : 0.1) * aspect;
    final framedText = Rect.fromLTRB(ex, 1 - ey - textH, 1 - ex, 1 - ey * 0.4);
    final framedPhoto = Rect.fromLTRB(ex, ey, 1 - ex, 1 - ey - textH);
    const full = Rect.fromLTRB(0, 0, 1, 1);
    return switch (layout ?? set.layout) {
      CoverLayout.framed => _g(framedPhoto, framedText, set.titleAlign),
      CoverLayout.framedLeft => _g(framedPhoto, framedText, TextAlign.left),
      CoverLayout.gradient => _g(
        full,
        Rect.fromLTRB(ex, 1 - textH - ey, 1 - ex, 1 - ey * 0.5),
        set.titleAlign,
        overlay: true,
      ),
      CoverLayout.band => _g(full, Rect.fromLTRB(0, 1 - textH - ey, 1, 1), set.titleAlign, band: true),
      CoverLayout.photoOnly => _g(full, null, set.titleAlign),
      CoverLayout.overlayLeft => _g(
        full,
        Rect.fromLTRB(ex * 2, 1 - textH - ey * 2, 1 - ex * 2, 1 - ey),
        TextAlign.left,
        overlay: true,
      ),
      CoverLayout.textAbove => _g(
        Rect.fromLTRB(ex, ey + textH, 1 - ex, 1 - ey),
        Rect.fromLTRB(ex, ey * 0.4, 1 - ex, ey + textH),
        TextAlign.left,
      ),
      CoverLayout.textLeft => _g(
        const Rect.fromLTRB(0.45, 0.2, 1, 0.75),
        const Rect.fromLTRB(ex * 2, 0.2, 0.42, 0.75),
        TextAlign.left,
      ),
      CoverLayout.corner => _g(
        Rect.fromLTRB(0.4, 0.38, 1 - ex * 2, 1 - ey * 2),
        Rect.fromLTRB(ex * 2, ey * 2, 1 - ex * 2, 0.34),
        TextAlign.left,
      ),
    };
  }

  /// Düzenleme ekranı için fotoğraf alanının en/boy oranı.
  static double photoAreaAspect(PrintSet set, int index) {
    final g = geometry(set, index);
    return aspectOf(set, set.items[index]) * g.photo.width / g.photo.height;
  }

  TextAppearance _font(String? id) => fonts.firstWhere((f) => f.id == (id ?? set.fontId), orElse: () => fonts.first);

  @override
  Widget build(BuildContext context) {
    final paper = hexColor(set.colorOf(item));
    final g = geometry(set, index, layout: layout);
    final onPaper = paper.computeLuminance() < 0.5 ? Colors.white : const Color(0xFF222222);
    final fg = g.overlay ? Colors.white : onPaper;
    final heading = _cover ? set.title : item.caption;
    final sub = _cover ? set.subtitle : '';
    final font = _font(_cover ? set.titleFontId : item.fontId);
    final multiLine = _cover && (layout ?? set.layout) == CoverLayout.textLeft;
    return AspectRatio(
      aspectRatio: aspectOf(set, item),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          Rect scaled(Rect r) => Rect.fromLTRB(r.left * w, r.top * h, r.right * w, r.bottom * h);
          final text = g.text == null ? null : scaled(g.text!);
          final cross = switch (g.align) {
            TextAlign.left => CrossAxisAlignment.start,
            TextAlign.right => CrossAxisAlignment.end,
            _ => CrossAxisAlignment.center,
          };
          final shadow = g.overlay ? const [Shadow(color: Colors.black54, blurRadius: 6)] : null;
          String up(String s) => font.uppercase ? s.toUpperCase() : s;
          return TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: paper),
            duration: _duration,
            builder: (context, color, child) => DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(w * 0.008),
                boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: child,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(w * 0.008),
              child: Stack(
                children: [
                  AnimatedPositioned.fromRect(
                    duration: _duration,
                    curve: Curves.easeInOutCubic,
                    rect: scaled(g.photo),
                    child: ClipRect(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final r = photoRect(Size(box.maxWidth, box.maxHeight), item.photo.aspect, item.slot);
                          return Stack(
                            children: [
                              Positioned.fromRect(
                                rect: r,
                                child: RotatedBox(
                                  quarterTurns: item.turns,
                                  child: PhotoImage(photoId: item.photo.id, size: thumbSize),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  if (g.overlay)
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.5, 1],
                            colors: [Color(0x00000000), Color(0x99000000)],
                          ),
                        ),
                      ),
                    ),
                  if (g.band && text != null)
                    Positioned.fromRect(
                      rect: text,
                      child: ColoredBox(color: paper.withValues(alpha: 0.82)),
                    ),
                  if (text != null && heading.isNotEmpty)
                    Positioned.fromRect(
                      rect: text.deflate(w * 0.01),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: cross,
                        children: [
                          Text(
                            up(heading),
                            maxLines: multiLine ? 3 : 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: g.align,
                            style: TextStyle(
                              color: fg,
                              fontFamily: font.titleFont,
                              fontWeight: _cover ? font.titleWeight : FontWeight.w500,
                              letterSpacing: font.letterSpacing,
                              fontSize: w * (_cover ? 0.05 : 0.042),
                              shadows: shadow,
                            ),
                          ),
                          if (sub.isNotEmpty)
                            Text(
                              up(sub),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: g.align,
                              style: TextStyle(
                                color: fg.withValues(alpha: 0.85),
                                fontFamily: font.bodyFont,
                                fontSize: w * 0.028,
                                shadows: shadow,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
