import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/catalog.dart';
import '../../models/print_set.dart';
import '../../services/palette_service.dart';
import '../editor/sheets/theme_sheet.dart' show ThemeSwatch, ThemeSwatchRow;

/// Baskı tema penceresi (Popsa Themes, baskılar): kapsam "Baskı N" ya da "Tüm baskılar";
/// Dinamik (o baskının fotoğrafından), Nötr (beyaz önerilen), Pastel, Koyu, Canlı.
/// [index] verilirse o baskı seçili açılır. Seçim anında uygulanır; [onChanged] kaydı yapar.
Future<void> showPrintThemeSheet(
  BuildContext context, {
  required PrintSet set,
  int? index,
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    barrierColor: Colors.transparent,
    builder: (_) => _PrintThemeSheet(set: set, index: index, onChanged: onChanged),
  );
}

class _PrintThemeSheet extends StatefulWidget {
  const _PrintThemeSheet({required this.set, this.index, required this.onChanged});

  final PrintSet set;
  final int? index;
  final VoidCallback onChanged;

  @override
  State<_PrintThemeSheet> createState() => _PrintThemeSheetState();
}

class _PrintThemeSheetState extends State<_PrintThemeSheet> {
  late int? _index = widget.index; // null: tüm baskılar
  List<String> _dynamic = const [];

  static const _groups = [('neutral', S.neutralThemes), ('pastel', 'Pastel'), ('deep', 'Koyu'), ('vivid', 'Canlı')];

  PrintSet get _set => widget.set;

  @override
  void initState() {
    super.initState();
    _loadDynamic();
  }

  Future<void> _loadDynamic() async {
    final ids = _index == null ? _set.items.take(6).map((e) => e.photo.id).toList() : [_set.items[_index!].photo.id];
    final palette = await PaletteService.forPhotos(ids);
    if (!mounted) return;
    setState(() {
      // Popsa gibi 5 ton: açık → koyu sırasında görünen tonlar.
      _dynamic = [
        for (final i in PaletteService.displayOrder.where((i) => i < palette.length)) palette[i],
      ].take(5).toList();
    });
  }

  String _label(int? i) => i == null ? S.allPrints : (i == 0 ? S.coverPrint : S.printN(i));

  String get _current => (_index == null ? _set.colorHex : _set.colorOf(_set.items[_index!])).toUpperCase();

  void _apply(String hex) {
    setState(() {
      if (_index == null) {
        _set.setColorAll(hex);
      } else {
        _set.items[_index!].colorHex = hex.toUpperCase() == _set.colorHex.toUpperCase() ? null : hex;
      }
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.5, 0.92],
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
                    PopupMenuButton<int>(
                      initialValue: _index ?? -1,
                      onSelected: (v) {
                        setState(() => _index = v < 0 ? null : v);
                        _loadDynamic();
                      },
                      itemBuilder: (_) => [
                        if (widget.index != null)
                          CheckedPopupMenuItem(
                            value: widget.index!,
                            checked: _index == widget.index,
                            child: Text(_label(widget.index)),
                          ),
                        CheckedPopupMenuItem(value: -1, checked: _index == null, child: Text(_label(null))),
                      ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_label(_index), style: TextStyle(color: context.mutedText, fontSize: 16)),
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
          if (_dynamic.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(S.dynamicThemes, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            Text(S.dynamicThemesBody, style: TextStyle(color: context.mutedText, fontSize: 14)),
            const SizedBox(height: 12),
            ThemeSwatchRow(
              children: [
                for (final c in _dynamic)
                  ThemeSwatch(selected: current == c.toUpperCase(), colors: [hexColor(c)], onTap: () => _apply(c)),
              ],
            ),
          ],
          for (final (id, name) in _groups) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                if (id == 'neutral') ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      S.recommendedWhite,
                      style: TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            ThemeSwatchRow(
              children: [
                for (final c in Catalog.themeGroups[id]!)
                  ThemeSwatch(selected: current == c.toUpperCase(), colors: [hexColor(c)], onTap: () => _apply(c)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
