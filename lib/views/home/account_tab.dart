import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.receipt_long_outlined, 'Siparişlerim'),
      (Icons.location_on_outlined, 'Adreslerim'),
      (Icons.language, 'Dil ve Ülke'),
      (Icons.help_outline, 'Yardım ve Destek'),
      (Icons.info_outline, 'Hakkında'),
    ];
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: [
        const Text(S.accountTitle, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),
        for (final (icon, label) in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon, color: context.mutedText),
            title: Text(label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Bu bölüm test sürümünde yok.'))),
          ),
      ]),
    );
  }
}
