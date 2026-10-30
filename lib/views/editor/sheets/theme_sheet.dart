import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../constants/strings_tr.dart';
import '../../../models/catalog.dart';
import '../../../services/palette_service.dart';
import '../../../view_model/editor_view_model.dart';

/// Tema paneli (Popsa ThemeSelectorBottomSheet): kapsam seçimi; Dinamik ve Nötr görünür, yukarı çekince
/// Pastel, Koyu, Canlı ve Dokular açılır. Arkadaki editör kararmaz, seçim anında sayfalarda görünür.
Future<void> showThemeSheet(BuildContext context, EditorViewModel vm, {int? pageIndex}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    barrierColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: vm,
      child: _ThemeSheet(pageIndex: pageIndex),
    ),
  );
}

class _ThemeSheet extends StatefulWidget {
  const _ThemeSheet({this.pageIndex});

  final int? pageIndex;

  @override
  State<_ThemeSheet> createState() => _ThemeSheetState();
}

class _ThemeSheetState extends State<_ThemeSheet> {
  late ThemeScope _scope = switch (widget.pageIndex) {
    null => ThemeScope.inside,
    0 => ThemeScope.cover,
    _ => ThemeScope.page,
  };

  static const _groups = [('neutral', S.neutralThemes), ('pastel', 'Pastel'), ('deep', 'Koyu'), ('vivid', 'Canlı')];

  String _scopeLabel(ThemeScope s) => switch (s) {
    ThemeScope.cover => S.frontCover,
    ThemeScope.inside => S.allInnerPages,
    ThemeScope.all => S.allPages,
    ThemeScope.page => S.pageN(widget.pageIndex ?? 1),
  };

  String _current(EditorViewModel vm) => switch (_scope) {
    ThemeScope.cover => vm.book.themeIdOf(0),
    ThemeScope.page => vm.book.themeIdOf(widget.pageIndex!),
    ThemeScope.inside => vm.book.pages.length > 1 ? vm.book.themeIdOf(1) : vm.book.themeId,
    ThemeScope.all => vm.book.themeId,
  };

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditorViewModel>();
    final current = _current(vm).toUpperCase();
    final scopes = [
      if (widget.pageIndex != null && widget.pageIndex! > 0) ThemeScope.page,
      ThemeScope.cover,
      ThemeScope.inside,
      ThemeScope.all,
    ];
    final palette = vm.book.palette;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.42,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.42, 0.92],
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 12, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(S.themes, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                    PopupMenuButton<ThemeScope>(
                      initialValue: _scope,
                      onSelected: (s) => setState(() => _scope = s),
                      itemBuilder: (_) => [
                        for (final s in scopes)
                          CheckedPopupMenuItem(value: s, checked: s == _scope, child: Text(_scopeLabel(s))),
                      ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_scopeLabel(_scope), style: TextStyle(color: context.mutedText, fontSize: 16)),
                          Icon(Icons.keyboard_arrow_down, color: context.mutedText),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          if (palette.length >= 5 && (_scope == ThemeScope.inside || _scope == ThemeScope.all)) ...[
            const SizedBox(height: 18),
            const Text(S.dynamicThemes, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            Text(S.dynamicThemesBody, style: TextStyle(color: context.mutedText, fontSize: 14)),
            const SizedBox(height: 12),
            ThemeSwatchRow(
              children: [
                for (final i in PaletteService.displayOrder.where((i) => i < palette.length))
                  ThemeSwatch(
                    selected: current == 'DYN:$i',
                    onTap: () => _apply(vm, 'dyn:$i'),
                    // Her sayfa kendi tonunu alacağı için daire kitaptaki iki farklı sayfanın tonunu gösterir.
                    colors: _dynamicPreview(vm, i),
                  ),
              ],
            ),
          ],
          for (final (id, name) in _groups) ...[
            const SizedBox(height: 20),
            Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            ThemeSwatchRow(
              children: [
                for (final c in Catalog.themeGroups[id]!)
                  ThemeSwatch(selected: current == c.toUpperCase(), colors: [hexColor(c)], onTap: () => _apply(vm, c)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Dinamik dairede gösterilecek renkler: kitap paleti ve (varsa) farklı iki sayfanın aynı tonu.
  List<Color> _dynamicPreview(EditorViewModel vm, int i) {
    final colors = <Color>[hexColor(vm.book.palette[i])];
    for (final p in vm.book.pages.skip(1)) {
      if (p.palette.length > i) {
        final c = hexColor(p.palette[i]);
        if (!colors.contains(c)) colors.add(c);
      }
      if (colors.length == 3) break;
    }
    return colors;
  }

  void _apply(EditorViewModel vm, String id) => vm.setTheme(id, scope: _scope, pageIndex: widget.pageIndex);
}

class ThemeSwatchRow extends StatelessWidget {
  const ThemeSwatchRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

class ThemeSwatch extends StatelessWidget {
  const ThemeSwatch({super.key, required this.colors, required this.selected, required this.onTap});

  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 62,
        height: 62,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: selected ? context.strongText : Colors.transparent, width: 2.5),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.first,
            gradient: colors.length > 1
                ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors)
                : null,
            border: Border.all(color: Colors.black12),
          ),
        ),
      ),
    );
  }
}
