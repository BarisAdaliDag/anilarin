import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../constants/strings_tr.dart';
import '../../../models/catalog.dart';
import '../../../view_model/editor_view_model.dart';

/// Şablon seçici (Popsa PageTemplateActivity): iki sütunlu ızgara; iç sayfalarda kategori çipleri.
class TemplatePickerScreen extends StatefulWidget {
  const TemplatePickerScreen({super.key, required this.pageIndex});

  final int pageIndex;

  @override
  State<TemplatePickerScreen> createState() => _TemplatePickerScreenState();
}

class _TemplatePickerScreenState extends State<TemplatePickerScreen> {
  String _category = 'all';

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditorViewModel>();
    final isCover = vm.book.pages[widget.pageIndex].isCover;
    final all = vm.templatesFor(widget.pageIndex);
    final categories = [
      'all',
      ...S.templateCategories.keys.where((k) => k != 'all' && all.any((t) => t.categories.contains(k))),
    ];
    final list = _category == 'all' ? all : all.where((t) => t.categories.contains(_category)).toList();
    final current = vm.book.pages[widget.pageIndex].templateId;

    return Scaffold(
      appBar: AppBar(title: const Text(S.templates)),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Text(S.templateWarning, style: TextStyle(fontSize: 15, height: 1.4, color: context.strongText)),
          ),
        ),
        if (!isCover)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(S.templateCategories[c]!),
                        selected: c == _category,
                        showCheckmark: false,
                        selectedColor: context.isDark ? const Color(0xFF555555) : const Color(0xFFDADADA),
                        backgroundColor: context.pillColor,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onSelected: (_) => setState(() => _category = c),
                      ),
                    ),
                ],
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: vm.product.aspect,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final t = list[i];
              return GestureDetector(
                onTap: () {
                  vm.changeTemplate(widget.pageIndex, t.id);
                  Navigator.pop(context);
                },
                child: TemplateThumb(template: t, format: vm.format, selected: t.id == current),
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// Popsa'daki gibi şablon önizlemesi: gri zemin, açık gri fotoğraf alanları, "AaBbCc" yazı örneği.
class TemplateThumb extends StatelessWidget {
  const TemplateThumb({super.key, required this.template, required this.format, this.selected = false});

  final PageTemplate template;
  final String format;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final tile = selected ? const Color(0xFF52ACC2) : (dark ? const Color(0xFF585858) : const Color(0xFFD5D5D5));
    final photo = selected ? const Color(0xFFA9D4E0) : (dark ? const Color(0xFFABABAB) : const Color(0xFFF2F2F2));
    final text = dark || selected ? Colors.white : const Color(0xFF555555);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: tile,
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          final elements = template.elementsFor(format);
          return Stack(children: [
            for (final e in elements.where((e) => e.isPhoto))
              Positioned(
                left: e.frame.left / 100 * w,
                top: e.frame.top / 100 * h,
                width: e.frame.width / 100 * w,
                height: e.frame.height / 100 * h,
                // Popsa tam sayfa fotoğrafı ayrı kutu olarak çizmez (geçişli şablon hariç).
                child: e.frame.width >= 99 && e.frame.height >= 99 && !elements.any((x) => x.scrim)
                    ? const SizedBox.shrink()
                    : Container(
                        decoration: BoxDecoration(
                          color: photo,
                          border: e.border ? Border.all(color: Colors.white, width: w * 0.015) : null,
                        ),
                      ),
              ),
            for (final e in elements.where((e) => e.scrim))
              Positioned(
                left: 0,
                right: 0,
                top: (e.frame.top - e.frame.height) / 100 * h,
                bottom: 0,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x88000000)],
                    ),
                  ),
                ),
              ),
            for (final e in elements.where((e) => !e.isPhoto))
              Positioned(
                left: e.frame.left / 100 * w,
                top: e.frame.top / 100 * h,
                width: e.frame.width / 100 * w,
                height: e.frame.height / 100 * h,
                child: _sampleText(e, w, h, text),
              ),
          ]);
        }),
      ),
    );
  }

  Widget _sampleText(TemplateElement e, double w, double h, Color color) {
    final alignment = switch (e.align) {
      TextAlign.left => Alignment.centerLeft,
      TextAlign.right => Alignment.centerRight,
      _ => Alignment.center,
    };
    Widget child;
    if (e.role == 'caption') {
      child = FractionallySizedBox(
        widthFactor: 0.9,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var k = 0; k < 4; k++)
            Container(height: 1.6, margin: const EdgeInsets.symmetric(vertical: 1.4), color: color.withValues(alpha: 0.8)),
        ]),
      );
    } else {
      child = Padding(
        padding: EdgeInsets.symmetric(horizontal: w * 0.02),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: Text(
            'AaBbCc',
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: h * 0.11),
          ),
        ),
      );
    }
    child = Align(alignment: alignment, child: child);
    if (e.vertical) child = RotatedBox(quarterTurns: 3, child: child);
    return child;
  }
}
