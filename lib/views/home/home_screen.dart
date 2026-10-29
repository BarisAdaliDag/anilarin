import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../view_model/app_view_model.dart';
import '../basket/basket_screen.dart';
import 'account_tab.dart';
import 'designs_tab.dart';
import 'memories_tab.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    if (app.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: IndexedStack(
        index: app.tabIndex,
        children: const [MemoriesTab(), DesignsTab(), BasketScreen(embedded: true), AccountTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: app.tabIndex,
        onDestinationSelected: app.setTab,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.accent.withValues(alpha: 0.12),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome, color: AppColors.accent),
            label: S.tabMemories,
          ),
          const NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library, color: AppColors.accent),
            label: S.tabDesigns,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: app.basketCount > 0,
              label: Text('${app.basketCount}'),
              backgroundColor: AppColors.failure,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: app.basketCount > 0,
              label: Text('${app.basketCount}'),
              backgroundColor: AppColors.failure,
              child: const Icon(Icons.shopping_bag, color: AppColors.accent),
            ),
            label: S.tabBasket,
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.accent),
            label: S.tabAccount,
          ),
        ],
      ),
    );
  }
}
