import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/catalog.dart';
import '../../models/photo_book.dart';
import '../../services/auto_layout_service.dart';
import '../../services/palette_service.dart';
import '../../view_model/app_view_model.dart';
import '../editor/editor_screen.dart';

/// Başlık ve alt başlık; ardından kitap otomatik tasarlanır (Popsa CreatePrintTitleActivity).
class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key, required this.product, required this.options, required this.photos});

  final Product product;
  final ProductOptions options;
  final List<BookPhoto> photos;

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  final _title = TextEditingController();
  late final _subtitle = TextEditingController(text: AutoLayoutService.dateRangeLabel(widget.photos));
  late final List<String> _suggestions = AutoLayoutService.titleSuggestions(widget.photos);
  bool _designing = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    FocusScope.of(context).unfocus();
    setState(() => _designing = true);
    final app = context.read<AppViewModel>();
    final navigator = Navigator.of(context);
    final started = DateTime.now();
    final sorted = AutoLayoutService.sortPhotos(widget.photos);
    final palette = await PaletteService.forPhotos(sorted.map((p) => p.id).toList());
    final book = AutoLayoutService(app.catalog!).create(
      product: widget.product,
      photos: widget.photos,
      title: _title.text.trim().isEmpty ? S.defaultTitle : _title.text.trim(),
      subtitle: _subtitle.text.trim(),
      options: widget.options,
      palette: palette,
    );
    // Tasarım ekranı bir an görünsün.
    final wait = const Duration(milliseconds: 1400) - DateTime.now().difference(started);
    if (!wait.isNegative) await Future<void>.delayed(wait);
    await app.saveBook(book);
    app.setTab(0);
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => EditorScreen(bookId: book.id, firstCreation: true)),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_designing) return const _DesigningView();
    final dateLabel = AutoLayoutService.dateRangeLabel(widget.photos);
    return Scaffold(
      appBar: AppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _create,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text(S.create),
            ),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        TextField(
          controller: _title,
          autofocus: true,
          maxLength: 40,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w500, height: 1.25),
          decoration: InputDecoration(
            hintText: S.enterTitle,
            hintStyle: TextStyle(color: context.mutedText.withValues(alpha: 0.6)),
            border: InputBorder.none,
            counterText: '',
          ),
        ),
        TextField(
          controller: _subtitle,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(fontSize: 16, color: context.mutedText),
          decoration: InputDecoration(
            hintText: S.subtitleHint,
            hintStyle: TextStyle(color: context.mutedText.withValues(alpha: 0.6)),
            border: InputBorder.none,
            counterText: '',
          ),
        ),
        const SizedBox(height: 24),
        Text(S.suggestions.toUpperCase(), style: TextStyle(fontSize: 12, letterSpacing: 1.4, color: context.mutedText)),
        const SizedBox(height: 4),
        for (final s in _suggestions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.auto_stories_outlined),
            title: Text(s),
            subtitle: dateLabel.isEmpty ? null : Text(dateLabel, style: TextStyle(color: context.mutedText)),
            trailing: Icon(Icons.more_horiz, color: context.mutedText),
            onTap: () => _title.text = s,
          ),
      ]),
    );
  }
}

class _DesigningView extends StatelessWidget {
  const _DesigningView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 5)),
          SizedBox(height: 24),
          Text(S.designingLayout, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
