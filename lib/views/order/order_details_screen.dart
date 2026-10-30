import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/catalog.dart';
import '../../view_model/editor_view_model.dart';
import '../editor/editor_screen.dart' show buyBook, openPreview;
import '../widgets/asset_video.dart';
import '../widgets/book_mockup.dart';
import '../widgets/price_text.dart';
import '../widgets/print_page_view.dart';
import '../widgets/ref_image.dart';

/// Editörde "İleri"ye basınca açılan Sipariş Ayrıntıları (Popsa Order Details):
/// boyut (elde tutulan kitap sahnesi), kapak türü ve kâğıt yüzeyi kartları; altta ara toplam.
/// [fromBasket]: sepetten açıldıysa İleri yalnız pencereyi kapatır (sepet zaten arkada).
Future<void> showOrderDetails(BuildContext context, EditorViewModel vm, {bool fromBasket = false}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.97,
      child: OrderDetailsScreen(vm: vm, fromBasket: fromBasket),
    ),
  );
}

class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({super.key, required this.vm, this.fromBasket = false});

  final EditorViewModel vm;
  final bool fromBasket;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool _inches = false;

  EditorViewModel get vm => widget.vm;

  Future<void> _next() async {
    final nav = Navigator.of(context);
    nav.pop();
    if (!widget.fromBasket) await buyBook(nav.context, vm);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final product = vm.product;
        final catalog = vm.catalog;
        final sizes = catalog.sizesOf(product.type, product.format);
        final types = [...catalog.productTypes.reversed]; // Kitapçık, Yumuşak, Sert (Popsa sırası)
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
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
                                FilledButton.tonalIcon(
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 42),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: _next,
                                  iconAlignment: IconAlignment.end,
                                  icon: const Icon(Icons.arrow_forward, size: 20),
                                  label: const Text(S.next, style: TextStyle(fontSize: 17)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            const Text(S.orderDetails, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 10),
                            Text(
                              S.orderDetailsBody,
                              style: TextStyle(fontSize: 16, height: 1.45, color: context.mutedText),
                            ),
                            const SizedBox(height: 18),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 46),
                                side: BorderSide(color: context.strongText.withValues(alpha: 0.6), width: 2),
                                foregroundColor: context.strongText,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => openPreview(context, vm),
                              icon: const Icon(Icons.view_in_ar_outlined),
                              label: const Text(S.preview, style: TextStyle(fontSize: 17)),
                            ),
                            const SizedBox(height: 30),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    S.upgradeSize,
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                UnitToggle(inches: _inches, onChanged: (v) => setState(() => _inches = v)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: OrderCarousel(
                        selected: sizes.indexWhere((p) => p.code == product.code),
                        children: [
                          for (final p in sizes)
                            OrderOptionCard(
                              title: p.sizeLabel,
                              subtitle: p.dimensionsLabel(inches: _inches),
                              selected: p.code == product.code,
                              note: vm.book.pageCount > p.pagesMax ? S.maxPagesNote(p.pagesMax) : null,
                              onTap: vm.book.pageCount > p.pagesMax ? null : () => vm.changeProduct(p.code),
                              background: _SizeScene(vm: vm, product: p),
                            ),
                        ],
                      ),
                    ),
                    _header(S.coverSection),
                    SliverToBoxAdapter(
                      child: OrderCarousel(
                        selected: types.indexOf(product.type),
                        children: [
                          for (final type in types)
                            if (catalog.closestOfType(product, type) case final p?)
                              OrderOptionCard(
                                title: p.typeLabel,
                                subtitle: p.tierLabel,
                                selected: product.type == type,
                                badge: type == 'hardback' ? S.mostPopularBadge : null,
                                note: vm.book.pageCount > p.pagesMax
                                    ? S.maxPagesNote(p.pagesMax)
                                    : p.size != product.size
                                    ? S.onlySizes(
                                        catalog.sizesOf(type, product.format).map((s) => s.sizeLabel).join(', '),
                                      )
                                    : null,
                                onTap: vm.book.pageCount > p.pagesMax ? null : () => vm.changeProduct(p.code),
                                background: OrderVideo('assets/ref/media/order_cover_$type.mp4'),
                              ),
                        ],
                      ),
                    ),
                    _header(S.paperFinishSection),
                    SliverToBoxAdapter(
                      child: OrderCarousel(
                        selected: vm.book.options.gloss ? 1 : 0,
                        children: [
                          OrderOptionCard(
                            title: S.matte,
                            subtitle: S.tierStandard,
                            selected: !vm.book.options.gloss,
                            onTap: () => vm.setGloss(false),
                            background: const OrderVideo('assets/ref/media/order_paper_matte.mp4'),
                          ),
                          OrderOptionCard(
                            title: S.gloss,
                            subtitle: S.tierPremium,
                            selected: vm.book.options.gloss,
                            onTap: () => vm.setGloss(true),
                            background: const OrderVideo('assets/ref/media/order_paper_gloss.mp4'),
                          ),
                        ],
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 130)),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _SubtotalBar(vm: vm, onNext: _next),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(String title) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 0),
      child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
    ),
  );
}

/// Ortadaki kart seçili olanla açılır; kenarlarda komşular görünür (Popsa kaydırmalı kartlar).
/// Kaydırmak seçmez, dokunmak seçer.
class OrderCarousel extends StatefulWidget {
  const OrderCarousel({super.key, required this.selected, required this.children});

  final int selected;
  final List<Widget> children;

  @override
  State<OrderCarousel> createState() => _CarouselState();
}

class _CarouselState extends State<OrderCarousel> {
  late final _controller = PageController(viewportFraction: 0.66, initialPage: widget.selected.clamp(0, 99));

  @override
  void didUpdateWidget(OrderCarousel old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected && widget.selected >= 0 && _controller.hasClients) {
      _controller.animateToPage(
        widget.selected,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width * 0.66;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: width / 0.76,
        child: PageView(
          controller: _controller,
          children: [
            for (final c in widget.children) Padding(padding: const EdgeInsets.symmetric(horizontal: 7), child: c),
          ],
        ),
      ),
    );
  }
}

class OrderOptionCard extends StatelessWidget {
  const OrderOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.background,
    this.onTap,
    this.badge,
    this.note,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final Widget background;
  final VoidCallback? onTap;
  final String? badge;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: selected ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: selected ? context.strongText : Colors.transparent, width: 3),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Stack(
            fit: StackFit.expand,
            children: [
              background,
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment(0, -0.2),
                    colors: [Color(0x59000000), Color(0x00000000)],
                  ),
                ),
              ),
              if (onTap == null && !selected) const ColoredBox(color: Color(0x66000000)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                              ),
                              Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                            ],
                          ),
                        ),
                        _Check(selected: selected),
                      ],
                    ),
                    const Spacer(),
                    if (note != null)
                      Text(note!, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.3)),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0x99403530),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? const Color(0xFF2BB5D9) : Colors.transparent,
        border: Border.all(color: selected ? Colors.white : Colors.white54, width: 3),
      ),
      child: selected ? const Icon(Icons.check, color: Colors.white, size: 24) : null,
    );
  }
}

class OrderVideo extends StatelessWidget {
  const OrderVideo(this.path, {super.key});

  final String path;

  @override
  Widget build(BuildContext context) => AssetVideo(
    path: path,
    fallback: const RefPlaceholder(icon: Icons.menu_book_outlined),
  );
}

/// Masada elle tutulan kitap: Popsa sahne arka planı + kitabın kapağı + eller katmanı.
/// Katmanlar `tool/make_scene_overlays.py` ile üretilir; yoksa düz mockup gösterilir.
class _SizeScene extends StatelessWidget {
  const _SizeScene({required this.vm, required this.product});

  final EditorViewModel vm;
  final Product product;

  @override
  Widget build(BuildContext context) => SceneMockup(
    sceneKey: product.code,
    fallback: BookMockup(book: vm.book, catalog: vm.catalog),
    child: SizedBox(
      width: 400,
      child: PrintPageView(book: vm.book, pageIndex: 0, catalog: vm.catalog, thumbSize: 500),
    ),
  );
}

/// Masada elle tutulan ürün sahnesi: Popsa sahne arka planı + [child] (kapak ya da baskı) + eller katmanı.
/// Katmanlar `tool/make_scene_overlays.py` ile üretilir; yoksa [fallback] gösterilir.
class SceneMockup extends StatelessWidget {
  const SceneMockup({
    super.key,
    required this.sceneKey,
    required this.child,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  final String sceneKey;
  final Widget child;
  final Widget fallback;

  /// Ürün sahnedeki alana nasıl yerleşir; dik bir baskı yatay alanda kırpılmasın diye [BoxFit.contain].
  final BoxFit fit;

  static final Future<Map<String, dynamic>?> _rects = rootBundle
      .loadString('assets/ref/mockups/scene/rects.json')
      .then<Map<String, dynamic>?>((s) => jsonDecode(s) as Map<String, dynamic>)
      .catchError((_) => null);

  @override
  Widget build(BuildContext context) {
    final key = sceneKey;
    return FutureBuilder(
      future: _rects,
      builder: (context, snap) {
        final r = (snap.data?[key] as List?)?.cast<num>();
        if (r == null) {
          return ColoredBox(
            color: const Color(0xFFD8CCC2),
            child: Center(
              child: Padding(padding: const EdgeInsets.all(24), child: fallback),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, c) {
            // Sahne 1024×1360; kart oranı yakın, BoxFit.cover gibi ortalanır.
            const sceneAspect = 1024 / 1360;
            final w = c.maxWidth / c.maxHeight > sceneAspect ? c.maxWidth : c.maxHeight * sceneAspect;
            final h = w / sceneAspect;
            final rect = Rect.fromLTRB(r[0] * w, r[1] * h, r[2] * w, r[3] * h);
            return OverflowBox(
              maxWidth: w,
              maxHeight: h,
              child: SizedBox(
                width: w,
                height: h,
                child: Stack(
                  children: [
                    Positioned.fill(child: RefImage('assets/ref/mockups/scene/$key.webp')),
                    Positioned.fromRect(
                      rect: rect,
                      child: FittedBox(fit: fit, clipBehavior: Clip.hardEdge, child: child),
                    ),
                    Positioned.fill(
                      child: Image.asset(
                        'assets/ref/mockups/scene/${key}_OVERLAY.png',
                        fit: BoxFit.fill,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class UnitToggle extends StatelessWidget {
  const UnitToggle({super.key, required this.inches, required this.onChanged});

  final bool inches;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: context.pillColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (v, label) in const [(false, 'cm'), (true, 'in')])
            GestureDetector(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: v == inches ? (context.isDark ? AppColors.darkBackground : Colors.white) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(label, style: const TextStyle(fontSize: 16)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Alttaki ara toplam; dokununca ya da yukarı çekince fiyat dökümü açılır.
class _SubtotalBar extends StatelessWidget {
  const _SubtotalBar({required this.vm, required this.onNext});

  final EditorViewModel vm;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final p = vm.product, b = vm.book;
    return GestureDetector(
      onTap: () => _breakdown(context),
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < 0) _breakdown(context);
      },
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
                  price: p.totalPrice(b.pageCount, b.options),
                  compareAt: p.compareTotal(b.pageCount, b.options),
                  size: 19,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _breakdown(BuildContext context) {
    final p = vm.product, b = vm.book;
    final extra = (b.pageCount - p.pagesDefault).clamp(0, 999);
    final lines = <(String, int)>[
      ('${p.title} (${p.sizeLabel})', p.priceCents),
      if (extra > 0) (S.extraPages(extra), extra * p.incrementPriceCents),
      if (b.options.gloss) (S.glossFinish, p.glossPriceCents),
      if (p.supportsUpgrades && b.options.layflat) (S.layflat, Product.layflatPriceCents),
      if (p.supportsUpgrades && b.options.foil != null) (S.foil, Product.foilPriceCents),
      if (b.options.giftBox) (S.giftBox, Product.giftBoxPriceCents),
    ];
    showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(S.price, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                  ),
                  IconButton.filledTonal(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(c)),
                ],
              ),
              const SizedBox(height: 12),
              for (final (label, cents) in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(label, style: TextStyle(fontSize: 16, color: c.mutedText)),
                      ),
                      Text(formatPrice(cents), style: TextStyle(fontSize: 16, color: c.mutedText)),
                    ],
                  ),
                ),
              Divider(height: 32, color: c.divider),
              Row(
                children: [
                  const Expanded(
                    child: Text(S.subtotal, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  PriceText(
                    price: p.totalPrice(b.pageCount, b.options),
                    compareAt: p.compareTotal(b.pageCount, b.options),
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(c);
                    onNext();
                  },
                  child: const Text(S.next),
                ),
              ),
              const SizedBox(height: 12),
              Text(S.vouchersAtBasket, style: TextStyle(fontSize: 13, color: c.mutedText)),
            ],
          ),
        ),
      ),
    );
  }
}
