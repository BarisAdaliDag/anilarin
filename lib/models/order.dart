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

  /// Dosyalar matbaaya (Firebase) gönderildi mi?
  final bool uploaded;

  const Order({
    required this.reference,
    required this.createdAtMs,
    required this.items,
    required this.address,
    required this.shippingId,
    required this.paymentMethod,
    required this.totalCents,
    this.uploaded = false,
  });

  Order markUploaded() => Order(
    reference: reference,
    createdAtMs: createdAtMs,
    items: items,
    address: address,
    shippingId: shippingId,
    paymentMethod: paymentMethod,
    totalCents: totalCents,
    uploaded: true,
  );

  Map<String, dynamic> toJson() => {
    'ref': reference,
    'created': createdAtMs,
    'items': items.map((e) => e.toJson()).toList(),
    'address': address.toJson(),
    'shipping': shippingId,
    'payment': paymentMethod,
    'total': totalCents,
    if (uploaded) 'up': true,
  };

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    reference: j['ref'],
    createdAtMs: j['created'],
    items: (j['items'] as List).map((e) => BasketItem.fromJson(e)).toList(),
    address: Address.fromJson(j['address']),
    shippingId: j['shipping'],
    paymentMethod: j['payment'] ?? 'card',
    totalCents: j['total'],
    uploaded: j['up'] ?? false,
  );
}
