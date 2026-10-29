import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/asset_paths.dart';
import '../../constants/strings_tr.dart';
import '../../models/catalog.dart';
import '../../models/photo_book.dart';
import '../../view_model/app_view_model.dart';
import '../editor/editor_screen.dart';
import '../product/product_detail_screen.dart';
import '../widgets/book_mockup.dart';
import '../widgets/promo_carousel.dart';
import '../widgets/ref_image.dart';

/// "Tasarımlarım" sekmesi: kayıtlı kitaplar + ürünler (Popsa'nın My Designs + Products Overview ekranı).
class DesignsTab extends StatelessWidget {
  const DesignsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final catalog = app.catalog!;
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  S.appName,
                  style: const TextStyle(
                    fontFamily: 'DMSerifDisplay',
                    fontSize: 22,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(S.myDesigns, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text(S.homeDescription, style: TextStyle(fontSize: 15, color: AppColors.text)),
              ]),
            ),
          ),
          SliverToBoxAdapter(child: _DesignsStrip(books: app.books, catalog: catalog)),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          const SliverToBoxAdapter(child: PromoCarousel()),
          const SliverToBoxAdapter(child: _SectionTitle(S.whatToCreate)),
          SliverToBoxAdapter(child: _PhotoBookHeroCard(catalog: catalog)),
          const SliverToBoxAdapter(child: _ComingSoonRow()),
          const SliverToBoxAdapter(child: _SectionTitle(S.createdByCommunity)),
          const SliverToBoxAdapter(child: _CommunityCarousel()),
          const SliverToBoxAdapter(child: _SectionTitle(S.aboutUs)),
          const SliverToBoxAdapter(child: _AboutCards()),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

void openPhotoBook(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductDetailScreen()));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
        child: Text(text, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
      );
}

class _DesignsStrip extends StatelessWidget {
  const _DesignsStrip({required this.books, required this.catalog});

  final List<PhotoBook> books;
  final Catalog catalog;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          _NewDesignCard(onTap: () => openPhotoBook(context)),
          for (final b in books) _DesignCard(book: b, catalog: catalog),
        ],
      ),
    );
  }
}

class _NewDesignCard extends StatelessWidget {
  const _NewDesignCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 150,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 1.5),
          ),
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.accent,
              child: Icon(Icons.add, color: Colors.white, size: 30),
            ),
            SizedBox(height: 12),
            Text(S.newDesign, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.accentDark)),
          ]),
        ),
      ),
    );
  }
}

class _DesignCard extends StatelessWidget {
  const _DesignCard({required this.book, required this.catalog});

  final PhotoBook book;
  final Catalog catalog;

  @override
  Widget build(BuildContext context) {
    final product = catalog.product(book.productCode);
    final date = DateFormat('d MMM y', 'tr').format(DateTime.fromMillisecondsSinceEpoch(book.updatedAtMs));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EditorScreen(bookId: book.id)),
        ),
        onLongPress: () => _menu(context),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Center(child: BookMockup(book: book, catalog: catalog))),
            const SizedBox(height: 8),
            Text(
              book.title.isEmpty ? S.photoBook : book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            Text(
              '${product.typeLabel} · ${S.pagesCount(book.pageCount)} · $date',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.text),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext context) async {
    final app = context.read<AppViewModel>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(S.deleteBook),
        content: const Text(S.deleteBookConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text(S.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text(S.delete, style: TextStyle(color: AppColors.failure)),
          ),
        ],
      ),
    );
    if (ok == true) await app.deleteBook(book.id);
  }
}

class _PhotoBookHeroCard extends StatelessWidget {
  const _PhotoBookHeroCard({required this.catalog});

  final Catalog catalog;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openPhotoBook(context),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const AspectRatio(aspectRatio: 1.5, child: RefImage(AssetPaths.heroPhotoBook)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text(S.photoBook, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${S.from} ${formatPrice(catalog.lowestPrice)}',
                      style: const TextStyle(color: AppColors.text),
                    ),
                  ]),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
                  onPressed: () => openPhotoBook(context),
                  child: const Text(S.create),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ComingSoonRow extends StatelessWidget {
  const _ComingSoonRow();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.photo_outlined, 'Baskılar'),
      (Icons.calendar_month_outlined, 'Takvim'),
      (Icons.inventory_2_outlined, 'Fotoğraf Kutusu'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(children: [
        for (final (icon, label) in items)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Icon(icon, color: Colors.black38),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const Text('Yakında', style: TextStyle(fontSize: 11, color: AppColors.text)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _CommunityCarousel extends StatelessWidget {
  const _CommunityCarousel();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: AssetPaths.community.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(width: 165, child: RefImage(AssetPaths.community[i], icon: Icons.menu_book_outlined)),
        ),
      ),
    );
  }
}

class _AboutCards extends StatelessWidget {
  const _AboutCards();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.auto_awesome, 'Akıllı tasarım', 'Fotoğraflarını tarih sırasına göre düzenler, en uygun şablonları seçeriz.'),
      (Icons.workspace_premium_outlined, 'Kaliteli baskı', 'Canlı renkler, kalın sayfalar ve dayanıklı cilt.'),
      (Icons.local_shipping_outlined, 'Hızlı teslimat', 'Siparişin birkaç iş günü içinde kapında.'),
    ];
    return Column(children: [
      for (final (icon, title, body) in items)
        Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(icon, color: AppColors.accent, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(color: AppColors.text)),
              ]),
            ),
          ]),
        ),
    ]);
  }
}
