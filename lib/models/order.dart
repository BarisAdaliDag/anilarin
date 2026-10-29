import 'address.dart';
import 'basket_item.dart';

/// Verilmiş sipariş. Test sürümünde ödeme alınmaz; sipariş yalnız cihazda saklanır.
class Order {
  final String reference;
  final int createdAtMs;
  final List<BasketItem> items;
  final Address address;
  final String shippingId;
  final String paymentMethod; // gpay | card
  final int totalCents;

  const Order({
    required this.reference,
    required this.createdAtMs,
    required this.items,
    required this.address,
    required this.shippingId,
    required this.paymentMethod,
    required this.totalCents,
  });

  Map<String, dynamic> toJson() => {
    'ref': reference,
    'created': createdAtMs,
    'items': items.map((e) => e.toJson()).toList(),
    'address': address.toJson(),
    'shipping': shippingId,
    'payment': paymentMethod,
    'total': totalCents,
  };

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    reference: j['ref'],
    createdAtMs: j['created'],
    items: (j['items'] as List).map((e) => BasketItem.fromJson(e)).toList(),
    address: Address.fromJson(j['address']),
    shippingId: j['shipping'],
    paymentMethod: j['payment'] ?? 'card',
    totalCents: j['total'],
  );
}
