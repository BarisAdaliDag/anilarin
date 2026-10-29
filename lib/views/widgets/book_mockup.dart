import 'package:flutter/material.dart';

import '../../models/catalog.dart';
import '../../models/photo_book.dart';
import 'print_page_view.dart';

/// Kitabın kapağını üstten görünüm mockup'ı üzerinde gösterir
/// (assets/ref/mockups/topdown ışık katmanı; yoksa düz gölge).
class BookMockup extends StatelessWidget {
  const BookMockup({super.key, required this.book, required this.catalog});

  final PhotoBook book;
  final Catalog catalog;

  @override
  Widget build(BuildContext context) {
    final product = catalog.product(book.productCode);
    final square = product.format == 'square';
    final canvas = square ? const Size(942, 942) : const Size(942, 753);
    final quad = switch (product.mockupKey) {
      'PHOTOBOOKLET' => const Rect.fromLTRB(63, 45, 847, 602),
      'SOFTCOVER' => const Rect.fromLTRB(63, 45, 847, 640),
      'HARDBACK' => const Rect.fromLTRB(63, 45, 847, 645),
      _ => const Rect.fromLTRB(63, 45, 849, 831),
    };
    return AspectRatio(
      aspectRatio: canvas.width / canvas.height,
      child: LayoutBuilder(builder: (context, c) {
        final k = c.maxWidth / canvas.width;
        final r = Rect.fromLTRB(quad.left * k, quad.top * k, quad.right * k, quad.bottom * k);
        return Stack(children: [
          Positioned.fromRect(
            rect: r,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: 400,
                    child: PrintPageView(book: book, pageIndex: 0, catalog: catalog, thumbSize: 500),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Image.asset(
                'assets/ref/mockups/topdown/${product.mockupKey}_LIGHTING.webp',
                fit: BoxFit.fill,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}
