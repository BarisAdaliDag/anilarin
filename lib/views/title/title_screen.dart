import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/catalog.dart';
import '../../models/photo_book.dart';
import '../../services/auto_layout_service.dart';
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
  final _subtitle = TextEditingController();
  late final List<String> _suggestions = AutoLayoutService.titleSuggestions(widget.photos);
  bool _designing = false;

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
    // Tasarım animasyonu görünsün diye kısa bir bekleme; yerleşimin kendisi anlık.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final book = AutoLayoutService(app.catalog!).create(
      product: widget.product,
      photos: widget.photos,
      title: _title.text.trim().isEmpty ? S.defaultTitle : _title.text.trim(),
      subtitle: _subtitle.text.trim(),
      options: widget.options,
    );
    await app.saveBook(book);
    app.setTab(1);
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => EditorScreen(bookId: book.id, firstCreation: true)),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_designing) return const _DesigningView();
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: _create,
            child: const Text(S.next, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent)),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 32), children: [
        const Text(S.enterTitle, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        TextField(
          controller: _title,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(hintText: S.titleHint),
          onSubmitted: (_) => _create(),
        ),
        TextField(
          controller: _subtitle,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: S.subtitleHint),
        ),
        const SizedBox(height: 16),
        const Text(S.suggestions, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        for (final s in _suggestions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lightbulb_outline, color: AppColors.accent),
            title: Text(s),
            onTap: () => setState(() => _title.text = s),
          ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _create, child: const Text(S.next)),
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
          Text(S.designingLayout, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
