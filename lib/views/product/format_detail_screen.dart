import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/asset_paths.dart';
import '../../constants/strings_tr.dart';
import '../../models/catalog.dart';
import '../../models/photo_book.dart';
import '../../view_model/app_view_model.dart';
import '../photo_picker/photo_picker_screen.dart';
import '../widgets/ref_image.dart';

/// Boyut seçimi, fiyat ve yükseltmeler (Popsa ProductFormatDetailActivity).
class FormatDetailScreen extends StatefulWidget {
  const FormatDetailScreen({super.key, required this.type, required this.format});

  final String type;
  final String format;

  @override
  State<FormatDetailScreen> createState() => _FormatDetailScreenState();
}

class _FormatDetailScreenState extends State<FormatDetailScreen> {
  int? _selected;
  int _mediaIndex = 0;
  final _options = ProductOptions();

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<AppViewModel>().catalog!;
    final products = catalog.products.where((p) => p.type == widget.type && p.format == widget.format).toList();
    // varsayılan: orta boy varsa o
    final sizeIndex = _selected ??= products.indexWhere((p) => p.size == 'medium').clamp(0, products.length - 1);
    final product = products[sizeIndex];
    final total = product.totalPrice(product.pagesDefault, _options);
    final media = [AssetPaths.heroPhotoBook, AssetPaths.productPhotoBook, AssetPaths.onboarding];

    return Scaffold(
      appBar: AppBar(title: Text('${product.typeLabel} · ${product.formatLabel}')),
      body: ListView(padding: const EdgeInsets.only(bottom: 120), children: [
        if (products.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(children: [
              for (var i = 0; i < products.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      showCheckmark: false,
                      label: SizedBox(
                        width: double.infinity,
                        child: Column(children: [
                          Text(products[i].sizeLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${products[i].dimensionsCm} cm', style: const TextStyle(fontSize: 11)),
                        ]),
                      ),
                      selected: i == sizeIndex,
                      labelStyle: TextStyle(color: i == sizeIndex ? Colors.white : AppColors.textStrong),
                      onSelected: (_) => setState(() => _selected = i),
                    ),
                  ),
                ),
            ]),
          ),
        SizedBox(
          height: 280,
          child: PageView.builder(
            itemCount: media.length,
            onPageChanged: (i) => setState(() => _mediaIndex = i),
            itemBuilder: (_, i) => RefImage(media[i]),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < media.length; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == _mediaIndex ? AppColors.accent : AppColors.grey,
              ),
            ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              formatPrice(product.priceCents),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.accentDark),
            ),
            const SizedBox(height: 2),
            Text(
              product.canChangePages
                  ? '${product.pagesDefault} ${S.pagesIncluded} · ${S.extraPage} ${formatPrice(product.incrementPriceCents)}'
                  : '${product.pagesDefault} ${S.pagesIncluded}',
              style: const TextStyle(color: AppColors.text),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        _InfoRow(
          icon: Icons.straighten,
          title: '${product.dimensionsCm} cm',
          subtitle: '${product.sizeLabel} · ${product.formatLabel}',
        ),
        _InfoRow(
          icon: Icons.local_shipping_outlined,
          title: S.deliveryEstimate,
          subtitle: '${product.deliveryDays.first}–${product.deliveryDays.last} iş günü',
        ),
        const Divider(height: 32, indent: 20, endIndent: 20),
        _InfoRow(
          icon: Icons.card_giftcard,
          title: '${S.giftBox} (+${formatPrice(Product.giftBoxPriceCents)})',
          subtitle: S.giftBoxBody,
          trailing: Switch(
            value: _options.giftBox,
            onChanged: (v) => setState(() => _options.giftBox = v),
          ),
        ),
        _InfoRow(
          icon: Icons.menu_book,
          title: '${S.layflat} (+${formatPrice(Product.layflatPriceCents)})',
          subtitle: product.supportsUpgrades ? S.layflatBody : S.hardbackOnly,
          enabled: product.supportsUpgrades,
          trailing: Switch(
            value: product.supportsUpgrades && _options.layflat,
            onChanged: product.supportsUpgrades ? (v) => setState(() => _options.layflat = v) : null,
          ),
        ),
        _InfoRow(
          icon: Icons.auto_awesome,
          title: '${S.foil} (+${formatPrice(Product.foilPriceCents)})',
          subtitle: product.supportsUpgrades ? S.foilBody : S.hardbackOnly,
          enabled: product.supportsUpgrades,
          trailing: Switch(
            value: product.supportsUpgrades && _options.foil != null,
            onChanged: product.supportsUpgrades
                ? (v) => setState(() => _options.foil = v ? 'gold' : null)
                : null,
          ),
        ),
        if (product.supportsUpgrades && _options.foil != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 20, 8),
            child: Wrap(spacing: 8, children: [
              for (final (id, label, color) in [
                ('gold', S.foilGold, const Color(0xFFD4AF37)),
                ('silver', S.foilSilver, const Color(0xFFC0C0C0)),
              ])
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: color, radius: 8),
                  label: Text(label),
                  selected: _options.foil == id,
                  onSelected: (_) => setState(() => _options.foil = id),
                ),
            ]),
          ),
        if (_options.giftBox && _options.layflat && product.supportsUpgrades)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(S.giftLayflatLimit, style: TextStyle(color: AppColors.warning, fontSize: 13)),
          ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          child: Row(children: [
            Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(S.total, style: TextStyle(color: AppColors.text, fontSize: 12)),
              Text(formatPrice(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PhotoPickerScreen(product: product, options: _options.copy()),
                )),
                child: const Text(S.next),
              ),
            ),
          ]),
        ),
      ),
    );
  }

}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        leading: Icon(icon, color: AppColors.accent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }
}
