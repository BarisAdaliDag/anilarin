import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../constants/strings_tr.dart';
import '../../../models/catalog.dart';
import '../../../models/photo_book.dart';
import '../../../view_model/editor_view_model.dart';
import '../../widgets/print_page_view.dart';
import '../text_editor_screen.dart';

/// Kapak başlığı ve alt başlığı: metin düzenleyicide boyut, yazı tipi, hizalama ve dikey konumla.
Future<void> editTitleDialog(BuildContext context, EditorViewModel vm) async {
  final cover = vm.book.cover;
  final current =
      cover.textStyles[0] ??
      TextSlotStyle(style: TextStyleId.heading3, align: TextAlign.center, valign: TextVAlign.center);
  final result = await Navigator.of(context).push<TextEditValue>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => TextEditorScreen(
        title: S.editTitle,
        initial: TextEditValue(
          text: vm.book.title,
          subtitle: vm.book.subtitle,
          style: current.style,
          align: current.align,
          valign: current.valign,
          fontId: current.font,
        ),
        styles: const [
          TextStyleId.heading2,
          TextStyleId.heading3,
          TextStyleId.heading4,
          TextStyleId.subheading1,
          TextStyleId.subheading2,
        ],
        limit: 40,
        showVAlign: true,
        pageHeightCm: vm.pageHeightCm,
        fonts: vm.catalog.textAppearances,
        bookFontId: vm.book.textAppearanceId,
        hint: S.titleHint,
      ),
    ),
  );
  if (result == null) return;
  vm.setTitle(
    result.text,
    result.subtitle ?? vm.book.subtitle,
    style: TextSlotStyle(style: result.style, align: result.align, valign: result.valign, font: result.fontId),
  );
}

/// Sayfaya yazı ekler/düzenler. Düzeni bozmaz: yazı sayfanın altında ya da üstünde şerit olarak durur.
Future<void> editCaptionFlow(BuildContext context, EditorViewModel vm, int pageIndex) async {
  final page = vm.book.pages[pageIndex];
  final result = await Navigator.of(context).push<TextEditValue>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => TextEditorScreen(
        title: page.caption.isEmpty ? S.addCaption : S.editCaption,
        initial: TextEditValue(
          text: page.caption,
          style: page.captionStyle,
          align: page.captionAlign,
          fontId: page.captionFont,
          top: page.captionTop,
        ),
        fonts: vm.catalog.textAppearances,
        bookFontId: vm.book.textAppearanceId,
        pageHeightCm: vm.pageHeightCm,
        showPosition: true,
      ),
    ),
  );
  if (result == null) return;
  vm.setPageCaption(
    pageIndex,
    result.text,
    style: result.style,
    align: result.align,
    font: result.fontId,
    clearFont: result.fontId == null,
    top: result.top,
  );
}

/// Şablonun kendi yazı alanını düzenler (yazılı şablonlar, Popsa "Edit Text"); -1 sayfa yazısıdır.
Future<void> editCaptionDialog(BuildContext context, EditorViewModel vm, int pageIndex, int textIndex) async {
  if (textIndex < 0) return editCaptionFlow(context, vm, pageIndex);
  final page = vm.book.pages[pageIndex];
  final slots = vm.templateOf(pageIndex).textSlots(vm.format);
  if (textIndex >= slots.length) return;
  final slot = slots[textIndex];
  final isTitle = slot.role == 'title';
  final current = page.textStyles[textIndex] ?? defaultSlotStyle(slot);
  final result = await Navigator.of(context).push<TextEditValue>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => TextEditorScreen(
        title: textIndex < page.texts.length && page.texts[textIndex].isNotEmpty ? S.editText : S.addText,
        initial: TextEditValue(
          text: textIndex < page.texts.length ? page.texts[textIndex] : '',
          style: current.style,
          align: current.align,
          fontId: current.font,
          valign: current.valign,
        ),
        limit: isTitle ? 40 : 600,
        showVAlign: true,
        pageHeightCm: vm.pageHeightCm,
        fonts: vm.catalog.textAppearances,
        bookFontId: vm.book.textAppearanceId,
        hint: 'Bu alanda görünecek metni yaz',
      ),
    ),
  );
  if (result == null) return;
  vm.setCaption(
    pageIndex,
    textIndex,
    result.text,
    style: TextSlotStyle(style: result.style, align: result.align, valign: result.valign, font: result.fontId),
  );
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(S.aboutBook, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 12),
            for (final (k, v) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(k, style: TextStyle(color: context.mutedText)),
                    ),
                    Expanded(
                      child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
