import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../constants/strings_tr.dart';
import '../../../models/catalog.dart';
import '../../../view_model/editor_view_model.dart';

/// Kitabın yazı grubunu değiştirir (Seçenekler → Yazı Tipini Değiştir).
Future<void> showFontSheet(BuildContext context, EditorViewModel vm) async {
  final id = await pickFont(context, fonts: vm.catalog.textAppearances, selectedId: vm.book.textAppearanceId);
  if (id != null) vm.setTextAppearance(id);
}

/// Yazı tipi seçim ekranını açar; seçilen yazı grubunun kimliğini döndürür.
Future<String?> pickFont(BuildContext context, {required List<TextAppearance> fonts, required String selectedId}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => FontPickerScreen(fonts: fonts, selectedId: selectedId),
    ),
  );
}

/// Yazı grubu seçimi (Popsa FontPickerActivity): her grup için alfabe örneği.
class FontPickerScreen extends StatelessWidget {
  const FontPickerScreen({super.key, required this.fonts, required this.selectedId});

  final List<TextAppearance> fonts;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.fonts)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(S.selectFontGroup, style: TextStyle(color: context.mutedText, height: 1.4)),
          const SizedBox(height: 16),
          for (final f in fonts)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Material(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.pop(context, f.id),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 26, 16, 26),
                    child: Stack(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            children: [
                              Text(
                                f.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 13,
                                  letterSpacing: 1.6,
                                  fontWeight: FontWeight.w600,
                                  color: context.strongText,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'ABCÇDEFGĞHIİJKLMN\nOPRSŞTUÜVYZ',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: f.titleFont,
                                  fontWeight: f.titleWeight,
                                  letterSpacing: 2 + f.letterSpacing,
                                  fontSize: 20,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'abcçdefgğhıijklmn\noöprsştuüvyz',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontFamily: f.bodyFont, fontSize: 18, letterSpacing: 2, height: 1.35),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '1234567890',
                                style: TextStyle(fontFamily: f.bodyFont, fontSize: 18, letterSpacing: 3),
                              ),
                            ],
                          ),
                        ),
                        if (f.id == selectedId)
                          const Positioned(right: 4, bottom: 0, child: Icon(Icons.check, size: 32)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
