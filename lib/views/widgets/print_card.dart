import 'package:flutter/material.dart';

import '../../models/catalog.dart';
import '../../models/print_set.dart';
import 'photo_image.dart';

/// Tek bir baskının görünümü (Popsa baskı editörü): zemin rengi, beyaz çerçeveli fotoğraf, altında yazı.
/// [title]/[subtitle] verilirse kapak baskısıdır ve yazı alanında başlık gösterilir.
class PrintCard extends StatelessWidget {
  const PrintCard({
    super.key,
    required this.item,
    required this.product,
    required this.colorHex,
    this.title,
    this.subtitle,
    this.thumbSize = 700,
  });

  final PrintItem item;
  final PrintProduct product;
  final String colorHex;
  final String? title;
  final String? subtitle;
  final int thumbSize;

  @override
  Widget build(BuildContext context) {
    final bg = hexColor(colorHex);
    final dark = bg.computeLuminance() < 0.5;
    final fg = dark ? Colors.white : const Color(0xFF222222);
    final aspect = product.square ? 1.0 : (item.portrait ? 1 / product.aspect : product.aspect);
    final hasText = (title != null && title!.isNotEmpty) || item.caption.isNotEmpty;
    return AspectRatio(
      aspectRatio: aspect,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final margin = w * 0.07;
          final textH = hasText ? w * 0.16 : 0.0;
          final frame = item.border ? w * 0.012 : 0.0;
          return ColoredBox(
            color: bg,
            child: Padding(
              padding: EdgeInsets.fromLTRB(margin, margin, margin, hasText ? 0 : margin),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(frame),
                      decoration: BoxDecoration(
                        color: item.border ? Colors.white : null,
                        borderRadius: BorderRadius.circular(w * 0.012),
                        boxShadow: item.border
                            ? const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))]
                            : null,
                      ),
                      child: SizedBox.expand(
                        child: PhotoImage(photoId: item.photo.id, size: thumbSize),
                      ),
                    ),
                  ),
                  if (hasText)
                    SizedBox(
                      height: textH + margin * 0.4,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title != null && title!.isNotEmpty ? title! : item.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: fg, fontSize: w * 0.052, fontWeight: FontWeight.w500),
                            ),
                            if (subtitle != null && subtitle!.isNotEmpty)
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: fg.withValues(alpha: 0.85), fontSize: w * 0.03),
                              ),
                          ],
                        ),
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
