import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/basket_item.dart';
import '../../models/order.dart';
import '../../models/photo_book.dart';
import '../../models/print_set.dart';
import '../../view_model/editor_view_model.dart';
import '../preview/preview_screen.dart';
import '../widgets/print_card.dart';
import '../../view_model/app_view_model.dart';
import '../checkout/checkout_screens.dart';
import '../../models/catalog.dart' show formatPrice;

/// Siparişlerim: gönderimi yarım kalan siparişler buradan tamamlanır.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<AppViewModel>().orders;
    return Scaffold(
      appBar: AppBar(title: const Text(S.myOrders)),
      body: orders.isEmpty
          ? Center(
              child: Text(S.ordersEmpty, style: TextStyle(color: context.mutedText)),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _OrderCard(order: orders[i]),
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMMM y, HH:mm', 'tr').format(DateTime.fromMillisecondsSinceEpoch(order.createdAtMs));
    final pending = !order.uploaded;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(order.reference, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
              Text(formatPrice(order.totalCents)),
            ],
          ),
          const SizedBox(height: 4),
          Text(date, style: TextStyle(color: context.mutedText)),
          const SizedBox(height: 6),
          // Sipariş edilen tasarımlar: dokununca siparişteki hâli açılır.
          for (final item in order.items)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: order.designs.containsKey(item.bookId) ? () => _openDesign(context, order, item) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(item.isPrints ? Icons.photo_library_outlined : Icons.menu_book_outlined, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${item.quantity}× ${item.title}')),
                    if (order.designs.containsKey(item.bookId)) Icon(Icons.chevron_right, color: context.mutedText),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                pending ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
                size: 18,
                color: pending ? AppColors.warning : AppColors.success,
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(pending ? S.statusPending : S.statusUploaded)),
              if (pending)
                FilledButton(
                  // Tema dolu düğmeyi tam genişlik yapar; satırda yazıyı harf harf sıkıştırıyordu.
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderUploadScreen(order: order))),
                  child: const Text(S.completeUpload),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sipariş edilen tasarım: siparişteki hâliyle önizleme ya da kopyasını taslaklara ekleme.
void _openDesign(BuildContext context, Order order, BasketItem item) {
  final app = context.read<AppViewModel>();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text(S.viewOrderedDesign),
            onTap: () {
              Navigator.pop(c);
              final json = order.designs[item.bookId]!;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => item.isPrints
                      ? _OrderedPrintsScreen(set: PrintSet.fromJson(json))
                      : ChangeNotifierProvider(
                          create: (_) => EditorViewModel(book: PhotoBook.fromJson(json), catalog: app.catalog!),
                          child: const PreviewScreen(readOnly: true),
                        ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text(S.copyOrderedDesign),
            subtitle: const Text(S.copyOrderedDesignBody),
            onTap: () async {
              Navigator.pop(c);
              final id = await app.copyOrderedDesign(order, item.bookId);
              if (id == null || !context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(S.copyOrderedDesignDone)));
            },
          ),
        ],
      ),
    ),
  );
}

/// Sipariş edilen baskı seti: baskılar alt alta, yalnız görüntüleme.
class _OrderedPrintsScreen extends StatelessWidget {
  const _OrderedPrintsScreen({required this.set});

  final PrintSet set;

  @override
  Widget build(BuildContext context) {
    final fonts = context.read<AppViewModel>().catalog!.textAppearances;
    return Scaffold(
      appBar: AppBar(title: Text(set.title.isEmpty ? S.photoPrints : set.title)),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(40, 8, 40, 32),
        itemCount: set.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 24),
        itemBuilder: (_, i) => PrintCard(set: set, index: i, fonts: fonts, thumbSize: 600),
      ),
    );
  }
}
