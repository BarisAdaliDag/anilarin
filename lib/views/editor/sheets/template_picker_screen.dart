import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../constants/strings_tr.dart';
import '../../../models/catalog.dart';
import '../../../view_model/editor_view_model.dart';

/// Şablon seçici (Popsa PageTemplateActivity): kategori çipleri ve şablon ızgarası.
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
    final all = vm.templatesFor(widget.pageIndex);
    final categories = ['all', ...S.templateCategories.keys.where((k) => k != 'all' && all.any((t) => t.categories.contains(k)))];
    final list = _category == 'all' ? all : all.where((t) => t.categories.contains(_category)).toList();
    final current = vm.book.pages[widget.pageIndex].templateId;
    final photoCount = vm.book.pages[widget.pageIndex].photoIds.length;
    final theme = vm.themeOf(widget.pageIndex);
    final isCover = vm.book.pages[widget.pageIndex].isCover;

    return Scaffold(
      appBar: AppBar(title: const Text(S.changeTemplate)),
      body: Column(children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: const Text(S.templateWarning, style: TextStyle(fontSize: 13)),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final c in categories)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(S.templateCategories[c]!),
                    selected: c == _category,
                    showCheckmark: false,
                    labelStyle: TextStyle(color: c == _category ? Colors.white : context.strongText),
                    onSelected: (_) => setState(() => _category = c),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final t = list[i];
              final loses = t.photoCount < photoCount;
              return GestureDetector(
                onTap: () {
                  vm.changeTemplate(widget.pageIndex, t.id);
                  Navigator.pop(context);
                },
                child: Column(children: [
                  Expanded(
                    child: Center(
                      child: TemplateThumb(
                        template: t,
                        format: vm.format,
                        aspect: vm.product.aspect,
                        background: isCover ? theme.coverBackground : theme.background,
                        textColor: isCover ? theme.coverText : theme.title,
                        selected: t.id == current,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loses ? '${t.photoCount} foto · ${photoCount - t.photoCount} çıkar' : '${t.photoCount} foto',
                    style: TextStyle(fontSize: 11, color: loses ? AppColors.warning : context.mutedText),
                  ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class TemplateThumb extends StatelessWidget {
  const TemplateThumb({
    super.key,
    required this.template,
    required this.format,
    required this.aspect,
    required this.background,
    required this.textColor,
    this.selected = false,
  });

  final PageTemplate template;
  final String format;
  final double aspect;
  final Color background;
  final Color textColor;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspect,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: selected ? AppColors.accent : context.divider, width: selected ? 3 : 1),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return Stack(children: [
            for (final e in template.elementsFor(format))
              Positioned(
                left: e.frame.left / 100 * w,
                top: e.frame.top / 100 * h,
                width: e.frame.width / 100 * w,
                height: e.frame.height / 100 * h,
                child: e.isPhoto
                    ? Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFCFD8DC),
                          border: Border.all(color: background, width: 0.5),
                        ),
                      )
                    : Align(
                        alignment: switch (e.align) {
                          TextAlign.left => Alignment.centerLeft,
                          TextAlign.right => Alignment.centerRight,
                          _ => Alignment.center,
                        },
                        child: FractionallySizedBox(
                          widthFactor: e.role == 'title' ? 0.7 : 0.9,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var k = 0; k < (e.role == 'title' ? 1 : 3); k++)
                                Container(
                                  height: e.role == 'title' ? 4 : 2,
                                  margin: const EdgeInsets.symmetric(vertical: 1),
                                  color: textColor.withValues(alpha: 0.7),
                                ),
                            ],
                          ),
                        ),
                      ),
              ),
          ]);
        }),
      ),
    );
  }
}
