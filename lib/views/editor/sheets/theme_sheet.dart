import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../constants/strings_tr.dart';
import '../../../models/catalog.dart';
import '../../../view_model/editor_view_model.dart';

/// Tema seçici (Popsa ThemesActivity / ThemeSelectorBottomSheet).
Future<void> showThemeSheet(BuildContext context, EditorViewModel vm, {int? pageIndex}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
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
  late ThemeScope _scope = widget.pageIndex == null ? ThemeScope.all : ThemeScope.page;
  String _group = 'colors';

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditorViewModel>();
    final catalog = vm.catalog;
    final current = widget.pageIndex != null && _scope == ThemeScope.page
        ? vm.themeOf(widget.pageIndex!).id
        : vm.book.themeId;
    final themes = catalog.themes.where((t) => t.group == _group).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Text(S.themes, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const Spacer(),
              TextButton(onPressed: vm.resetThemes, child: const Text(S.resetAll)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: SegmentedButton<ThemeScope>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.accent,
                selectedForegroundColor: Colors.white,
              ),
              segments: [
                const ButtonSegment(value: ThemeScope.all, label: Text(S.applyAll)),
                if (widget.pageIndex != null) const ButtonSegment(value: ThemeScope.page, label: Text(S.applyThisPage)),
                const ButtonSegment(value: ThemeScope.inside, label: Text(S.applyInside)),
              ],
              selected: {_scope},
              onSelectionChanged: (s) => setState(() => _scope = s.first),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final g in catalog.themeGroups)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(g.name),
                      selected: g.id == _group,
                      showCheckmark: false,
                      labelStyle: TextStyle(color: g.id == _group ? Colors.white : AppColors.textStrong),
                      onSelected: (_) => setState(() => _group = g.id),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemCount: themes.length,
              itemBuilder: (_, i) => _ThemeTile(
                theme: themes[i],
                selected: themes[i].id == current,
                onTap: () => vm.setTheme(themes[i].id, scope: _scope, pageIndex: widget.pageIndex),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.theme, required this.selected, required this.onTap});

  final BookTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? AppColors.accent : AppColors.grey, width: selected ? 3 : 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(children: [
              // kapak
              Expanded(
                child: ColoredBox(
                  color: theme.coverBackground,
                  child: Center(
                    child: Text('Aa', style: TextStyle(color: theme.coverText, fontWeight: FontWeight.w700, fontSize: 20)),
                  ),
                ),
              ),
              // iç sayfa
              Expanded(
                child: ColoredBox(
                  color: theme.background,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(children: [
                      Expanded(child: Container(color: const Color(0xFFDADADA))),
                      const SizedBox(height: 4),
                      Container(height: 4, color: theme.title),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Text(theme.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      ]),
    );
  }
}
