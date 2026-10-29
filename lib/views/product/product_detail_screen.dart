import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/asset_paths.dart';
import '../../constants/strings_tr.dart';
import '../../models/catalog.dart';
import '../../view_model/app_view_model.dart';
import '../widgets/ref_image.dart';
import 'format_detail_screen.dart';

/// Fotoğraf kitabı kategori ekranı: cilt tipi sekmeleri ve format listesi (Popsa ProductDetailActivity).
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String _type = 'hardback';

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<AppViewModel>().catalog!;
    final products = catalog.productsOfType(_type);
    final formats = <String, List<Product>>{};
    for (final p in products) {
      formats.putIfAbsent(p.format, () => []).add(p);
    }
    return Scaffold(
      appBar: AppBar(title: const Text(S.photoBook)),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        const AspectRatio(aspectRatio: 1.6, child: RefImage(AssetPaths.heroPhotoBook)),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Text(S.photoBookDescription, style: TextStyle(fontSize: 15, color: AppColors.text, height: 1.4)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.accent,
              selectedForegroundColor: Colors.white,
            ),
            segments: [
              for (final t in catalog.productTypes)
                ButtonSegment(value: t, label: Text(catalog.productsOfType(t).first.typeLabel)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
        ),
        for (final entry in formats.entries)
          _FormatRow(
            products: entry.value,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FormatDetailScreen(type: _type, format: entry.key),
            )),
          ),
      ]),
    );
  }
}

class _FormatRow extends StatelessWidget {
  const _FormatRow({required this.products, required this.onTap});

  final List<Product> products;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final first = products.first;
    final lowest = products.map((p) => p.priceCents).reduce((a, b) => a < b ? a : b);
    final sizes = products.map((p) => p.dimensionsCm).join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: first.aspect,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: const RefImage(AssetPaths.productPhotoBook),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    '${first.typeLabel} · ${first.formatLabel}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text('$sizes cm', style: const TextStyle(color: AppColors.text, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    '${S.from} ${formatPrice(lowest)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accentDark),
                  ),
                ]),
              ),
            ),
            const Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.chevron_right)),
          ]),
        ),
      ),
    );
  }
}
