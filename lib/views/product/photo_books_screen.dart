import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/asset_paths.dart';
import '../../constants/strings_tr.dart';
import '../../models/catalog.dart';
import '../../view_model/app_view_model.dart';
import '../widgets/price_text.dart';
import '../widgets/ref_image.dart';
import 'format_detail_screen.dart';

/// Fotoğraf kitapları: Yatay/Kare sekmesi ve cilt tipi kartları (Popsa ProductDetailActivity).
class PhotoBooksScreen extends StatefulWidget {
  const PhotoBooksScreen({super.key});

  @override
  State<PhotoBooksScreen> createState() => _PhotoBooksScreenState();
}

class _PhotoBooksScreenState extends State<PhotoBooksScreen> {
  String _format = 'landscape';

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<AppViewModel>().catalog!;
    return Scaffold(
      appBar: AppBar(title: const Text(S.photoBooks)),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
        Text(S.photoBooksDescription, style: TextStyle(fontSize: 15, color: context.mutedText, height: 1.4)),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: _FormatToggle(value: _format, onChanged: (v) => setState(() => _format = v)),
        ),
        const SizedBox(height: 18),
        for (final type in catalog.productTypes)
          if (catalog.products.any((p) => p.type == type && p.format == _format))
            _TypeCard(
              products: catalog.products.where((p) => p.type == type && p.format == _format).toList(),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => FormatDetailScreen(type: type, format: _format),
              )),
            ),
      ]),
    );
  }
}

class _FormatToggle extends StatelessWidget {
  const _FormatToggle({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: context.pillColor, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (v, label) in const [('landscape', S.landscape), ('square', S.square)])
          GestureDetector(
            onTap: () => onChanged(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: v == value ? (context.isDark ? AppColors.darkBackground : Colors.white) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(label, style: const TextStyle(fontSize: 15)),
            ),
          ),
      ]),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({required this.products, required this.onTap});

  final List<Product> products;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cheapest = products.reduce((a, b) => a.priceCents <= b.priceCents ? a : b);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Material(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (cheapest.mostPopular)
                const Text(S.mostPopular, style: TextStyle(color: AppColors.accent, fontSize: 14)),
              Text(cheapest.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              const Text(S.fromUpper, style: TextStyle(fontSize: 12, letterSpacing: 1.2)),
              PriceText(price: cheapest.priceCents, compareAt: cheapest.compareAtCents, size: 17),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 210,
                  child: AspectRatio(
                    aspectRatio: cheapest.format == 'square' ? 1 : 1.3,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(4, 6))],
                      ),
                      child: RefImage(AssetPaths.productCover(cheapest.type, cheapest.format)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
