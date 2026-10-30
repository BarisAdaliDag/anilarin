import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/asset_paths.dart';
import '../../constants/strings_tr.dart';
import '../../view_model/app_view_model.dart';
import '../widgets/price_text.dart';
import '../widgets/ref_image.dart';
import '../../models/catalog.dart';
import '../../models/print_set.dart';
import '../prints/print_screens.dart';
import 'photo_books_screen.dart';

/// "Bugün ne oluşturmak istersin?" (Popsa ProductsOverviewActivity).
class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<AppViewModel>().catalog!;
    void openBooks() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PhotoBooksScreen()));
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          const Text(S.whatToCreate, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500, height: 1.25)),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: openBooks,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const RefImage(AssetPaths.heroPhotoBook),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [Color(0xAA0E1A2B), Color(0x000E1A2B)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            S.photoBooks,
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          const Text(S.from, style: TextStyle(color: Colors.white, fontSize: 14)),
                          DefaultTextStyle.merge(
                            style: const TextStyle(color: Colors.white),
                            child: Theme(
                              data: Theme.of(context).copyWith(brightness: Brightness.dark),
                              child: PriceText(
                                price: catalog.lowestPrice,
                                compareAt: catalog.lowestCompareAt,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 20,
                      bottom: 20,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xCC1E1E1E),
                          minimumSize: const Size(96, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: openBooks,
                        child: const Text(S.create),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.78,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PhotoPrintsScreen())),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          width: double.infinity,
                          child: RefImage(AssetPaths.productPrints, icon: Icons.photo_library_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(S.photoPrints, style: TextStyle(fontWeight: FontWeight.w600)),
                    Row(
                      children: [
                        Text('${S.from} ', style: TextStyle(color: context.mutedText)),
                        Text(
                          formatPrice(PrintCatalog.all.map((p) => p.headlineCents).reduce((a, b) => a < b ? a : b)),
                          style: TextStyle(color: context.mutedText),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              for (final (icon, label) in const [
                (Icons.calendar_month_outlined, 'Fotoğraf Takvimi'),
                (Icons.park_outlined, 'Yılbaşı Süsü'),
                (Icons.grid_view, 'Fotoğraf Karoları'),
                (Icons.inventory_2_outlined, 'Fotoğraf Kutusu'),
              ])
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(18)),
                        child: Icon(icon, size: 44, color: context.mutedText),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('Yakında', style: TextStyle(color: context.mutedText)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(S.aboutUs, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          for (final (icon, title, body) in const [
            (
              Icons.eco_outlined,
              'Çevreye Duyarlı',
              'Biyolojik olarak parçalanabilen ve geri dönüştürülebilir kâğıt, kapak ve mürekkep.',
            ),
            (
              Icons.thumb_up_alt_outlined,
              'Kalite Garantisi',
              'Üründen memnun kalmazsan düzeltiriz ya da paranı iade ederiz.',
            ),
            (
              Icons.auto_awesome,
              'Akıllı Tasarım',
              'Fotoğraflarını tarih sırasına göre dizer, en uygun şablonları seçeriz.',
            ),
          ])
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      ),
                      CircleAvatar(
                        backgroundColor: AppColors.accent,
                        child: Icon(icon, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(body, style: TextStyle(color: context.mutedText, height: 1.4)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
