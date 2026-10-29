import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/catalog.dart';
import '../../models/photo_book.dart';
import 'sheets/font_sheet.dart';

/// Metin düzenleyicinin sonucu: metin, stil (boyut), hizalama, (varsa) özel yazı tipi ve sayfadaki konum.
class TextEditValue {
  final String text;
  final TextStyleId style;
  final TextAlign align;
  final String? fontId;
  final bool top;
  final TextVAlign valign;

  const TextEditValue({
    required this.text,
    this.style = TextStyleId.body,
    this.align = TextAlign.left,
    this.fontId,
    this.top = false,
    this.valign = TextVAlign.top,
  });
}

/// Tam ekran metin düzenleyici (Popsa TextEditorActivity): geri al/yinele, yazı tipi (Aa),
/// metin stili (AA), hizalama, silme ve karakter sayacı.
/// Popsa sınır aşılınca kaydetmeyi engeller; burada kaydedilir, altta yalnızca taşma uyarısı gösterilir.
class TextEditorScreen extends StatefulWidget {
  const TextEditorScreen({
    super.key,
    required this.title,
    required this.initial,
    required this.fonts,
    required this.bookFontId,
    this.styles = TextStyleId.values,
    this.pageHeightCm = 21,
    this.showPosition = false,
    this.showVAlign = false,
    this.limit,
    this.hint = 'Sayfanda fotoğrafların altında ya da üstünde görünecek bir metin yaz',
  });

  final String title;
  final TextEditValue initial;
  final List<TextAppearance> fonts;
  final String bookFontId;
  final List<TextStyleId> styles;
  final double pageHeightCm; // stil listesinde baskı punto boyutunu hesaplamak için
  final bool showPosition; // üstte/altta seçimi (sayfa yazısı)
  final bool showVAlign; // alan içinde üst/orta/alt (şablon yazı alanı)
  final int? limit; // verilirse stil sınırının yerine geçer (ör. yazılı şablon alanı 600)
  final String hint;

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  late final _controller = TextEditingController(text: widget.initial.text);
  late TextStyleId _style = widget.initial.style;
  late TextAlign _align = widget.initial.align;
  late String? _fontId = widget.initial.fontId;
  late bool _top = widget.initial.top;
  late TextVAlign _valign = widget.initial.valign;
  final _undo = <String>[];
  final _redo = <String>[];
  late String _last = widget.initial.text;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (_controller.text == _last) return;
    _undo.add(_last);
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
    _last = _controller.text;
    setState(() {});
  }

  void _restore(String text) {
    _last = text;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextAppearance get _font =>
      widget.fonts.firstWhere((f) => f.id == (_fontId ?? widget.bookFontId), orElse: () => widget.fonts.first);

  int get _length => _controller.text.trim().length;

  int get _limit => widget.limit ?? _style.charLimit;

  bool get _over => _length > _limit;

  void _save() => Navigator.pop(
        context,
        TextEditValue(
          text: _controller.text,
          style: _style,
          align: _align,
          fontId: _fontId,
          top: _top,
          valign: _valign,
        ),
      );

  /// Stilin baskıdaki yaklaşık punto boyutu.
  int _points(TextStyleId s) => (s.sizeFactor * widget.pageHeightCm / 2.54 * 72).round();

  Future<void> _pickStyle() async {
    final picked = await showDialog<TextStyleId>(
      context: context,
      barrierColor: Colors.black54,
      builder: (c) => Dialog(
        backgroundColor: context.isDark ? const Color(0xFF2E2E2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
              child: Text(
                S.textStyles,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w500, color: c.strongText),
              ),
            ),
            Divider(height: 1, indent: 24, endIndent: 24, color: c.divider),
            const SizedBox(height: 8),
            for (final s in widget.styles)
              Material(
                color: s == _style
                    ? (c.isDark ? const Color(0xFF444444) : const Color(0xFFEDEDED))
                    : Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(c, s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          s.label,
                          style: TextStyle(
                            fontFamily: s.heading ? _font.titleFont : _font.bodyFont,
                            fontWeight: s.heading ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 16 + s.sizeFactor * 140,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_points(s)} pt',
                          style: TextStyle(fontSize: 14, color: c.mutedText.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _style = picked);
  }

  Future<void> _pickFont() async {
    final id = await pickFont(context, fonts: widget.fonts, selectedId: _fontId ?? widget.bookFontId);
    if (id != null) setState(() => _fontId = id == widget.bookFontId ? null : id);
  }

  void _cycleAlign() => setState(() {
    _align = switch (_align) {
      TextAlign.left => TextAlign.center,
      TextAlign.center => TextAlign.right,
      _ => TextAlign.left,
    };
  });

  @override
  Widget build(BuildContext context) {
    final font = _font;
    final heading = _style.heading;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: context.pillColor,
                foregroundColor: context.strongText,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _save,
              child: const Text(S.save),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: null,
                  textAlign: _align,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontFamily: heading ? font.titleFont : font.bodyFont,
                    fontWeight: heading ? font.titleWeight : FontWeight.w400,
                    fontSize: 14 + _style.sizeFactor * 260,
                    height: 1.3,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: TextStyle(color: context.mutedText.withValues(alpha: 0.6), fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
          if (_over)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.failure),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      S.textOverflowHint,
                      style: const TextStyle(color: AppColors.failure, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 20, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: _undo.isEmpty
                      ? null
                      : () {
                          _redo.add(_controller.text);
                          _restore(_undo.removeLast());
                        },
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  onPressed: _redo.isEmpty
                      ? null
                      : () {
                          _undo.add(_controller.text);
                          _restore(_redo.removeLast());
                        },
                  icon: const Icon(Icons.redo),
                ),
                const Spacer(),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$_length',
                        style: TextStyle(
                          color: _over ? AppColors.failure : context.strongText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: ' / $_limit',
                        style: TextStyle(color: context.mutedText),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  _ToolButton(
                    tooltip: S.font,
                    onTap: _pickFont,
                    child: Text(
                      'Aa',
                      style: TextStyle(fontFamily: font.titleFont, fontSize: 22, fontWeight: font.titleWeight),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ToolButton(
                    tooltip: S.textStyles,
                    onTap: _pickStyle,
                    child: const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'A', style: TextStyle(fontSize: 15)),
                          TextSpan(text: 'A', style: TextStyle(fontSize: 22)),
                        ],
                      ),
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ToolButton(
                    tooltip: S.alignment,
                    onTap: _cycleAlign,
                    child: Icon(switch (_align) {
                      TextAlign.left => Icons.format_align_left,
                      TextAlign.right => Icons.format_align_right,
                      _ => Icons.format_align_center,
                    }),
                  ),
                  if (widget.showVAlign) ...[
                    const SizedBox(width: 12),
                    _ToolButton(
                      tooltip: S.verticalPosition,
                      onTap: () => setState(() {
                        _valign = TextVAlign.values[(_valign.index + 1) % TextVAlign.values.length];
                      }),
                      child: Icon(switch (_valign) {
                        TextVAlign.top => Icons.vertical_align_top,
                        TextVAlign.center => Icons.vertical_align_center,
                        TextVAlign.bottom => Icons.vertical_align_bottom,
                      }),
                    ),
                  ],
                  if (widget.showPosition) ...[
                    const SizedBox(width: 12),
                    _ToolButton(
                      tooltip: _top ? S.positionTop : S.positionBottom,
                      onTap: () => setState(() => _top = !_top),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_top ? Icons.vertical_align_top : Icons.vertical_align_bottom, size: 22),
                          Text(_top ? S.positionTop : S.positionBottom, style: const TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  _ToolButton(tooltip: S.delete, onTap: _controller.clear, child: const Icon(Icons.delete_outline)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.child, required this.onTap, required this.tooltip});

  final Widget child;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: context.pillColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(width: 56, height: 56, child: Center(child: child)),
        ),
      ),
    );
  }
}
