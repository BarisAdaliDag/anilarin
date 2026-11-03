import 'dart:math';

import 'package:intl/intl.dart';

import 'address.dart';
import 'basket_item.dart';

/// Verilmiş sipariş. Test sürümünde ödeme alınmaz; sipariş cihazda saklanır ve matbaaya gönderilir.
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

  /// Sipariş anındaki tasarımların kopyası (ürün kimliği → tasarım JSON'u).
  /// Tasarım sonradan değişse ya da silinse de gönderim bununla tamamlanır.
  final Map<String, Map<String, dynamic>> designs;

  const Order({
    required this.reference,
    required this.createdAtMs,
    required this.items,
    required this.address,
    required this.shippingId,
    required this.paymentMethod,
    required this.totalCents,
    this.uploaded = false,
    this.designs = const {},
  });

  /// Okunur sipariş numarası: `AN-20261103-K7Q2`.
  static String newReference(DateTime now, [Random? random]) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = random ?? Random.secure();
    final suffix = List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
    return 'AN-${DateFormat('yyyyMMdd').format(now)}-$suffix';
  }

  Order markUploaded() => Order(
    reference: reference,
    createdAtMs: createdAtMs,
    items: items,
    address: address,
    shippingId: shippingId,
    paymentMethod: paymentMethod,
    totalCents: totalCents,
    uploaded: true,
    designs: designs,
  );

  /// Tasarımlar hariç bilgiler (Firestore kaydı için).
  Map<String, dynamic> summaryJson() => {
    'ref': reference,
    'created': createdAtMs,
    'items': items.map((e) => e.toJson()).toList(),
    'address': address.toJson(),
    'shipping': shippingId,
    'payment': paymentMethod,
    'total': totalCents,
  };

  Map<String, dynamic> toJson() => {
    ...summaryJson(),
    if (uploaded) 'up': true,
    if (designs.isNotEmpty) 'designs': designs,
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
    designs: {
      for (final e in ((j['designs'] as Map?) ?? const {}).entries)
        e.key as String: Map<String, dynamic>.from(e.value as Map),
    },
  );
}
