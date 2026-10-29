import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../view_model/app_view_model.dart';
import '../basket/basket_screen.dart';
import 'account_tab.dart';
import 'designs_tab.dart';
import 'memories_tab.dart';

/// Alt sekmeli ana ekran (Popsa HomeActivity): Tasarımlar, Hatırlatıcılar, Anılar, Sepet, Hesap.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const designsTab = 0;
  static const basketTab = 3;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    if (app.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    Widget basketIcon(bool selected) => Badge(
          isLabelVisible: app.basketCount > 0,
          label: Text('${app.basketCount}'),
          backgroundColor: AppColors.failure,
          child: Icon(selected ? Icons.shopping_cart : Icons.shopping_cart_outlined),
        );
    return Scaffold(
      body: IndexedStack(
        index: app.tabIndex,
        children: const [DesignsTab(), _RemindersTab(), MemoriesTab(), BasketScreen(embedded: true), AccountTab()],
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: app.tabIndex,
        onDestinationSelected: app.setTab,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: S.tabDesigns,
          ),
          const NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: S.tabReminders,
          ),
          const NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: S.tabMemories,
          ),
          NavigationDestination(icon: basketIcon(false), selectedIcon: basketIcon(true), label: S.tabBasket),
          const NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: S.tabAccount,
          ),
        ],
      ),
    );
  }
}

class _RemindersTab extends StatelessWidget {
  const _RemindersTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 32), children: [
        const Text(S.tabReminders, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text(S.remindersBody, style: TextStyle(fontSize: 15, color: context.mutedText)),
        const SizedBox(height: 24),
        for (final (icon, title, date) in const [
          (Icons.cake_outlined, 'Doğum günü', 'Sevdiklerinin doğum günlerini ekle'),
          (Icons.favorite_border, 'Yıl dönümü', 'Özel günlerini unutma'),
          (Icons.celebration_outlined, 'Yılbaşı', '31 Aralık'),
        ])
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Icon(icon, color: AppColors.accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  Text(date, style: TextStyle(color: context.mutedText)),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}
