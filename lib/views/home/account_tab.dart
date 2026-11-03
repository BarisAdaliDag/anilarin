import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../services/auth_service.dart';
import '../auth/auth_screens.dart';
import '../order/orders_screen.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    const soon = [
      (Icons.location_on_outlined, 'Adreslerim'),
      (Icons.language, 'Dil ve Ülke'),
      (Icons.help_outline, 'Yardım ve Destek'),
      (Icons.info_outline, 'Hakkında'),
    ];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text(S.accountTitle, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          if (auth.available)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(14)),
              child: auth.signedIn
                  ? ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.account_circle, size: 40),
                      title: Text(auth.profile?.fullName ?? auth.email ?? ''),
                      subtitle: Text(auth.email ?? ''),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => open(const ProfileScreen()),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(S.accountGuestBody, style: TextStyle(color: context.mutedText)),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: () => ensureSignedIn(context), child: const Text(S.signInOrRegister)),
                      ],
                    ),
            ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.receipt_long_outlined, color: context.mutedText),
            title: const Text(S.myOrders),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const OrdersScreen()),
          ),
          for (final (icon, label) in soon)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon, color: context.mutedText),
              title: Text(label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Bu bölüm test sürümünde yok.'))),
            ),
        ],
      ),
    );
  }
}
