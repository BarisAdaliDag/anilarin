import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../view_model/editor_view_model.dart';
import '../editor/editor_screen.dart' show buyBook;
import '../widgets/print_page_view.dart';

/// Kitap önizlemesi: sayfa çevirme animasyonlu karşılıklı sayfalar (Popsa'daki 3D Unity önizlemenin 2D karşılığı).
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final _controller = PageController();
  double _page = 0;
  Color _bg = const Color(0xFFE8E2D9);
  static const _backgrounds = [
    Color(0xFFE8E2D9),
    Color(0xFFFFFFFF),
    Color(0xFFDDE7EA),
    Color(0xFF3A3A3A),
    Color(0xFF8D6E63),
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _page = _controller.page ?? 0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditorViewModel>();
    final book = vm.book;
    // [kapak], [1,2], [3,4], ...
    final spreads = <List<int>>[
      [0],
      for (var i = 1; i < book.pages.length; i += 2) [i, if (i + 1 < book.pages.length) i + 1],
    ];
    final dark = _bg.computeLuminance() < 0.4;
    final fg = dark ? Colors.white : AppColors.textStrong;
    final current = _page.round().clamp(0, spreads.length - 1);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: fg,
        title: Text(book.title, style: TextStyle(color: fg)),
      ),
      body: Column(children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: spreads.length,
            itemBuilder: (context, i) {
              final delta = (i - _page).clamp(-1.0, 1.0);
              return Transform(
                alignment: delta > 0 ? Alignment.centerLeft : Alignment.centerRight,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(-delta * pi / 2.6),
                child: Opacity(
                  opacity: (1 - delta.abs() * 0.6).clamp(0.0, 1.0),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _SpreadView(vm: vm, pages: spreads[i]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Text(
          current == 0 ? S.cover : spreads[current].map((p) => '$p').join(' – '),
          style: TextStyle(color: fg, fontWeight: FontWeight.w600),
        ),
        Slider(
          value: _page.clamp(0, (spreads.length - 1).toDouble()),
          max: max(1, spreads.length - 1).toDouble(),
          activeColor: AppColors.accent,
          onChanged: (v) => _controller.jumpToPage(v.round()),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(S.background, style: TextStyle(color: fg)),
          const SizedBox(width: 12),
          for (final c in _backgrounds)
            GestureDetector(
              onTap: () => setState(() => _bg = c),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(color: c == _bg ? AppColors.accent : Colors.black26, width: c == _bg ? 3 : 1),
                ),
              ),
            ),
        ]),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: fg),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Düzenle'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: () => buyBook(context, vm), child: const Text(S.buy))),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _SpreadView extends StatelessWidget {
  const _SpreadView({required this.vm, required this.pages});

  final EditorViewModel vm;
  final List<int> pages;

  @override
  Widget build(BuildContext context) {
    final isCover = pages.length == 1 && pages.first == 0;
    final aspect = vm.product.aspect;
    final width = isCover ? aspect : aspect * 2;
    return AspectRatio(
      aspectRatio: width,
      child: FractionallySizedBox(
        widthFactor: isCover ? 0.8 : 1,
        child: Container(
          decoration: const BoxDecoration(
            boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 18, offset: Offset(0, 10))],
          ),
          child: Row(children: [
            for (var k = 0; k < (isCover ? 1 : 2); k++)
              Expanded(
                child: k < pages.length
                    ? Stack(children: [
                        PrintPageView(book: vm.book, pageIndex: pages[k], catalog: vm.catalog, thumbSize: 900),
                        if (!isCover)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: k == 0 ? Alignment.centerRight : Alignment.centerLeft,
                                    end: k == 0 ? Alignment.centerLeft : Alignment.centerRight,
                                    colors: const [Color(0x33000000), Color(0x00000000)],
                                    stops: const [0, 0.12],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ])
                    : const ColoredBox(color: Colors.white),
              ),
          ]),
        ),
      ),
    );
  }
}
