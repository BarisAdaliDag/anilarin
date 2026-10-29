import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/asset_paths.dart';
import '../../constants/strings_tr.dart';
import '../../models/catalog.dart';
import '../../models/photo_book.dart';
import '../../view_model/app_view_model.dart';
import '../photo_picker/photo_picker_screen.dart';
import '../widgets/asset_video.dart';
import '../widgets/price_text.dart';
import '../widgets/ref_image.dart';

/// Boyut, fiyat, ürün özellikleri, ekstralar ve teslimat (Popsa ProductFormatDetailActivity).
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

  static const _descriptions = {
    'hardback': 'Dayanıklı kapaklı, sırtında başlığın yazan premium kitaplar.',
    'softcover': 'Hafif, esnek kapaklı; her güne uygun şık bir albüm.',
    'booklet': 'İnce ve zarif; kısa anılar ve hediyeler için ideal.',
  };

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<AppViewModel>().catalog!;
    final products = catalog.products.where((p) => p.type == widget.type && p.format == widget.format).toList();
    final sizeIndex = _selected ??= products.indexWhere((p) => p.size == 'large').clamp(0, products.length - 1);
    final product = products[sizeIndex];
    final media = [AssetPaths.productVideo, ...AssetPaths.productCarousel];
    final dims = product.dimensionsCm.split('×').map((e) => double.tryParse(e.trim()) ?? 0).toList();
    final inches = dims.map((d) => (d / 2.54).round()).join('" × ');
    final now = DateTime.now();
    final fmt = DateFormat('d MMMM', 'tr');
    String range(int a, int b) =>
        '${fmt.format(now.add(Duration(days: a)))} – ${fmt.format(now.add(Duration(days: b)))}';

    return Scaffold(
      appBar: AppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _PillButton(
              label: S.next,
              icon: Icons.arrow_forward,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PhotoPickerScreen(product: product, options: _options.copy()),
              )),
            ),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(_descriptions[product.type]!, style: TextStyle(fontSize: 15, color: context.mutedText, height: 1.4)),
            const SizedBox(height: 18),
            if (products.length > 1)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: context.pillColor, borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < products.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _selected = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: i == sizeIndex ? (context.isDark ? const Color(0xFF555555) : Colors.white) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(products[i].sizeLabel, style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                ]),
              ),
            const SizedBox(height: 18),
            PriceText(price: product.priceCents, compareAt: product.compareAtCents, size: 21),
            const SizedBox(height: 16),
          ]),
        ),
        AspectRatio(
          aspectRatio: 1.15,
          child: Stack(children: [
            PageView.builder(
              itemCount: media.length,
              onPageChanged: (i) => setState(() => _mediaIndex = i),
              itemBuilder: (_, i) => media[i].endsWith('.mp4')
                  ? AssetVideo(path: media[i], playing: _mediaIndex == 0, fallback: const RefImage(AssetPaths.heroPhotoBook))
                  : RefImage(media[i]),
            ),
            Positioned(
              left: 20,
              bottom: 14,
              child: Row(children: [
                for (var i = 0; i < media.length; i++)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _mediaIndex ? Colors.white : Colors.white54,
                    ),
                  ),
              ]),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                color: const Color(0xCC1E1E1E),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: const Text(S.soldBanner, style: TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 1.2)),
              ),
            ),
          ]),
        ),
        const _SectionTitle(S.productSpecs),
        _SpecRow(icon: Icons.straighten, title: '${product.dimensionsCm} cm', subtitle: '$inches"'),
        _SpecRow(
          icon: Icons.menu_book_outlined,
          title: '${product.pagesDefault} sayfa',
          subtitle: product.canChangePages ? '${product.pagesMax - product.pagesDefault} ek sayfaya kadar eklenebilir' : null,
        ),
        const _SpecRow(icon: Icons.layers_outlined, title: '200 g/m² kâğıt'),
        const _SpecRow(icon: Icons.auto_awesome_outlined, title: 'Mat yüzey', subtitle: 'Parlak yüzeye yükseltilebilir'),
        _SpecRow(icon: Icons.crop_landscape, title: product.formatLabel),
        const _SectionTitle(S.extras),
        _ExtraRow(
          icon: Icons.auto_fix_high,
          title: S.foil,
          body: product.supportsUpgrades ? S.foilBody : S.hardbackOnly,
          price: Product.foilPriceCents,
          value: product.supportsUpgrades && _options.foil != null,
          onChanged: product.supportsUpgrades ? (v) => setState(() => _options.foil = v ? 'gold' : null) : null,
          button: 'Varak seçeneklerini gör',
          onButton: product.supportsUpgrades ? () => _foilOptions(context) : null,
        ),
        _ExtraRow(
          icon: Icons.chrome_reader_mode_outlined,
          title: S.layflat,
          body: product.supportsUpgrades ? S.layflatBody : S.hardbackOnly,
          price: Product.layflatPriceCents,
          value: product.supportsUpgrades && _options.layflat,
          onChanged: product.supportsUpgrades ? (v) => setState(() => _options.layflat = v) : null,
        ),
        _ExtraRow(
          icon: Icons.card_giftcard,
          title: S.giftBox,
          body: S.giftBoxBody,
          price: Product.giftBoxPriceCents,
          value: _options.giftBox,
          onChanged: (v) => setState(() => _options.giftBox = v),
        ),
        if (_options.giftBox && _options.layflat && product.supportsUpgrades)
          const Padding(
            padding: EdgeInsets.fromLTRB(64, 0, 20, 8),
            child: Text(S.giftLayflatLimit, style: TextStyle(color: AppColors.warning, fontSize: 13)),
          ),
        const _SectionTitle(S.delivery),
        _SpecRow(
          icon: Icons.local_shipping_outlined,
          title: S.standardShipping,
          subtitle: 'Bugün sipariş ver, ${range(product.deliveryDays.first + 2, product.deliveryDays.last + 2)} arasında teslim al',
        ),
        _SpecRow(
          icon: Icons.track_changes,
          title: S.trackedShipping,
          subtitle: 'Bugün sipariş ver, ${range(product.deliveryDays.first, product.deliveryDays.last - 2)} arasında teslim al',
        ),
        const _SectionTitle(S.moreInfo),
        const _SpecRow(
          icon: Icons.thumb_up_alt_outlined,
          title: 'Kalite Garantisi',
          subtitle: 'Üründen memnun kalmazsan bize ulaş; düzeltemezsek tam iade ederiz.',
        ),
        const _SpecRow(
          icon: Icons.eco_outlined,
          title: 'Çevreye Duyarlı',
          subtitle: 'Yalnızca biyolojik olarak parçalanabilen ve geri dönüştürülebilir malzemeler.',
        ),
      ]),
    );
  }

  Future<void> _foilOptions(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (id, label, color) in const [
            ('gold', S.foilGold, Color(0xFFD4AF37)),
            ('silver', S.foilSilver, Color(0xFFC0C0C0)),
          ])
            ListTile(
              leading: CircleAvatar(backgroundColor: color),
              title: Text(label),
              trailing: _options.foil == id ? const Icon(Icons.check, color: AppColors.accent) : null,
              onTap: () => Navigator.pop(c, id),
            ),
        ]),
      ),
    );
    if (choice != null) setState(() => _options.foil = choice);
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.pillColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            if (icon != null) ...[const SizedBox(width: 6), Icon(icon, size: 18)],
          ]),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
        child: Text(text, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w500)),
      );
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 24),
        const SizedBox(width: 20),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 16)),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle!, style: TextStyle(color: context.mutedText, height: 1.35)),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _ExtraRow extends StatelessWidget {
  const _ExtraRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.price,
    required this.value,
    required this.onChanged,
    this.button,
    this.onButton,
  });

  final IconData icon;
  final String title;
  final String body;
  final int price;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? button;
  final VoidCallback? onButton;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onChanged == null ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 12, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 24)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$title  +${formatPrice(price)}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Text(body, style: TextStyle(color: context.mutedText, height: 1.35)),
              if (button != null) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: onButton,
                  child: Text(button!),
                ),
              ],
            ]),
          ),
          Switch(value: value, onChanged: onChanged),
        ]),
      ),
    );
  }
}
