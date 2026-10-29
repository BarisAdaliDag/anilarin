import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../constants/strings_tr.dart';
import '../../../models/catalog.dart';
import '../../../view_model/editor_view_model.dart';
import '../text_editor_screen.dart';

Future<void> editTitleDialog(BuildContext context, EditorViewModel vm) async {
  final title = TextEditingController(text: vm.book.title);
  final subtitle = TextEditingController(text: vm.book.subtitle);
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text(S.editTitle, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 12),
        TextField(
          controller: title,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(labelText: S.titleHint),
        ),
        TextField(
          controller: subtitle,
          maxLength: 60,
          decoration: const InputDecoration(labelText: S.subtitleHint),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text(S.save)),
      ]),
    ),
  );
  if (ok == true) vm.setTitle(title.text, subtitle.text);
}

/// Sayfaya altyazı ekler. Şablonda yazı alanı yoksa aynı fotoğraf sayısındaki yazılı bir şablona geçer.
Future<void> editCaptionFlow(BuildContext context, EditorViewModel vm, int pageIndex) async {
  if (vm.templateOf(pageIndex).textSlots(vm.format).isEmpty) {
    final tpl = vm.captionTemplateFor(pageIndex);
    if (tpl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu sayfa düzeni için yazılı şablon yok. Önce şablonu değiştir.')),
      );
      return;
    }
    vm.changeTemplate(pageIndex, tpl);
  }
  if (!context.mounted) return;
  await editCaptionDialog(context, vm, pageIndex, 0);
}

Future<void> editCaptionDialog(BuildContext context, EditorViewModel vm, int pageIndex, int textIndex) async {
  final page = vm.book.pages[pageIndex];
  final slots = vm.templateOf(pageIndex).textSlots(vm.format);
  if (textIndex >= slots.length) return;
  final isTitle = slots[textIndex].role == 'title';
  final result = await Navigator.of(context).push<String>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => TextEditorScreen(
      title: isTitle ? 'Başlık Ekle' : S.addCaption,
      initial: textIndex < page.texts.length ? page.texts[textIndex] : '',
      limit: isTitle ? 40 : 240,
      font: vm.textAppearance,
    ),
  ));
  if (result != null) vm.setCaption(pageIndex, textIndex, result);
}

Future<bool> confirmDelete(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text(S.deleteBook),
      content: const Text(S.deleteBookConfirm),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text(S.cancel)),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text(S.delete, style: TextStyle(color: AppColors.failure)),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<void> showAboutBook(BuildContext context, EditorViewModel vm) {
  final p = vm.product;
  final b = vm.book;
  final rows = <(String, String)>[
    ('Ürün', p.title),
    ('Boyut', '${p.sizeLabel} · ${p.formatLabel} · ${p.dimensionsCm} cm'),
    ('Sayfa', '${b.pageCount} (${p.pagesMin}–${p.pagesMax})'),
    ('Fotoğraf', '${b.usedPhotoIds.length} kullanıldı · ${b.unusedPhotoIds.length} kullanılmadı'),
    ('Tema', b.themeId),
    ('Yazı tipi', vm.textAppearance.name),
    ('Fiyat', formatPrice(p.totalPrice(b.pageCount, b.options))),
  ];
  return showModalBottomSheet(
    context: context,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(S.aboutBook, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 12),
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                SizedBox(width: 90, child: Text(k, style: TextStyle(color: context.mutedText))),
                Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
              ]),
            ),
        ]),
      ),
    ),
  );
}
