import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/order.dart';
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
          for (final item in order.items)
            Text('${item.quantity}× ${item.title}', style: TextStyle(color: context.mutedText)),
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
