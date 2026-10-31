import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/catalog.dart';
import '../../models/photo_book.dart';
import '../../models/print_set.dart';
import '../../services/auto_layout_service.dart';
import '../../view_model/app_view_model.dart';
import '../basket/basket_screen.dart';
import '../home/designs_tab.dart' show timeAgo;
import '../editor/sheets/font_sheet.dart';
import '../editor/text_editor_screen.dart';
import '../photo_picker/photo_picker_screen.dart';
import '../widgets/media_carousel.dart';
import '../widgets/price_text.dart';
import '../widgets/print_card.dart';
import '../widgets/ref_image.dart';
import 'print_edit_photo_screen.dart';
import 'print_order_details.dart';
import 'print_theme_sheet.dart';

const _printImages = {'regular': 'assets/ref/media/prints_regular.png', 'square': 'assets/ref/media/prints_square.png'};

/// Ürün sayfası karuseli: Popsa'dan alınan boyut başına görseller, ardından ücretsiz (Unsplash) alternatifler.
/// Hepsi assets/ref/media altında, repoya girmez.
const _carouselCount = {
  'regular_small': 3,
  'regular_medium': 4,
  'regular_large': 5,
  'regular_xlarge': 3,
  'square_small': 5,
  'square_medium': 4,
  'square_large': 5,
};

List<String> printMedia(String format, String size) {
  final n = _carouselCount['${format}_$size'] ?? 0;
  final key = size == 'xlarge' ? 'xl' : size;
  return [
    for (var i = 1; i <= n; i++) 'assets/ref/media/prints_${format}_${key}_$i.jpg',
    for (var i = 1; i <= 7; i++) 'assets/ref/media/free/free_prints_$i.jpg',
  ];
}

// ---- Fotoğraf Baskıları: Normal / Kare ----

class PhotoPrintsScreen extends StatelessWidget {
  const PhotoPrintsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.photoPrints)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text(S.photoPrintsBody, style: TextStyle(fontSize: 16, height: 1.5, color: context.mutedText)),
          const SizedBox(height: 24),
          for (final format in const ['regular', 'square']) _FormatCard(format: format),
        ],
      ),
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({required this.format});

  final String format;

  @override
  Widget build(BuildContext context) {
    final products = PrintCatalog.ofFormat(format);
    final cheapest = products.reduce((a, b) => a.headlineCents <= b.headlineCents ? a : b);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Material(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => PrintProductScreen(format: format))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (format == 'regular')
                  const Text(S.mostPopular, style: TextStyle(color: AppColors.accent, fontSize: 14)),
                Text(
                  format == 'regular' ? S.regularPrints : S.squarePrints,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                const Text(S.fromUpper, style: TextStyle(fontSize: 12, letterSpacing: 1.2)),
                PriceText(price: cheapest.headlineCents, compareAt: cheapest.listCents, size: 18),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 230,
                    child: AspectRatio(
                      aspectRatio: format == 'regular' ? 1.27 : 1.45,
                      child: RefImage(_printImages[format]!, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Ürün sayfası ----

class PrintProductScreen extends StatefulWidget {
  const PrintProductScreen({super.key, required this.format});

  final String format;

  @override
  State<PrintProductScreen> createState() => _PrintProductScreenState();
}

class _PrintProductScreenState extends State<PrintProductScreen> {
  late final List<PrintProduct> _sizes = PrintCatalog.ofFormat(widget.format);
  late PrintProduct _product = _sizes.firstWhere((p) => p.size == 'medium', orElse: () => _sizes.first);
  bool _inches = false;

  Future<void> _next() async {
    final tier = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (c) => _TierSheet(product: _product),
    );
    if (tier == null || !mounted) return;
    final photos = await Navigator.of(context).push<List<BookPhoto>>(
      MaterialPageRoute(
        builder: (_) => PhotoPickerScreen(maxPhotos: PrintProduct.maxPrints, minPhotos: tier),
      ),
    );
    if (photos == null || photos.isEmpty || !mounted) return;
    final sorted = AutoLayoutService.sortPhotos(photos);
    final suggestions = AutoLayoutService.titleSuggestions(sorted);
    final set = PrintSet(
      id: const Uuid().v4(),
      title: suggestions.isEmpty ? S.printTitleDefault : suggestions.first,
      subtitle: AutoLayoutService.dateRangeLabel(sorted),
      productCode: _product.code,
      coverLayout: CoverLayout.photoOnly.index, // Popsa'da kapak ilk açılışta yazısız
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      items: [for (final p in sorted) PrintItem(id: const Uuid().v4(), photo: p)],
    );
    final app = context.read<AppViewModel>();
    final nav = Navigator.of(context);
    await app.savePrintSet(set);
    nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => PrintSetScreen(setId: set.id)), (r) => r.isFirst);
  }

  String _range(int a, int b) {
    final now = DateTime.now();
    final fmt = DateFormat('d MMMM', 'tr');
    return '${fmt.format(now.add(Duration(days: a)))} – ${fmt.format(now.add(Duration(days: b)))}';
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    final regular = widget.format == 'regular';
    Widget spec(IconData icon, String title, [String? sub]) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                if (sub != null) Text(sub, style: TextStyle(fontSize: 14, height: 1.4, color: context.mutedText)),
              ],
            ),
          ),
        ],
      ),
    );
    Widget title(String t) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 14),
      child: Text(t, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
    );
    return Scaffold(
      appBar: AppBar(
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
              onPressed: _next,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward, size: 20),
              label: const Text(S.next, style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: 32 + MediaQuery.viewPaddingOf(context).bottom),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  regular ? S.regularPrints : S.squarePrints,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Text(
                  regular ? S.regularPrintsBody : S.squarePrintsBody,
                  style: TextStyle(fontSize: 16, height: 1.5, color: context.mutedText),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: context.pillColor, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      for (final s in _sizes)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _product = s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: s == p ? (context.isDark ? AppColors.darkBackground : Colors.white) : null,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(S.sizeName(s.size), style: const TextStyle(fontSize: 15)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    PriceText(price: p.headlineCents, compareAt: p.listCents, size: 22),
                    const SizedBox(width: 8),
                    const Text(S.perPrint, style: TextStyle(fontSize: 18)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          MediaCarousel(media: printMedia(widget.format, p.size)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title(S.printSpecs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: spec(
                        Icons.straighten,
                        p.dimensions(inches: _inches),
                        _inches ? p.dimensions() : p.dimensions(inches: true),
                      ),
                    ),
                    TextButton(onPressed: () => setState(() => _inches = !_inches), child: Text(_inches ? 'cm' : 'in')),
                  ],
                ),
                spec(Icons.auto_awesome_outlined, S.glossFinishSpec, S.matteAvailable),
                spec(Icons.layers_outlined, S.gsmPaper),
                spec(
                  Icons.photo_library_outlined,
                  S.minMaxPrints(PrintProduct.minPrints, PrintProduct.maxPrints),
                  S.addUpTo(PrintProduct.maxPrints),
                ),
                spec(p.square ? Icons.crop_square : Icons.crop_landscape, p.square ? S.square : S.landscape),
                title(S.delivery),
                spec(
                  Icons.local_shipping_outlined,
                  S.standardShipping,
                  'Bugün sipariş ver, ${_range(7, 10)} arasında teslim al',
                ),
                spec(Icons.track_changes, S.trackedShipping, 'Bugün sipariş ver, ${_range(5, 8)} arasında teslim al'),
                title(S.moreInfo),
                spec(
                  Icons.thumb_up_alt_outlined,
                  'Kalite Garantisi',
                  'Üründen memnun kalmazsan bize ulaş; düzeltemezsek tam iade ederiz.',
                ),
                spec(
                  Icons.eco_outlined,
                  'Çevreye Duyarlı',
                  'Yalnızca biyolojik olarak parçalanabilen ve geri dönüştürülebilir kâğıt ve mürekkep kullanırız.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Bir seçenek seç": daha büyük pakette giderek artan indirim (Popsa loose_prints_offers).
class _TierSheet extends StatelessWidget {
  const _TierSheet({required this.product});

  final PrintProduct product;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.sheetColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewPaddingOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: context.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 22),
            const Text(S.selectOption, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Text(S.selectOptionBody, style: TextStyle(fontSize: 16, height: 1.4, color: context.mutedText)),
            const SizedBox(height: 20),
            for (final (min, percent) in PrintProduct.tiers)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context, min),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                      child: Row(
                        children: [
                          Expanded(child: Text(S.photosPlus(min), style: const TextStyle(fontSize: 19))),
                          if (percent > 0)
                            Container(
                              margin: const EdgeInsets.only(right: 14),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF0A5C),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '-%$percent',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                            ),
                          Text(
                            formatPrice(PrintProduct.unitCents(product.listCents, min)),
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---- Baskı seti editörü ----

class PrintSetScreen extends StatefulWidget {
  const PrintSetScreen({super.key, required this.setId});

  final String setId;

  @override
  State<PrintSetScreen> createState() => _PrintSetScreenState();
}

class _PrintSetScreenState extends State<PrintSetScreen> {
  late final PrintSet _set = context.read<AppViewModel>().printSet(widget.setId)!.clone();

  AppViewModel get _app => context.read<AppViewModel>();

  void _changed(VoidCallback change) {
    setState(change);
    _app.savePrintSet(_set);
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _next() async {
    if (_set.count < PrintProduct.minPrints) {
      _toast(S.minPrintsWarning(PrintProduct.minPrints));
      return;
    }
    await showPrintOrderDetails(context, _set, onChanged: () => _changed(() {}));
    if (mounted) setState(() {});
  }

  Future<void> _addMore() async {
    final room = PrintProduct.maxPrints - _set.count;
    if (room <= 0) return _toast(S.maxPrintsWarning(PrintProduct.maxPrints));
    final photos = await Navigator.of(
      context,
    ).push<List<BookPhoto>>(MaterialPageRoute(builder: (_) => PhotoPickerScreen(maxPhotos: room)));
    if (photos == null || photos.isEmpty) return;
    _changed(() {
      for (final p in photos) {
        _set.items.add(PrintItem(id: const Uuid().v4(), photo: p));
      }
    });
  }

  void _remove(int i) {
    if (_set.count <= PrintProduct.minPrints) return _toast(S.minPrintsWarning(PrintProduct.minPrints));
    _changed(() => _set.items.removeAt(i));
  }

  void _duplicate(int i) {
    if (_set.count >= PrintProduct.maxPrints) return _toast(S.maxPrintsWarning(PrintProduct.maxPrints));
    _changed(() => _set.items.insert(i + 1, _set.items[i].copyWith(id: const Uuid().v4())));
  }

  List<TextAppearance> get _fonts => _app.catalog!.textAppearances;

  /// Popsa Edit Title: fotoğraf kitabındaki tam ekran yazı düzenleyici (başlık + alt başlık, yazı tipi, hizalama).
  Future<void> _editTitle() async {
    final result = await Navigator.of(context).push<TextEditValue>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TextEditorScreen(
          title: S.editPrintTitle,
          initial: TextEditValue(
            text: _set.title,
            subtitle: _set.subtitle,
            align: _set.titleAlign,
            fontId: _set.titleFontId,
          ),
          fonts: _fonts,
          bookFontId: _set.fontId,
          limit: 36,
          hint: S.printTitleDefault,
          showStyle: false,
        ),
      ),
    );
    if (result == null) return;
    _changed(() {
      _set
        ..title = result.text
            .trim() // boş bırakılırsa kapakta yazı olmaz
        ..subtitle = (result.subtitle ?? '').trim()
        ..titleAlign = result.align
        ..titleFontId = result.fontId;
    });
  }

  /// Popsa Add Caption: baskının altındaki yazı, aynı tam ekran düzenleyiciyle.
  Future<void> _editCaption(int i) async {
    final item = _set.items[i];
    final result = await Navigator.of(context).push<TextEditValue>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TextEditorScreen(
          title: item.caption.isEmpty ? S.addCaption : S.editCaptionPrint,
          initial: TextEditValue(text: item.caption, align: item.align, fontId: item.fontId),
          fonts: _fonts,
          bookFontId: _set.fontId,
          limit: 90,
          hint: S.captionHintPrint,
          showStyle: false,
        ),
      ),
    );
    if (result == null) return;
    _changed(() {
      item
        ..caption = result.text.trim()
        ..align = result.align
        ..fontId = result.fontId;
    });
  }

  /// Popsa Change Font: tüm baskıların yazı tipi (özel seçimler temizlenir).
  Future<void> _changeFont() async {
    final id = await pickFont(context, fonts: _fonts, selectedId: _set.fontId);
    if (id == null) return;
    _changed(() {
      _set
        ..fontId = id
        ..titleFontId = null;
      for (final i in _set.items) {
        i.fontId = null;
      }
    });
  }

  /// Popsa Templates (kapak baskısı): düzen seçimi.
  Future<void> _coverTemplates() async {
    final picked = await Navigator.of(context).push<CoverLayout>(
      MaterialPageRoute(
        builder: (_) => CoverTemplateScreen(set: _set, fonts: _fonts),
      ),
    );
    if (picked != null) _changed(() => _set.coverLayout = picked.index);
  }

  Future<void> _removePrints() async {
    final removed = await Navigator.of(context).push<Set<int>>(
      MaterialPageRoute(
        builder: (_) => RemovePrintsScreen(set: _set, fonts: _fonts),
      ),
    );
    if (removed == null || removed.isEmpty) return;
    _changed(() {
      final ids = {for (final i in removed) _set.items[i].id};
      _set.items.removeWhere((e) => ids.contains(e.id));
    });
  }

  /// Popsa Themes: [index] verilirse o baskı kapsamında açılır, yoksa "Tüm baskılar".
  void _themes([int? index]) => showPrintThemeSheet(context, set: _set, index: index, onChanged: () => _changed(() {}));

  Future<void> _editPhoto(int i) async {
    final item = _set.items[i];
    final result = await Navigator.of(context).push<PrintEditResult>(
      MaterialPageRoute(
        builder: (_) =>
            PrintEditPhotoScreen(photo: item.photo, slot: item.slot, frameAspect: PrintCard.photoAreaAspect(_set, i)),
      ),
    );
    if (result == null) return;
    if (result.removed) return _remove(i);
    _changed(() {
      if (result.photo != null) item.photo = result.photo!;
      if (result.slot != null) item.applySlot(result.slot!);
    });
  }

  void _options() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) {
        Widget tile(IconData icon, String label, VoidCallback onTap, {bool danger = false}) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: Icon(icon, color: danger ? AppColors.failure : null),
          title: Text(label, style: TextStyle(fontSize: 17, color: danger ? AppColors.failure : null)),
          onTap: () {
            Navigator.pop(c);
            onTap();
          },
        );
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Text(
                    _set.title.isEmpty ? S.printTitleDefault : _set.title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    _set.product.square ? S.squarePrints : S.regularPrints,
                    style: TextStyle(fontSize: 17, color: c.mutedText),
                  ),
                ),
                Divider(color: c.divider, indent: 20, endIndent: 20),
                tile(Icons.edit_outlined, S.editPrintTitle, _editTitle),
                tile(Icons.text_fields, S.changeFont, _changeFont),
                tile(Icons.add_photo_alternate_outlined, S.addMorePrints, _addMore),
                tile(Icons.remove_circle_outline, S.removePrints, _removePrints),
                tile(Icons.copy_outlined, S.duplicateSet, () async {
                  final copy = await _app.duplicatePrintSet(_set.id);
                  if (copy != null && mounted) {
                    Navigator.of(
                      context,
                    ).pushReplacement(MaterialPageRoute(builder: (_) => PrintSetScreen(setId: copy.id)));
                  }
                }),
                tile(Icons.delete_outline, S.deleteSet, () async {
                  final nav = Navigator.of(context);
                  await _app.deletePrintSet(_set.id);
                  nav.pop();
                }, danger: true),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _round(IconData? icon, VoidCallback onTap, {Widget? child}) => Material(
    color: context.pillColor,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(width: 44, height: 44, child: Center(child: child ?? Icon(icon, size: 22))),
    ),
  );

  /// Baskıyı yatay ↔ dikey çevirir; fotoğraf yeni çerçeveyi ortadan doldurur.
  void _toggleOrientation(int i) => _changed(() {
    _set.items[i]
      ..portrait = !_set.items[i].portrait
      ..dx = 0
      ..dy = 0;
  });

  void _printMenu(int i) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_set.product.square)
              ListTile(
                leading: Icon(_set.items[i].portrait ? Icons.crop_landscape : Icons.crop_portrait),
                title: Text(_set.items[i].portrait ? S.makeLandscape : S.makePortrait),
                onTap: () {
                  Navigator.pop(c);
                  _toggleOrientation(i);
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text(S.duplicatePrint),
              onTap: () {
                Navigator.pop(c);
                _duplicate(i);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text(S.removePrint),
              onTap: () {
                Navigator.pop(c);
                _remove(i);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppViewModel>();
    final product = _set.product;
    return Scaffold(
      appBar: AppBar(
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
              onPressed: _next,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward, size: 20),
              label: const Text(S.next, style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView.builder(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 130 + MediaQuery.viewPaddingOf(context).bottom),
            itemCount: _set.count + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _set.title.isEmpty ? S.printTitleDefault : _set.title,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${product.square ? S.squarePrints : S.regularPrints} · ${S.printsN(_set.count)} · ${timeAgo(_set.updatedAtMs)}',
                      style: TextStyle(fontSize: 16, height: 1.4, color: context.mutedText),
                    ),
                    if (_app.basket.any((b) => b.bookId == _set.id)) ...[
                      const SizedBox(height: 14),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: context.pillColor,
                          foregroundColor: context.strongText,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () =>
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BasketScreen())),
                        child: const Text(S.viewInBasket),
                      ),
                    ],
                    Divider(height: 36, color: context.divider),
                  ],
                );
              }
              final i = index - 1;
              final item = _set.items[i];
              final cover = i == 0;
              return Padding(
                key: ValueKey(item.id),
                padding: const EdgeInsets.only(bottom: 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cover ? S.coverPrint : S.printN(i),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                          ),
                        ),
                        _round(
                          null,
                          () => _themes(i),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: hexColor(_set.colorOf(item)),
                              shape: BoxShape.circle,
                              border: Border.all(color: context.divider),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (cover)
                          _round(Icons.call_to_action_outlined, _coverTemplates)
                        else if (product.square)
                          _round(
                            item.border ? Icons.crop_din : Icons.crop_free,
                            () => _changed(() => item.border = !item.border),
                          )
                        else
                          // Simge gidilecek yönü gösterir: dikeyken yatay, yatayken dikey dikdörtgen.
                          _round(
                            item.portrait ? Icons.crop_landscape : Icons.crop_portrait,
                            () => _toggleOrientation(i),
                          ),
                        const SizedBox(width: 10),
                        _round(
                          null,
                          cover ? _editTitle : () => _editCaption(i),
                          child: const Text('Aa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(width: 10),
                        _round(Icons.more_horiz, () => _printMenu(i)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        // Dikey baskı yataydan daha dar: dikey olduğu bir bakışta anlaşılsın.
                        child: AnimatedFractionallySizedBox(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOutCubic,
                          widthFactor: item.portrait && !product.square ? 0.72 : 1,
                          child: GestureDetector(
                            onTap: () => _editPhoto(i),
                            child: PrintCard(set: _set, index: i, fonts: _fonts),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 12 + MediaQuery.viewPaddingOf(context).bottom,
            child: Material(
              elevation: 8,
              color: context.sheetColor,
              borderRadius: BorderRadius.circular(14),
              child: Row(
                children: [
                  for (final (icon, label, onTap) in [
                    (Icons.palette_outlined, S.themes, () => _themes()),
                    (
                      Icons.crop_free,
                      S.borderOn,
                      () => _changed(() {
                        final all = _set.items.every((e) => e.border);
                        for (final e in _set.items) {
                          e.border = !all;
                        }
                      }),
                    ),
                    (Icons.add_photo_alternate_outlined, S.addMorePrints, _addMore),
                    (Icons.more_horiz, S.options, _options),
                  ])
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: onTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon),
                              const SizedBox(height: 4),
                              Text(label, style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Popsa Templates (kapak baskısı): düzenler gerçek kapak önizlemesiyle iki sütunda; seçili olan vurgulu.
class CoverTemplateScreen extends StatelessWidget {
  const CoverTemplateScreen({super.key, required this.set, required this.fonts});

  final PrintSet set;
  final List<TextAppearance> fonts;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.templates)),
      body: GridView.builder(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + MediaQuery.viewPaddingOf(context).bottom),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 18,
          crossAxisSpacing: 18,
          childAspectRatio: PrintCard.aspectOf(set, set.items.first),
        ),
        itemCount: CoverLayout.values.length,
        itemBuilder: (context, i) {
          final layout = CoverLayout.values[i];
          final selected = layout == set.layout;
          return GestureDetector(
            onTap: () => Navigator.pop(context, layout),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: selected ? AppColors.accent : Colors.transparent, width: 3),
              ),
              child: PrintCard(set: set, index: 0, fonts: fonts, thumbSize: 300, layout: layout),
            ),
          );
        },
      ),
    );
  }
}

/// Popsa Remove Prints: kaldırılacak baskıları seç (kapak hariç); set en az [PrintProduct.minPrints] baskı kalır.
class RemovePrintsScreen extends StatefulWidget {
  const RemovePrintsScreen({super.key, required this.set, required this.fonts});

  final PrintSet set;
  final List<TextAppearance> fonts;

  @override
  State<RemovePrintsScreen> createState() => _RemovePrintsScreenState();
}

class _RemovePrintsScreenState extends State<RemovePrintsScreen> {
  final _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final set = widget.set;
    final removable = set.count - PrintProduct.minPrints;
    return Scaffold(
      appBar: AppBar(title: Text(S.removePrintsN(_selected.length))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(S.minPrintsWarning(PrintProduct.minPrints), style: TextStyle(color: context.mutedText)),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
              ),
              itemCount: set.count - 1,
              itemBuilder: (_, k) {
                final i = k + 1;
                final selected = _selected.contains(i);
                final disabled = !selected && _selected.length >= removable;
                return GestureDetector(
                  onTap: disabled ? null : () => setState(() => selected ? _selected.remove(i) : _selected.add(i)),
                  child: Opacity(
                    opacity: disabled ? 0.4 : 1,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PrintCard(set: set, index: i, fonts: widget.fonts, thumbSize: 250),
                        if (selected)
                          const Positioned(
                            top: 4,
                            right: 4,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.failure,
                              child: Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.failure),
                  onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected),
                  child: Text(S.removePrintsN(_selected.length)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
