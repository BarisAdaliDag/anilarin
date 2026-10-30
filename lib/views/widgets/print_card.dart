import 'package:flutter/material.dart';

import '../../models/catalog.dart';
import '../../models/print_set.dart';
import 'photo_image.dart';
import 'print_page_view.dart' show photoRect;

/// Tek bir baskının görünümü (Popsa baskı editörü): baskı bir kâğıttır; [colorHex] kâğıdın (kenarın) rengidir.
/// Kenarlıda fotoğrafın dört yanında eşit ince kenar kalır, yazı varsa altta bant açılır;
/// kenarsızda fotoğraf baskıyı tamamen kaplar. [title]/[subtitle] verilirse kapak baskısıdır.
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

  static const _duration = Duration(milliseconds: 280);

  /// Baskıdaki fotoğraf alanının en/boy oranı (kenar ve yazı bandı düşülmüş); düzenleme ekranı için.
  static double photoAreaAspect(PrintItem item, PrintProduct product, {String? title, String? subtitle}) {
    final aspect = product.square ? 1.0 : (item.portrait ? 1 / product.aspect : product.aspect);
    final heading = title != null && title.isNotEmpty ? title : item.caption;
    final edge = item.border ? 0.04 : 0.0;
    final band = heading.isEmpty ? 0.0 : (subtitle != null && subtitle.isNotEmpty ? 0.13 : 0.1);
    return (1 - 2 * edge) / (1 / aspect - 2 * edge - band);
  }

  @override
  Widget build(BuildContext context) {
    final paper = hexColor(colorHex);
    final fg = paper.computeLuminance() < 0.5 ? Colors.white : const Color(0xFF222222);
    final aspect = product.square ? 1.0 : (item.portrait ? 1 / product.aspect : product.aspect);
    final heading = title != null && title!.isNotEmpty ? title! : item.caption;
    final hasText = heading.isNotEmpty;
    return AspectRatio(
      aspectRatio: aspect,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final edge = item.border ? w * 0.04 : 0.0;
          final band = hasText ? w * (subtitle != null && subtitle!.isNotEmpty ? 0.13 : 0.1) : 0.0;
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
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: _duration,
                  curve: Curves.easeInOutCubic,
                  left: edge,
                  top: edge,
                  right: edge,
                  bottom: band + edge,
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
                if (hasText)
                  Positioned(
                    left: edge,
                    right: edge,
                    bottom: 0,
                    height: band,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          heading,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: fg, fontSize: w * 0.042, fontWeight: FontWeight.w500),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: w * 0.026),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
