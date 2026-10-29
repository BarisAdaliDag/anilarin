import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/catalog.dart';
import '../../view_model/app_view_model.dart';
import '../widgets/book_mockup.dart';

/// Sepet. [embedded] true ise ana sayfa sekmesi olarak gösterilir.
class BasketScreen extends StatelessWidget {
  const BasketScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final catalog = app.catalog!;
    final items = app.basket;
    final body = items.isEmpty
        ? const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text(S.basketEmpty, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final item in items)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 96,
                        child: app.book(item.bookId) == null
                            ? const Icon(Icons.menu_book, size: 48)
                            : BookMockup(book: app.book(item.bookId)!, catalog: catalog),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            Text(
                              '${catalog.product(item.productCode).title} · ${S.pagesCount(item.pages)}',
                              style: TextStyle(color: context.mutedText, fontSize: 13),
                            ),
                            if (item.options.giftBox ||
                                item.options.layflat ||
                                item.options.foil != null ||
                                item.options.gloss)
                              Text(
                                [
                                  if (item.options.gloss) S.glossFinish,
                                  if (item.options.giftBox) S.giftBox,
                                  if (item.options.layflat) S.layflat,
                                  if (item.options.foil != null)
                                    '${S.foil} (${item.options.foil == 'gold' ? S.foilGold : S.foilSilver})',
                                ].join(' · '),
                                style: TextStyle(color: context.mutedText, fontSize: 12),
                              ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _QtyButton(icon: Icons.remove, onTap: () => app.setQuantity(item, item.quantity - 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                ),
                                _QtyButton(icon: Icons.add, onTap: () => app.setQuantity(item, item.quantity + 1)),
                                const Spacer(),
                                Text(
                                  formatPrice(app.itemPrice(item)),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );

    return Scaffold(
      appBar: AppBar(title: const Text(S.basketTitle), automaticallyImplyLeading: !embedded),
      body: body,
      bottomNavigationBar: items.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.sheetColor,
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                ),
                child: Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(S.total, style: TextStyle(color: context.mutedText, fontSize: 12)),
                        Text(
                          formatPrice(app.basketTotal),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(S.checkoutSoon))),
                        child: const Text(S.checkout),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: context.divider),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}
