import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../constants/strings_tr.dart';
import '../../../models/catalog.dart';
import '../../../view_model/editor_view_model.dart';

/// Tema seçici (Popsa ThemeSelectorBottomSheet): kapsam seçimi, dinamik ve nötr renkler.
Future<void> showThemeSheet(BuildContext context, EditorViewModel vm, {int? pageIndex}) {
  return showModalBottomSheet(
    context: context,
    barrierColor: Colors.black26,
    builder: (_) => ChangeNotifierProvider.value(value: vm, child: _ThemeSheet(pageIndex: pageIndex)),
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
    null => ThemeScope.all,
    0 => ThemeScope.cover,
    _ => ThemeScope.page,
  };

  String _scopeLabel(ThemeScope s) => switch (s) {
        ThemeScope.cover => S.frontCover,
        ThemeScope.inside => S.allInnerPages,
        ThemeScope.all => S.allPages,
        ThemeScope.page => S.pageN(widget.pageIndex ?? 1),
      };

  String _current(EditorViewModel vm) => switch (_scope) {
        ThemeScope.cover => vm.themeOf(0).id,
        ThemeScope.page => vm.themeOf(widget.pageIndex!).id,
        ThemeScope.inside => vm.book.pages.length > 1 ? vm.themeOf(1).id : vm.book.themeId,
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 12, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text(S.themes, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
                PopupMenuButton<ThemeScope>(
                  initialValue: _scope,
                  onSelected: (s) => setState(() => _scope = s),
                  itemBuilder: (_) => [
                    for (final s in scopes) CheckedPopupMenuItem(value: s, checked: s == _scope, child: Text(_scopeLabel(s))),
                  ],
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_scopeLabel(_scope), style: TextStyle(color: context.mutedText, fontSize: 15)),
                    Icon(Icons.keyboard_arrow_down, color: context.mutedText),
                  ]),
                ),
              ]),
            ),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
          if (palette.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(S.dynamicThemes, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
            Text(S.dynamicThemesBody, style: TextStyle(color: context.mutedText, fontSize: 13)),
            const SizedBox(height: 12),
            _Swatches(colors: palette, current: current, onPick: (c) => _apply(vm, c)),
          ],
          const SizedBox(height: 18),
          const Text(S.neutralThemes, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          _Swatches(colors: vm.catalog.neutralColors, current: current, onPick: (c) => _apply(vm, c)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: vm.resetThemes, child: const Text(S.resetAll)),
          ),
        ]),
      ),
    );
  }

  void _apply(EditorViewModel vm, String color) =>
      vm.setTheme(color, scope: _scope, pageIndex: widget.pageIndex);
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.colors, required this.current, required this.onPick});

  final List<String> colors;
  final String current;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: colors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final selected = colors[i].toUpperCase() == current;
          return GestureDetector(
            onTap: () => onPick(colors[i]),
            child: Container(
              width: 54,
              height: 54,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? context.strongText : Colors.transparent, width: 2),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: hexColor(colors[i]),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
