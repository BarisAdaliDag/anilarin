import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/catalog.dart';

/// Tam ekran metin düzenleyici (Popsa TextEditorActivity): karakter sayacı, hizalama ve silme.
class TextEditorScreen extends StatefulWidget {
  const TextEditorScreen({
    super.key,
    required this.title,
    required this.initial,
    required this.limit,
    required this.font,
    this.hint = 'Tasarımında fotoğrafların altında görünecek bir metin yaz',
  });

  final String title;
  final String initial;
  final int limit;
  final TextAppearance font;
  final String hint;

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  late final _controller = TextEditingController(text: widget.initial);
  TextAlign _align = TextAlign.center;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              style: TextButton.styleFrom(backgroundColor: context.pillColor, foregroundColor: context.strongText),
              onPressed: () => Navigator.pop(context, _controller.text),
              child: const Text(S.save),
            ),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLength: widget.limit,
                maxLines: null,
                textAlign: _align,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontFamily: widget.font.bodyFont, fontSize: 22, height: 1.35),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: widget.hint,
                  hintStyle: TextStyle(color: context.mutedText.withValues(alpha: 0.6), fontSize: 16),
                  counterText: '',
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 16, 8),
          child: Row(children: [
            for (final (a, icon) in const [
              (TextAlign.left, Icons.format_align_left),
              (TextAlign.center, Icons.format_align_center),
              (TextAlign.right, Icons.format_align_right),
            ])
              IconButton(
                isSelected: _align == a,
                selectedIcon: Icon(icon, color: AppColors.accent),
                onPressed: () => setState(() => _align = a),
                icon: Icon(icon),
              ),
            IconButton(onPressed: _controller.clear, icon: const Icon(Icons.delete_outline)),
            const Spacer(),
            Text('${_controller.text.length} / ${widget.limit}', style: TextStyle(color: context.mutedText)),
          ]),
        ),
      ]),
    );
  }
}
