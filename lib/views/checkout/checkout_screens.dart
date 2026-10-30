import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/address.dart';
import '../../models/catalog.dart';
import '../../models/order.dart';
import '../../view_model/app_view_model.dart';

/// Ödeme akışı (Popsa Checkout): Yeni Adres → Kargo Seçenekleri → Ödeme Seçenekleri → Özet → Teşekkürler.
/// Ödeme sistemi yok: ödeme düğmeleri ödeme alınmış gibi Özet'e, oradan Teşekkürler'e geçer.
void startCheckout(BuildContext context) {
  final app = context.read<AppViewModel>();
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => app.address == null ? const AddressScreen() : const ShippingOptionsScreen()),
  );
}

/// Liste altına sistem gezinme çubuğu kadar boşluk (kenardan kenara ekranda son düğme örtülmesin).
EdgeInsets _listPadding(BuildContext context, {double top = 8}) =>
    EdgeInsets.fromLTRB(20, top, 20, 32 + MediaQuery.viewPaddingOf(context).bottom);

// ---- Yeni Adres ----

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key, this.editing = false});

  /// Kargo ekranından "Değiştir" ile açıldıysa kaydedince oraya döner.
  final bool editing;

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _form = GlobalKey<FormState>();
  late final Address _a = Address.fromJson((context.read<AppViewModel>().address ?? Address()).toJson());

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();
    final nav = Navigator.of(context);
    await context.read<AppViewModel>().saveAddress(_a);
    if (widget.editing) {
      nav.pop();
    } else {
      nav.pushReplacement(MaterialPageRoute(builder: (_) => const ShippingOptionsScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget field(
      String label,
      String initial,
      void Function(String) onSaved, {
      bool optional = false,
      TextInputType? keyboard,
      String? hint,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          initialValue: initial,
          keyboardType: keyboard,
          textCapitalization: keyboard == null ? TextCapitalization.words : TextCapitalization.none,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          validator: (v) => !optional && (v == null || v.trim().isEmpty) ? S.required : null,
          onSaved: (v) => onSaved(v?.trim() ?? ''),
        ),
      );
    }

    Widget group(IconData icon, List<Widget> fields) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 16, right: 14), child: Icon(icon, size: 26)),
          Expanded(child: Column(children: fields)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: const Text(S.newAddress),
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
              onPressed: _save,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward, size: 20),
              label: Text(widget.editing ? S.save : S.shipping, style: const TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: _listPadding(context),
          children: [
            Text(S.addressSavedNote, style: TextStyle(fontSize: 16, height: 1.4, color: context.mutedText)),
            const SizedBox(height: 24),
            group(Icons.flag_outlined, [field(S.country, _a.country, (v) => _a.country = v)]),
            group(Icons.person_outline, [
              field(S.firstName, _a.firstName, (v) => _a.firstName = v, hint: 'Ali'),
              field(S.lastName, _a.lastName, (v) => _a.lastName = v, hint: 'Veli'),
            ]),
            group(Icons.location_on_outlined, [
              field(S.addressLine1, _a.line1, (v) => _a.line1 = v, hint: 'Sultan Ahmet'),
              field(S.addressLine2, _a.line2, (v) => _a.line2 = v, optional: true, hint: 'Atmeydanı Cd. No:7'),
              field(S.postCode, _a.postCode, (v) => _a.postCode = v, keyboard: TextInputType.number, hint: '34122'),
              field(S.district, _a.district, (v) => _a.district = v, hint: 'Fatih'),
              field(S.city, _a.city, (v) => _a.city = v, hint: 'İstanbul'),
            ]),
            group(Icons.phone_outlined, [
              field(S.phone, _a.phone, (v) => _a.phone = v, keyboard: TextInputType.phone, hint: '05xx xxx xx xx'),
            ]),
          ],
        ),
      ),
    );
  }
}

// ---- Kargo Seçenekleri ----

/// Popsa'daki gibi "13 Kas Cum – 19 Kas Per": sepetteki en uzun teslim süresine kargonun ek günleri eklenir.
String _deliveryRange(AppViewModel app, ShippingOption s) {
  final catalog = app.catalog!;
  final days = app.basket.map((i) => catalog.product(i.productCode).deliveryDays);
  final lo = days.isEmpty ? 11 : days.map((d) => d.first).reduce((a, b) => a > b ? a : b);
  final hi = days.isEmpty ? 16 : days.map((d) => d.last).reduce((a, b) => a > b ? a : b);
  final now = DateTime.now();
  final fmt = DateFormat('d MMM E', 'tr');
  return '${fmt.format(now.add(Duration(days: lo + s.extraDaysMin)))} – '
      '${fmt.format(now.add(Duration(days: hi + s.extraDaysMax)))}';
}

class ShippingOptionsScreen extends StatelessWidget {
  const ShippingOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: _listPadding(context, top: 4),
        children: [
          const Text(S.shippingOptions, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  S.shippingOptionsBody(app.address?.city ?? ''),
                  style: TextStyle(fontSize: 16, height: 1.45, color: context.mutedText),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                icon: const Icon(Icons.info_outline),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text(S.shippingOptions),
                    content: const Text(S.shippingInfo),
                    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text(S.ok))],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (app.address != null) _AddressTile(address: app.address!),
          const SizedBox(height: 20),
          for (final s in ShippingOption.all)
            _ShippingCard(
              icon: s == ShippingOption.tracked ? Icons.wifi_tethering : Icons.local_shipping_outlined,
              title: s == ShippingOption.tracked ? S.trackedShipping : S.standardShipping,
              dates: _deliveryRange(app, s),
              price: formatPrice(s.priceCents),
              onTap: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentOptionsScreen(shipping: s))),
            ),
        ],
      ),
    );
  }
}

/// Kargo ekranında kayıtlı teslimat adresi ve "Değiştir" (ilk hatalı girişi düzeltmek için).
class _AddressTile extends StatelessWidget {
  const _AddressTile({required this.address});

  final Address address;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
      decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(address.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                Text(
                  [address.line1, address.city].where((e) => e.isNotEmpty).join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: context.mutedText),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddressScreen(editing: true))),
            child: const Text(S.change),
          ),
        ],
      ),
    );
  }
}

class _ShippingCard extends StatelessWidget {
  const _ShippingCard({
    required this.icon,
    required this.title,
    required this.dates,
    required this.price,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String dates;
  final String price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 28),
                    const SizedBox(width: 16),
                    Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 22),
                Text(S.estDelivery, style: TextStyle(fontSize: 13, letterSpacing: 1.4, color: context.mutedText)),
                const SizedBox(height: 6),
                Text(dates, style: const TextStyle(fontSize: 17)),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Ödeme Seçenekleri ----

class PaymentOptionsScreen extends StatelessWidget {
  const PaymentOptionsScreen({super.key, required this.shipping});

  final ShippingOption shipping;

  @override
  Widget build(BuildContext context) {
    // Ödeme sistemi yok: seçilen yöntemle ödeme alınmış sayılır, özete geçilir.
    void pay(String method) => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderSummaryScreen(shipping: shipping, paymentMethod: method),
      ),
    );
    final body = TextStyle(fontSize: 16, height: 1.45, color: context.mutedText);
    return Scaffold(
      appBar: AppBar(title: const Text(S.paymentOptions)),
      body: ListView(
        padding: _listPadding(context, top: 12),
        children: [
          SizedBox(
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF3C4043),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => pay('gpay'),
              child: const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'G',
                      style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: ' Pay'),
                  ],
                ),
                style: TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => pay('card'),
              child: const Text(S.cardPayment, style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 48),
          const Icon(Icons.lock_outline, size: 44),
          const SizedBox(height: 16),
          const Text(
            S.securePayments,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Text(S.securePaymentsBody, textAlign: TextAlign.center, style: body),
          const SizedBox(height: 14),
          Text(S.orderRefByEmail, textAlign: TextAlign.center, style: body),
          const SizedBox(height: 22),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 10,
            children: [
              _CardBadge(color: Color(0xFF1A1F71), child: _BadgeText('VISA', italic: true)),
              _CardBadge(color: Color(0xFF2B2B2B), child: _MastercardMark()),
              _CardBadge(color: Color(0xFF2E77BC), child: _BadgeText('AMEX')),
              _CardBadge(color: Color(0xFF4A4A4A), child: _BadgeText('UnionPay', size: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---- Özet ----

String _shippingTitle(ShippingOption s) => s == ShippingOption.tracked ? S.trackedShipping : S.standardShipping;

class OrderSummaryScreen extends StatefulWidget {
  const OrderSummaryScreen({super.key, required this.shipping, required this.paymentMethod});

  final ShippingOption shipping;
  final String paymentMethod;

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  bool _placing = false;

  Future<void> _confirm() async {
    setState(() => _placing = true);
    final nav = Navigator.of(context);
    final order = await context.read<AppViewModel>().placeOrder(widget.shipping, widget.paymentMethod);
    nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => ThankYouScreen(order: order)), (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final catalog = app.catalog!;
    final s = widget.shipping;
    final muted = TextStyle(fontSize: 15, color: context.mutedText);
    return Scaffold(
      appBar: AppBar(title: const Text(S.summary)),
      body: ListView(
        padding: _listPadding(context),
        children: [
          Text(S.orderSummaryBody, style: TextStyle(fontSize: 16, height: 1.4, color: context.mutedText)),
          const SizedBox(height: 24),
          _Section(
            title: S.deliverTo,
            icon: Icons.location_on_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final l in app.address?.lines ?? const <String>[]) Text(l, style: muted)],
            ),
          ),
          _Section(
            title: S.shippingMethod,
            icon: s == ShippingOption.tracked ? Icons.wifi_tethering : Icons.local_shipping_outlined,
            child: Text('${_shippingTitle(s)} · ${_deliveryRange(app, s)}', style: muted),
          ),
          _Section(
            title: S.items,
            icon: Icons.menu_book_outlined,
            child: Column(
              children: [
                for (final item in app.basket)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.quantity}× ${item.title}\n'
                            '${catalog.product(item.productCode).title} (${catalog.product(item.productCode).sizeLabel})',
                            style: muted,
                          ),
                        ),
                        Text(formatPrice(app.itemPrice(item)), style: muted),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          _Section(
            title: S.payWith,
            icon: widget.paymentMethod == 'gpay' ? Icons.account_balance_wallet_outlined : Icons.credit_card,
            child: Text(widget.paymentMethod == 'gpay' ? 'Google Pay' : S.cardPayment, style: muted),
          ),
          Divider(height: 32, color: context.divider),
          _AmountRow(S.discounts, '-${formatPrice(app.basketDiscount)}'),
          _AmountRow(S.shipping, formatPrice(s.priceCents)),
          _AmountRow(S.total, formatPrice(app.basketTotal + s.priceCents), strong: true),
          Align(
            alignment: Alignment.centerRight,
            child: Text(S.vatIncluded, style: TextStyle(fontSize: 13, color: context.mutedText)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: _placing || app.basket.isEmpty ? null : _confirm,
              child: const Text(S.confirmOrder, style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: strong ? 19 : 17, fontWeight: strong ? FontWeight.w600 : FontWeight.w400);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

// ---- Teşekkürler ----

class ThankYouScreen extends StatelessWidget {
  const ThankYouScreen({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (_, v, child) => Transform.scale(scale: v, alignment: Alignment.centerLeft, child: child),
                child: const Icon(Icons.check_circle, size: 76, color: AppColors.accent),
              ),
              const SizedBox(height: 24),
              const Text(S.thankYou, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text(S.thankYouBody, style: TextStyle(fontSize: 17, height: 1.45, color: context.mutedText)),
              const SizedBox(height: 28),
              Text(S.orderReference, style: TextStyle(fontSize: 14, color: context.mutedText)),
              const SizedBox(height: 4),
              SelectableText(order.reference, style: const TextStyle(fontSize: 24, letterSpacing: 1)),
              const SizedBox(height: 8),
              Text('${S.total}: ${formatPrice(order.totalCents)}', style: TextStyle(color: context.mutedText)),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () {
                    context.read<AppViewModel>().setTab(0);
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  child: const Text(S.backToDesigns, style: TextStyle(fontSize: 17)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kabul edilen kart türleri için basit rozet (logo dosyası yok).
class _CardBadge extends StatelessWidget {
  const _CardBadge({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: child,
    );
  }
}

class _BadgeText extends StatelessWidget {
  const _BadgeText(this.text, {this.italic = false, this.size = 16});

  final String text;
  final bool italic;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: Colors.white,
      fontSize: size,
      fontWeight: FontWeight.w800,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    ),
  );
}

class _MastercardMark extends StatelessWidget {
  const _MastercardMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 40,
      height: 26,
      child: Stack(
        children: [
          Positioned(left: 0, child: CircleAvatar(radius: 13, backgroundColor: Color(0xFFEB001B))),
          Positioned(right: 0, child: CircleAvatar(radius: 13, backgroundColor: Color(0xCCF79E1B))),
        ],
      ),
    );
  }
}
