import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/basket_item.dart';
import '../../models/catalog.dart';
import '../../view_model/app_view_model.dart';
import '../../view_model/editor_view_model.dart';
import '../checkout/checkout_screens.dart';
import '../editor/editor_screen.dart';
import '../home/designs_tab.dart' show openProducts;
import '../order/order_details_screen.dart';
import '../widgets/book_mockup.dart';
import '../prints/print_screens.dart';
import '../widgets/price_text.dart';
import '../widgets/print_card.dart';

/// Sepet (Popsa Basket): ürün kartları, indirim kodu kartı ve özet; ödeme üstteki düğmede.
/// [embedded] true ise ana sayfa sekmesi olarak gösterilir.
class BasketScreen extends StatefulWidget {
  const BasketScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<BasketScreen> createState() => _BasketScreenState();
}

class _BasketScreenState extends State<BasketScreen> {
  final _scroll = ScrollController();
  bool _titleInBar = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.offset > 60;
      if (show != _titleInBar) setState(() => _titleInBar = show);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final items = app.basket;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        centerTitle: true,
        title: AnimatedOpacity(
          opacity: _titleInBar ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: const Text(S.basketTitle),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: context.pillColor,
                foregroundColor: context.strongText,
                minimumSize: const Size(0, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: items.isEmpty ? null : () => startCheckout(context),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward, size: 20),
              label: const Text(S.checkout, style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          const Text(S.basketTitle, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(S.basketBody, style: TextStyle(fontSize: 16, height: 1.4, color: context.mutedText)),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  S.itemsN(app.basketCount),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
              ),
              if (items.isNotEmpty) _RoundIcon(icon: Icons.close, onTap: () => _confirmClear(context, app)),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 56, color: context.mutedText),
                  const SizedBox(height: 10),
                  Text(S.basketEmpty, style: TextStyle(fontSize: 17, color: context.mutedText)),
                ],
              ),
            ),
          for (final item in items) _ItemCard(item: item),
          const SizedBox(height: 8),
          _WideButton(label: S.addAnotherItem, onTap: () => openProducts(context)),
          const SizedBox(height: 30),
          const Text(S.discounts, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
          if (app.coupon case final c?) _CouponCard(coupon: c),
          _WideButton(label: S.redeemCodes, onTap: () => _redeem(context, app)),
          if (items.isNotEmpty) ...[
            Divider(height: 48, color: context.divider),
            _SummaryRow(label: S.discounts, value: '-${formatPrice(app.basketDiscount)}'),
            const SizedBox(height: 10),
            _SummaryRow(label: S.subtotal, value: formatPrice(app.basketTotal), strong: true),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, AppViewModel app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(S.clearBasketQ),
        content: const Text(S.clearBasketBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text(S.cancel)),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text(S.clear)),
        ],
      ),
    );
    if (ok == true) await app.clearBasket();
  }
}

/// Kod girme penceresi; geçersizse altında uyarı.
Future<void> _redeem(BuildContext context, AppViewModel app) async {
  final controller = TextEditingController();
  String? error;
  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setDialog) => AlertDialog(
        title: const Text(S.redeemCodes),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: S.enterCode, errorText: error),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text(S.cancel)),
          TextButton(
            onPressed: () async {
              if (await app.redeem(controller.text)) {
                if (c.mounted) Navigator.pop(c);
              } else {
                setDialog(() => error = S.codeInvalid);
              }
            },
            child: const Text(S.redeem),
          ),
        ],
      ),
    ),
  );
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});

  final BasketItem item;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final catalog = app.catalog!;
    final book = item.isPrints ? null : app.book(item.bookId);
    final set = item.isPrints ? app.printSet(item.bookId) : null;
    final cover = set != null
        ? Color.lerp(hexColor(set.colorHex), Colors.black, 0.2)!
        : book == null
        ? context.pillColor
        : Color.lerp(
            catalog
                .resolve(book.themeIdOf(0), pagePalette: book.pages.first.palette, bookPalette: book.palette)
                .background,
            Colors.black,
            0.45,
          )!;
    final lines = app.itemLines(item);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.divider, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 128,
              color: cover,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              child: set != null
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: PrintCard(set: set, index: 0, fonts: catalog.textAppearances, thumbSize: 300),
                    )
                  : book == null
                  ? const Icon(Icons.menu_book, size: 40, color: Colors.white70)
                  : BookMockup(book: book, catalog: catalog),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    _Quantity(item: item),
                    const SizedBox(height: 10),
                    for (final l in lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(l, style: TextStyle(fontSize: 15, color: context.mutedText)),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: PriceText(price: app.itemPrice(item), compareAt: app.itemCompareAt(item), size: 17),
                        ),
                        _MoreButton(onTap: () => _itemMenu(context, app, item)),
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

class _Quantity extends StatelessWidget {
  const _Quantity({required this.item});

  final BasketItem item;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppViewModel>();
    return Row(
      children: [
        Expanded(child: Text(S.copiesN(item.quantity), style: const TextStyle(fontSize: 16))),
        _RoundIcon(
          icon: Icons.remove,
          onTap: item.quantity > 1 ? () => app.setQuantity(item, item.quantity - 1) : null,
        ),
        const SizedBox(width: 10),
        _RoundIcon(icon: Icons.add, onTap: () => app.setQuantity(item, item.quantity + 1)),
      ],
    );
  }
}

/// Ürünün ••• menüsü (Popsa): adet, düzenle, önizle, sipariş ayrıntıları, kaldır.
void _itemMenu(BuildContext context, AppViewModel app, BasketItem item) {
  EditorViewModel? editorVm() {
    final book = app.book(item.bookId);
    if (book == null) return null;
    return EditorViewModel(book: book.clone(), catalog: app.catalog!, onSave: app.saveBook);
  }

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: ListenableBuilder(
        listenable: app,
        builder: (c, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(item.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: _Quantity(item: item),
            ),
            Divider(color: c.divider, indent: 20, endIndent: 20),
            if (item.isPrints && app.printSet(item.bookId) != null)
              _MenuTile(
                icon: Icons.dashboard_outlined,
                label: S.editLayout,
                onTap: () {
                  Navigator.pop(c);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => PrintSetScreen(setId: item.bookId)));
                },
              ),
            if (!item.isPrints && app.book(item.bookId) != null) ...[
              _MenuTile(
                icon: Icons.dashboard_outlined,
                label: S.editLayout,
                onTap: () {
                  Navigator.pop(c);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorScreen(bookId: item.bookId)));
                },
              ),
              _MenuTile(
                icon: Icons.view_in_ar_outlined,
                label: S.preview,
                onTap: () {
                  Navigator.pop(c);
                  if (editorVm() case final vm?) openPreview(context, vm);
                },
              ),
              _MenuTile(
                icon: Icons.auto_stories_outlined,
                label: S.changeOrderDetails,
                onTap: () async {
                  Navigator.pop(c);
                  final vm = editorVm();
                  if (vm == null) return;
                  await showOrderDetails(context, vm, fromBasket: true);
                  await vm.flush();
                  await app.addToBasket(vm.book);
                  vm.dispose();
                },
              ),
            ],
            _MenuTile(
              icon: Icons.delete_outline,
              label: S.removeFromBasket,
              onTap: () {
                Navigator.pop(c);
                app.removeFromBasket(item);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Popsa'daki mor kupon kartı: solda tekrar eden yazılı desen, sağda kod.
class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon});

  final Coupon coupon;

  @override
  Widget build(BuildContext context) {
    final title = S.welcomeDiscount(coupon.percent);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.divider, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 128,
              color: const Color(0xFF5B2D9C),
              // Desen kartın yüksekliğini etkilemesin: Stack + Positioned.fill (içsel yükseklik 0).
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRect(
                      child: OverflowBox(
                        maxWidth: 320,
                        maxHeight: 320,
                        child: Transform.rotate(
                          angle: -0.5,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < 9; i++)
                                Text(
                                  '${title.toUpperCase()}  ${title.toUpperCase()}',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: const TextStyle(
                                    color: Color(0x40FFFFFF),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    height: 1.5,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Text(S.validOnAll, style: TextStyle(fontSize: 15, color: context.mutedText)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        CustomPaint(
                          painter: _DashedBorder(color: context.mutedText),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Text(coupon.code, style: const TextStyle(fontSize: 17, letterSpacing: 0.5)),
                          ),
                        ),
                        const Spacer(),
                        _MoreButton(onTap: () => _couponMenu(context, coupon)),
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

void _couponMenu(BuildContext context, Coupon coupon) {
  final app = context.read<AppViewModel>();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              S.welcomeDiscount(coupon.percent),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
          ),
          Divider(color: c.divider, indent: 20, endIndent: 20),
          _MenuTile(
            icon: Icons.local_offer_outlined,
            label: S.redeemDifferent,
            onTap: () {
              Navigator.pop(c);
              _redeem(context, app);
            },
          ),
          _MenuTile(
            icon: Icons.delete_outline,
            label: S.removeFromBasket,
            onTap: () {
              Navigator.pop(c);
              app.removeCoupon();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    void dashes(Offset a, Offset b) {
      final len = (b - a).distance;
      final dir = (b - a) / len;
      for (double d = 0; d < len; d += 7) {
        canvas.drawLine(a + dir * d, a + dir * (d + 4).clamp(0, len), p);
      }
    }

    dashes(Offset.zero, Offset(size.width, 0));
    dashes(Offset(size.width, 0), Offset(size.width, size.height));
    dashes(Offset(size.width, size.height), Offset(0, size.height));
    dashes(Offset(0, size.height), Offset.zero);
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 18, fontWeight: strong ? FontWeight.w600 : FontWeight.w400);
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}

class _WideButton extends StatelessWidget {
  const _WideButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: context.pillColor,
          foregroundColor: context.strongText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 17)),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _RoundIcon(icon: Icons.more_horiz, onTap: onTap);
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.pillColor,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 22, color: onTap == null ? context.mutedText.withValues(alpha: 0.5) : null),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontSize: 17)),
      onTap: onTap,
    );
  }
}
