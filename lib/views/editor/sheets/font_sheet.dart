import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../constants/strings_tr.dart';
import '../../../view_model/editor_view_model.dart';

/// Yazı grubu seçimi (Popsa FontPickerActivity).
Future<void> showFontSheet(BuildContext context, EditorViewModel vm) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider.value(value: vm, child: const _FontSheet()),
  );
}

class _FontSheet extends StatelessWidget {
  const _FontSheet();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditorViewModel>();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(S.changeFont, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 4),
          const Text(S.selectFontGroup, style: TextStyle(color: AppColors.text)),
          const SizedBox(height: 12),
          for (final f in vm.catalog.textAppearances)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: f.id == vm.book.textAppearanceId ? AppColors.accent.withValues(alpha: 0.1) : AppColors.background,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => vm.setTextAppearance(f.id),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            f.apply(vm.book.title.isEmpty ? f.name : vm.book.title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: f.titleFont,
                              fontWeight: f.titleWeight,
                              letterSpacing: f.letterSpacing,
                              fontSize: 22,
                            ),
                          ),
                          Text(
                            f.name,
                            style: TextStyle(fontFamily: f.bodyFont, fontSize: 13, color: AppColors.text),
                          ),
                        ]),
                      ),
                      if (f.id == vm.book.textAppearanceId) const Icon(Icons.check_circle, color: AppColors.accent),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
