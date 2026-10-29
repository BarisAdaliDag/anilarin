import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/catalog.dart';
import '../../models/photo_book.dart';
import '../../view_model/app_view_model.dart';
import '../editor/editor_screen.dart';
import '../product/products_screen.dart';
import '../widgets/book_mockup.dart';

/// "Tasarımlarım" sekmesi (Popsa My Designs): her tasarım büyük bir kart, sağ altta "Oluştur".
class DesignsTab extends StatelessWidget {
  const DesignsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppViewModel>();
    final catalog = app.catalog!;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            const _Brand(),
            const SizedBox(height: 22),
            const Text(S.myDesigns, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(S.homeDescription, style: TextStyle(fontSize: 15, color: context.mutedText, height: 1.4)),
            const SizedBox(height: 24),
            for (final b in app.books) ...[
              _DesignCard(book: b, catalog: catalog),
              const SizedBox(height: 20),
            ],
            _SuggestionCard(onCreate: () => openProducts(context)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openProducts(context),
        backgroundColor: context.isDark ? Colors.white : AppColors.textStrong,
        foregroundColor: context.isDark ? AppColors.textStrong : Colors.white,
        shape: const StadiumBorder(),
        icon: const Icon(Icons.auto_stories_outlined),
        label: const Text(S.create, style: TextStyle(fontSize: 17)),
      ),
    );
  }
}

void openProducts(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductsScreen()));
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Icon(Icons.auto_awesome, size: 26),
      const SizedBox(width: 6),
      Text(S.appName, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: context.strongText)),
    ]);
  }
}

String timeAgo(int ms) {
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inMinutes < 1) return 'Az önce';
  if (d.inMinutes < 60) return '${d.inMinutes} dakika önce';
  if (d.inHours < 24) return '${d.inHours} saat önce';
  if (d.inDays < 30) return '${d.inDays} gün önce';
  return '${(d.inDays / 30).floor()} ay önce';
}

class _DesignCard extends StatelessWidget {
  const _DesignCard({required this.book, required this.catalog});

  final PhotoBook book;
  final Catalog catalog;

  @override
  Widget build(BuildContext context) {
    final cover = catalog.theme(book.cover.themeOverride ?? book.themeId);
    // Kart rengi kapak renginin koyulaştırılmışı (Popsa'da kartlar tasarımın rengini alır).
    final hsl = HSLColor.fromColor(cover.background);
    final cardColor = book.cover.themeOverride == null
        ? context.cardColor
        : hsl.withLightness((hsl.lightness * 0.6).clamp(0.12, 0.42)).toColor();
    final onCard = book.cover.themeOverride == null ? context.strongText : Colors.white;
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorScreen(bookId: book.id))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 12, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    S.photoBook.toUpperCase(),
                    style: TextStyle(fontSize: 12, letterSpacing: 1.6, color: onCard.withValues(alpha: 0.75)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.title.isEmpty ? S.photoBook : book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 20, color: onCard),
                  ),
                ]),
              ),
              IconButton(onPressed: () => _menu(context), icon: Icon(Icons.more_horiz, color: onCard)),
            ]),
            const SizedBox(height: 18),
            SizedBox(width: 210, child: BookMockup(book: book, catalog: catalog)),
            const SizedBox(height: 18),
            Text(timeAgo(book.updatedAtMs), style: TextStyle(color: onCard.withValues(alpha: 0.85))),
          ]),
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext context) async {
    final app = context.read<AppViewModel>();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Düzenle'),
            onTap: () => Navigator.pop(c, 'edit'),
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text(S.duplicateBook),
            onTap: () => Navigator.pop(c, 'duplicate'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.failure),
            title: const Text(S.deleteBook, style: TextStyle(color: AppColors.failure)),
            onTap: () => Navigator.pop(c, 'delete'),
          ),
        ]),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'edit':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorScreen(bookId: book.id)));
      case 'duplicate':
        await app.duplicateBook(book.id);
      case 'delete':
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
}

/// Popsa'nın sarı "My Life in 2026" öneri kartı.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 16, 18),
      decoration: BoxDecoration(color: const Color(0xFFC9A300), borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ÖNERİ', style: TextStyle(fontSize: 12, letterSpacing: 1.6, color: Colors.white70)),
        const SizedBox(height: 4),
        Text('$year Yılım', style: const TextStyle(fontSize: 20, color: Colors.white)),
        const SizedBox(height: 6),
        const Text(S.suggestionBody, style: TextStyle(color: Colors.white)),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFF8E1),
              foregroundColor: AppColors.textStrong,
              minimumSize: const Size(130, 48),
              shape: const StadiumBorder(),
            ),
            onPressed: onCreate,
            icon: const Icon(Icons.auto_stories_outlined),
            label: const Text(S.create),
          ),
        ),
      ]),
    );
  }
}
