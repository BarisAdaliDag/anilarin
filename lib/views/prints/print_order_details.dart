import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/print_set.dart';
import '../../view_model/app_view_model.dart';
import '../basket/basket_screen.dart';
import '../order/order_details_screen.dart' show OrderCarousel, OrderOptionCard, SceneMockup, UnitToggle;
import '../widgets/price_text.dart';
import '../widgets/print_card.dart';
import '../widgets/ref_image.dart';

/// Baskı setinin elde tutulduğu Popsa sahnesi (topdownscene/BACKGROUND_PTSn).
const _scenes = {
  'PRN-S-S': 'PTS-2',
  'PRN-S-M': 'PTS-3',
  'PRN-S-L': 'PTS-4',
  'PRN-R-S': 'PTS-5',
  'PRN-R-M': 'PTS-6',
  'PRN-R-L': 'PTS-7',
  'PRN-R-XL': 'PTS-8',
};

/// Baskı editöründe "İleri": Popsa Order Details (Photo Prints) — Boyut (elde tutulan baskı sahnesi),
/// Kâğıt Yüzeyi, altta Ara Toplam; üstte "Sepete Ekle". Seçimler sete hemen işlenir ([onChanged] kaydeder).
Future<void> showPrintOrderDetails(BuildContext context, PrintSet set, {required VoidCallback onChanged}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.97,
      child: _PrintOrderDetails(set: set, onChanged: onChanged),
    ),
  );
}

class _PrintOrderDetails extends StatefulWidget {
  const _PrintOrderDetails({required this.set, required this.onChanged});

  final PrintSet set;
  final VoidCallback onChanged;

  @override
  State<_PrintOrderDetails> createState() => _PrintOrderDetailsState();
}

class _PrintOrderDetailsState extends State<_PrintOrderDetails> {
  bool _inches = false;

  PrintSet get _set => widget.set;

  void _update(VoidCallback change) {
    setState(change);
    widget.onChanged();
  }

  Future<void> _addToBasket() async {
    final app = context.read<AppViewModel>();
    final nav = Navigator.of(context);
    await app.addPrintSetToBasket(_set);
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => const BasketScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final fonts = app.catalog!.textAppearances;
    final product = _set.product;
    final sizes = PrintCatalog.ofFormat(product.format);
    final inBasket = app.basket.any((b) => b.bookId == _set.id);
    final price = product.totalCents(_set.count);
    Widget header(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 0),
      child: Text(t, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
    );
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.only(bottom: 130),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            icon: const Icon(Icons.close, size: 30),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: context.pillColor,
                              foregroundColor: context.strongText,
                              minimumSize: const Size(0, 42),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _addToBasket,
                            iconAlignment: IconAlignment.end,
                            icon: const Icon(Icons.check, size: 20),
                            label: Text(
                              inBasket ? S.viewInBasket : S.addToBasket,
                              style: const TextStyle(fontSize: 17),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text(S.orderDetails, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      Text(S.printOrderBody, style: TextStyle(fontSize: 16, height: 1.45, color: context.mutedText)),
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(S.upgradeSize, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                          ),
                          UnitToggle(inches: _inches, onChanged: (v) => setState(() => _inches = v)),
                        ],
                      ),
                    ],
                  ),
                ),
                OrderCarousel(
                  selected: sizes.indexWhere((p) => p.code == product.code),
                  children: [
                    for (final p in sizes)
                      OrderOptionCard(
                        title: S.sizeName(p.size),
                        subtitle: p.dimensions(inches: _inches),
                        selected: p.code == product.code,
                        onTap: () => _update(() => _set.productCode = p.code),
                        background: SceneMockup(
                          sceneKey: _scenes[p.code]!,
                          fit: BoxFit.contain,
                          fallback: PrintCard(set: _set, index: 0, fonts: fonts, thumbSize: 400),
                          child: SizedBox(
                            width: 400,
                            child: PrintCard(set: _set, index: 0, fonts: fonts, thumbSize: 500),
                          ),
                        ),
                      ),
                  ],
                ),
                header(S.paperFinishSection),
                OrderCarousel(
                  selected: _set.matte ? 1 : 0,
                  children: [
                    OrderOptionCard(
                      title: S.gloss,
                      subtitle: S.tierStandard,
                      selected: !_set.matte,
                      onTap: () => _update(() => _set.matte = false),
                      background: const RefImage('assets/ref/media/prints_paper_gloss.jpg'),
                    ),
                    OrderOptionCard(
                      title: S.matte,
                      subtitle: S.tierPremium,
                      selected: _set.matte,
                      onTap: () => _update(() => _set.matte = true),
                      background: const RefImage('assets/ref/media/prints_paper_matte.jpg'),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 18 + MediaQuery.paddingOf(context).bottom),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: context.divider, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(S.subtotal, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                        ),
                        PriceText(
                          price: app.coupon?.apply(price) ?? price,
                          compareAt: product.compareCents(_set.count),
                          size: 19,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
