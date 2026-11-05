import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../view_model/app_view_model.dart';
import '../../services/firebase_order_backend.dart';
import '../basket/basket_screen.dart';
import '../order/orders_screen.dart';
import 'account_tab.dart';
import 'designs_tab.dart';
import '../product/products_screen.dart';

/// Alt sekmeli ana ekran: Mağaza (ürünler), Tasarımlarım (taslaklar), Sepet, Hesap.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const shopTab = 0;
  static const designsTab = 1;
  static const basketTab = 2;
  static const accountTab = 3;

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
    final drafts = app.draftCount;
    Widget draftsIcon(bool selected) => Badge(
      isLabelVisible: drafts > 0,
      label: Text('$drafts'),
      backgroundColor: AppColors.warning,
      child: Icon(selected ? Icons.menu_book : Icons.menu_book_outlined),
    );
    return Scaffold(
      body: IndexedStack(
        index: app.tabIndex,
        children: const [ProductsScreen(embedded: true), DesignsTab(), BasketScreen(embedded: true), AccountTab()],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (FirebaseSetup.available && app.orders.any((o) => !o.uploaded))
            Material(
              color: context.cardColor,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.cloud_upload_outlined, color: AppColors.warning),
                title: const Text(S.pendingUploadBanner),
                trailing: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrdersScreen())),
                  child: const Text(S.complete),
                ),
              ),
            ),
          NavigationBar(
            height: 72,
            selectedIndex: app.tabIndex,
            onDestinationSelected: app.setTab,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront),
                label: S.tabShop,
              ),
              NavigationDestination(icon: draftsIcon(false), selectedIcon: draftsIcon(true), label: S.tabDesigns),
              NavigationDestination(icon: basketIcon(false), selectedIcon: basketIcon(true), label: S.tabBasket),
              const NavigationDestination(
                icon: Icon(Icons.account_circle_outlined),
                selectedIcon: Icon(Icons.account_circle),
                label: S.tabAccount,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
