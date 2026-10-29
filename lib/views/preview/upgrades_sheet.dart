import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../view_model/editor_view_model.dart';

/// Önizlemedeki Yükseltmeler penceresi (Popsa Upgrades): Tür / Boyut / Kâğıt.
/// Seçim hemen kitaba uygulanır; önizleme arkada güncellenir.
Future<void> showUpgradesSheet(BuildContext context, EditorViewModel vm, {ValueChanged<int>? onTab}) {
  return showModalBottomSheet<void>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (_) => _UpgradesSheet(vm: vm, onTab: onTab),
  );
}

class _UpgradesSheet extends StatefulWidget {
  const _UpgradesSheet({required this.vm, this.onTab});

  final EditorViewModel vm;
  final ValueChanged<int>? onTab;

  @override
  State<_UpgradesSheet> createState() => _UpgradesSheetState();
}

class _UpgradesSheetState extends State<_UpgradesSheet> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.vm,
      builder: (context, _) {
        final vm = widget.vm;
        final product = vm.product;
        final catalog = vm.catalog;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(S.upgrades, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                const SizedBox(height: 18),
                _Tabs(
                  value: _tab,
                  labels: const [S.upgradeType, S.upgradeSize, S.paperFinish],
                  onChanged: (i) {
                    setState(() => _tab = i);
                    widget.onTab?.call(i);
                  },
                ),
                const SizedBox(height: 14),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: switch (_tab) {
                    0 => Column(
                      key: const ValueKey('type'),
                      children: [
                        for (final type in catalog.productTypes)
                          if (catalog.closestOfType(product, type) case final p?)
                            _option(
                              icon: Icon(_typeIcon(type), size: 30),
                              title: p.typeLabel,
                              subtitle: vm.book.pageCount > p.pagesMax ? S.maxPagesNote(p.pagesMax) : p.tierLabel,
                              selected: product.type == type,
                              enabled: vm.book.pageCount <= p.pagesMax,
                              onTap: () => vm.changeProduct(p.code),
                            ),
                      ],
                    ),
                    1 => Column(
                      key: const ValueKey('size'),
                      children: [
                        for (final p in catalog.sizesOf(product.type, product.format))
                          _option(
                            icon: Text(
                              _sizeLetter(p.size),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1),
                            ),
                            title: p.sizeLabel,
                            subtitle: '${p.dimensionsCm.replaceAll(' × ', ' cm × ')} cm',
                            selected: p.code == product.code,
                            enabled: vm.book.pageCount <= p.pagesMax,
                            onTap: () => vm.changeProduct(p.code),
                          ),
                      ],
                    ),
                    _ => Column(
                      key: const ValueKey('paper'),
                      children: [
                        _option(
                          icon: const Icon(Icons.auto_awesome_outlined, size: 26),
                          title: S.matte,
                          subtitle: S.tierStandard,
                          selected: !vm.book.options.gloss,
                          onTap: () => vm.setGloss(false),
                        ),
                        _option(
                          icon: const Icon(Icons.auto_awesome, size: 26),
                          title: S.gloss,
                          subtitle: S.tierPremium,
                          selected: vm.book.options.gloss,
                          onTap: () => vm.setGloss(true),
                        ),
                      ],
                    ),
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static IconData _typeIcon(String type) => switch (type) {
    'booklet' => Icons.import_contacts_outlined,
    'softcover' => Icons.menu_book_outlined,
    _ => Icons.auto_stories_outlined,
  };

  static String _sizeLetter(String size) => switch (size) {
    'small' => 'S',
    'medium' => 'M',
    'xlarge' => 'XL',
    _ => 'L',
  };

  Widget _option({
    required Widget icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled && !selected ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? context.strongText : Colors.transparent, width: 2.5),
          ),
          child: Row(
            children: [
              SizedBox(width: 40, child: Center(child: icon)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 15, color: context.mutedText)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.value, required this.labels, required this.onChanged});

  final int value;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: context.pillColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: i == value ? (context.isDark ? AppColors.darkBackground : Colors.white) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(labels[i], style: const TextStyle(fontSize: 15)),
              ),
            ),
        ],
      ),
    );
  }
}
