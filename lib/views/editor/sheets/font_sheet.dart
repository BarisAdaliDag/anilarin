import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../constants/strings_tr.dart';
import '../../../view_model/editor_view_model.dart';

/// Yazı grubu seçimi (Popsa FontPickerActivity): her grup için alfabe örneği.
Future<void> showFontSheet(BuildContext context, EditorViewModel vm) {
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ChangeNotifierProvider.value(value: vm, child: const _FontScreen()),
  ));
}

class _FontScreen extends StatelessWidget {
  const _FontScreen();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditorViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text(S.fonts)),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
        Text(S.selectFontGroup, style: TextStyle(color: context.mutedText, height: 1.4)),
        const SizedBox(height: 16),
        for (final f in vm.catalog.textAppearances)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Material(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => vm.setTextAppearance(f.id),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: f.id == vm.book.textAppearanceId ? AppColors.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(children: [
                    Text(f.name.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 1.6, color: context.mutedText)),
                    const SizedBox(height: 10),
                    Text(
                      f.apply('ABCÇDEFGĞHIİJKLMN\nOPRSŞTUÜVYZ'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: f.titleFont, fontWeight: f.titleWeight, letterSpacing: f.letterSpacing, fontSize: 19, height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'abcçdefgğhıijklmnoöprsştuüvyz\n1234567890',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: f.bodyFont, fontSize: 15, color: context.mutedText, height: 1.3),
                    ),
                    if (f.id == vm.book.textAppearanceId)
                      const Align(alignment: Alignment.centerRight, child: Icon(Icons.check, color: AppColors.accent)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
