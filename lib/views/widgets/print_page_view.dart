import 'package:flutter/material.dart';

import '../../models/catalog.dart';
import '../../models/photo_book.dart';
import 'photo_image.dart';

typedef SlotWrapper = Widget Function(BuildContext context, int slotIndex, Widget child);
typedef TextTap = void Function(int textIndex);

/// Kitabın bir sayfasını şablona göre çizer. Editör, önizleme ve küçük resimler aynı widget'ı kullanır.
class PrintPageView extends StatelessWidget {
  const PrintPageView({
    super.key,
    required this.book,
    required this.pageIndex,
    required this.catalog,
    this.slotWrapper,
    this.onTextTap,
    this.showPlaceholders = false,
    this.thumbSize = 600,
    this.highlightSlot,
  });

  final PhotoBook book;
  final int pageIndex;
  final Catalog catalog;
  final SlotWrapper? slotWrapper;
  final TextTap? onTextTap;
  final bool showPlaceholders;
  final int thumbSize;
  final int? highlightSlot;

  @override
  Widget build(BuildContext context) {
    final product = catalog.product(book.productCode);
    final page = book.pages[pageIndex];
    final tpl = catalog.template(page.templateId);
    final theme = catalog.theme(page.themeOverride ?? book.themeId);
    final font = catalog.textAppearance(book.textAppearanceId);
    var elements = tpl.elementsFor(product.format);
    if (page.borderless) elements = borderlessElements(elements);
    final bg = page.isCover ? theme.coverBackground : theme.background;

    return AspectRatio(
      aspectRatio: product.aspect,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        Rect toPx(Rect f) => Rect.fromLTWH(f.left / 100 * w, f.top / 100 * h, f.width / 100 * w, f.height / 100 * h);
        final photoRects = <Rect>[];
        final children = <Widget>[];
        var photoIdx = 0, textIdx = 0;
        for (final e in elements) {
          final r = toPx(e.frame);
          if (e.isPhoto) {
            final i = photoIdx++;
            photoRects.add(r);
            final slot = i < page.photos.length ? page.photos[i] : null;
            Widget child = _PhotoSlotView(
              slot: slot,
              photo: slot == null ? null : book.photos[slot.photoId],
              background: bg,
              showPlaceholder: showPlaceholders,
              thumbSize: thumbSize,
            );
            if (e.border && !page.borderless) {
              final bw = w * 0.012;
              child = Container(color: Colors.white, padding: EdgeInsets.all(bw), child: child);
            }
            if (highlightSlot == i) {
              child = DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFF00ACC3), width: 3)),
                child: child,
              );
            }
            if (slotWrapper != null) child = slotWrapper!(context, i, child);
            children.add(Positioned.fromRect(rect: r, child: child));
          } else {
            final i = textIdx++;
            final onPhoto = photoRects.any((p) => p.overlaps(r.deflate(2)));
            final value = _textValue(page, e, i);
            final coverTitle = page.isCover && e.role == 'title';
            if (e.scrim && onPhoto) {
              children.add(Positioned(
                left: 0,
                right: 0,
                top: r.top - r.height,
                bottom: 0,
                child: const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0x99000000)],
                      ),
                    ),
                  ),
                ),
              ));
            }
            Widget textView = _TextSlotView(
                text: coverTitle ? book.title : value,
                subtitle: coverTitle ? book.subtitle : '',
                role: e.role,
                align: e.align,
                pageHeight: h,
                color: onPhoto ? Colors.white : (e.role == 'title' ? (page.isCover ? theme.coverText : theme.title) : theme.text),
                shadow: onPhoto,
                font: font,
                placeholder: showPlaceholders && value.isEmpty,
                onTap: onTextTap == null ? null : () => onTextTap!(i),
              );
            if (e.vertical) textView = RotatedBox(quarterTurns: 3, child: textView);
            children.add(Positioned.fromRect(rect: r, child: textView));
          }
        }
        return ClipRect(child: ColoredBox(color: bg, child: Stack(children: children)));
      }),
    );
  }

  String _textValue(PrintPage page, TemplateElement e, int i) {
    if (page.isCover) {
      if (e.role == 'title') return book.subtitle.isEmpty ? book.title : '${book.title}\n${book.subtitle}';
      return book.subtitle;
    }
    return i < page.texts.length ? page.texts[i] : '';
  }
}

class _PhotoSlotView extends StatelessWidget {
  const _PhotoSlotView({
    required this.slot,
    required this.photo,
    required this.background,
    required this.showPlaceholder,
    required this.thumbSize,
  });

  final PhotoSlot? slot;
  final BookPhoto? photo;
  final Color background;
  final bool showPlaceholder;
  final int thumbSize;

  @override
  Widget build(BuildContext context) {
    final s = slot;
    if (s == null) {
      return ColoredBox(
        color: const Color(0xFFEDEDED),
        child: showPlaceholder
            ? const Center(child: Icon(Icons.add_photo_alternate_outlined, color: Colors.black38))
            : null,
      );
    }
    return LayoutBuilder(builder: (context, c) {
      final r = photoRect(Size(c.maxWidth, c.maxHeight), photo?.aspect ?? 1, s);
      return ClipRect(
        child: ColoredBox(
          color: s.fit ? background : const Color(0xFFE6E6E6),
          child: Stack(children: [
            Positioned.fromRect(
              rect: r,
              child: RotatedBox(
                quarterTurns: s.quarterTurns % 4,
                child: PhotoImage(photoId: s.photoId, size: thumbSize, fit: BoxFit.fill),
              ),
            ),
          ]),
        ),
      );
    });
  }
}

/// Fotoğraf alanlarının kapladığı bölgeyi sayfanın tamamına genişletir (kenarlıksız görünüm).
List<TemplateElement> borderlessElements(List<TemplateElement> elements) {
  final photos = elements.where((e) => e.isPhoto).map((e) => e.frame).toList();
  if (photos.isEmpty) return elements;
  final u = photos.reduce((a, b) => a.expandToInclude(b));
  if (u.width <= 0 || u.height <= 0) return elements;
  Rect map(Rect f) => Rect.fromLTWH(
        (f.left - u.left) / u.width * 100,
        (f.top - u.top) / u.height * 100,
        f.width / u.width * 100,
        f.height / u.height * 100,
      );
  return [
    for (final e in elements)
      e.isPhoto ? TemplateElement(type: e.type, role: e.role, frame: map(e.frame), align: e.align) : e,
  ];
}

/// Alan içinde fotoğrafın çizileceği dikdörtgen (döndürülmüş en-boy, Doldur/Sığdır, yakınlaştırma ve kaydırma).
Rect photoRect(Size slot, double photoAspect, PhotoSlot s) {
  final a = s.quarterTurns.isOdd ? 1 / photoAspect : photoAspect;
  final slotAspect = slot.width / slot.height;
  double w, h;
  final cover = !s.fit;
  if ((a > slotAspect) == cover) {
    h = slot.height;
    w = h * a;
  } else {
    w = slot.width;
    h = w / a;
  }
  w *= s.scale;
  h *= s.scale;
  final ox = (w - slot.width).abs() / 2;
  final oy = (h - slot.height).abs() / 2;
  final left = (slot.width - w) / 2 + s.dx * ox;
  final top = (slot.height - h) / 2 + s.dy * oy;
  return Rect.fromLTWH(left, top, w, h);
}

class _TextSlotView extends StatelessWidget {
  const _TextSlotView({
    required this.text,
    this.subtitle = '',
    required this.role,
    required this.align,
    required this.pageHeight,
    required this.color,
    required this.shadow,
    required this.font,
    required this.placeholder,
    this.onTap,
  });

  final String text;
  final String subtitle;
  final String role;
  final TextAlign align;
  final double pageHeight;
  final Color color;
  final bool shadow;
  final TextAppearance font;
  final bool placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isTitle = role == 'title';
    final style = TextStyle(
      fontFamily: isTitle ? font.titleFont : font.bodyFont,
      fontWeight: isTitle ? font.titleWeight : FontWeight.w400,
      letterSpacing: font.letterSpacing * pageHeight / 400,
      fontSize: isTitle ? pageHeight * (subtitle.isEmpty ? 0.06 : 0.048) : pageHeight * 0.03,
      height: 1.2,
      color: placeholder ? color.withValues(alpha: 0.45) : color,
      shadows: shadow ? const [Shadow(blurRadius: 6, color: Colors.black54)] : null,
    );
    final alignment = switch (align) {
      TextAlign.left => Alignment.centerLeft,
      TextAlign.right => Alignment.centerRight,
      _ => Alignment.center,
    };
    Widget child;
    if (text.isEmpty && !placeholder) {
      child = const SizedBox.expand();
    } else {
      final value = placeholder ? (isTitle ? 'Başlık' : 'Altyazı eklemek için dokun') : font.apply(text);
      Widget titleBlock = Text(value, textAlign: align, style: style);
      if (isTitle && subtitle.isNotEmpty && !placeholder) {
        titleBlock = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: switch (align) {
            TextAlign.left => CrossAxisAlignment.start,
            TextAlign.right => CrossAxisAlignment.end,
            _ => CrossAxisAlignment.center,
          },
          children: [
            titleBlock,
            SizedBox(height: pageHeight * 0.008),
            Text(
              font.apply(subtitle),
              textAlign: align,
              style: style.copyWith(
                fontFamily: font.bodyFont,
                fontWeight: FontWeight.w400,
                fontSize: pageHeight * 0.022,
                letterSpacing: 0,
              ),
            ),
          ],
        );
      }
      child = Align(
        alignment: alignment,
        child: isTitle
            ? FittedBox(fit: BoxFit.scaleDown, alignment: alignment, child: titleBlock)
            : Text(value, textAlign: align, style: style, overflow: TextOverflow.fade),
      );
    }
    if (placeholder) {
      child = DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.3))),
        child: child,
      );
    }
    return onTap == null ? child : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child);
  }
}
