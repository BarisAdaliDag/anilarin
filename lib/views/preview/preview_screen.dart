import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../view_model/editor_view_model.dart';
import '../editor/editor_screen.dart' show buyBook;
import '../widgets/print_page_view.dart';

/// [kapak], [boş, 1], [2, 3], ... — Popsa'daki gibi ilk iç sayfa sağda açılır. -1 boş sayfadır.
List<List<int>> bookSpreads(int pageCount) {
  final inner = [-1, for (var i = 1; i < pageCount; i++) i];
  if (inner.length.isOdd) inner.add(-1);
  return [
    [0],
    for (var i = 0; i < inner.length; i += 2) [inner[i], inner[i + 1]],
  ];
}

/// Kitap önizlemesi: sayfa çevirme animasyonlu karşılıklı sayfalar (Popsa'daki 3D Unity önizlemenin 2D karşılığı).
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final _controller = PageController();
  double _page = 0;

  // Popsa "Background Colours": Tema, Nötr ve iki sıra renk (canlı / açık tonlar).
  static const _theme = Color(0xFF5F5F5F);
  static const _neutral = Color(0xFFCFCFCF);
  static const _vivid = [
    Color(0xFFE53935),
    Color(0xFFC2185B),
    Color(0xFF8E24AA),
    Color(0xFF5E35B1),
    Color(0xFF3949AB),
    Color(0xFF1E88E5),
    Color(0xFF039BE5),
    Color(0xFF00ACC1),
    Color(0xFF00897B),
    Color(0xFF43A047),
    Color(0xFF7CB342),
    Color(0xFFFDD835),
    Color(0xFFFB8C00),
    Color(0xFF6D4C41),
  ];
  static const _pale = [
    Color(0xFFFFEBEE),
    Color(0xFFFCE4EC),
    Color(0xFFF3E5F5),
    Color(0xFFEDE7F6),
    Color(0xFFE8EAF6),
    Color(0xFFE3F2FD),
    Color(0xFFE1F5FE),
    Color(0xFFE0F7FA),
    Color(0xFFE0F2F1),
    Color(0xFFE8F5E9),
    Color(0xFFF1F8E9),
    Color(0xFFFFFDE7),
    Color(0xFFFFF3E0),
    Color(0xFFEFEBE9),
  ];
  Color _bg = _theme;

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

  String _label(List<int> spread) {
    if (spread.length == 1) return S.cover;
    final pages = spread.where((p) => p > 0).toList();
    return pages.length == 1 ? S.pageN(pages.first) : '${S.pageN(pages.first)} – ${pages.last}';
  }

  void _pickBackground() {
    showModalBottomSheet<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) {
          void pick(Color color) {
            setState(() => _bg = color);
            setSheet(() {});
          }

          Widget swatch(Color color, {String? label}) {
            final selected = color == _bg;
            final dark = color.computeLuminance() < 0.5;
            return GestureDetector(
              onTap: () => pick(color),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: selected ? 3 : 2),
                      ),
                      child: selected
                          ? Icon(Icons.check, color: dark ? Colors.white : AppColors.textStrong, size: 24)
                          : null,
                    ),
                    if (label != null) ...[
                      const SizedBox(height: 6),
                      Text(label, style: const TextStyle(fontSize: 13)),
                    ],
                  ],
                ),
              ),
            );
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(S.backgroundColours, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        swatch(_theme, label: S.themeBackground),
                        swatch(_neutral, label: S.neutral),
                        Container(
                          width: 1,
                          height: 46,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: c.divider,
                        ),
                        Column(
                          children: [
                            Row(children: [for (final color in _vivid) swatch(color)]),
                            const SizedBox(height: 16),
                            Row(children: [for (final color in _pale) swatch(color)]),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditorViewModel>();
    final spreads = bookSpreads(vm.book.pages.length);
    final dark = _bg.computeLuminance() < 0.4;
    final fg = dark ? Colors.white : AppColors.textStrong;
    final current = _page.round().clamp(0, spreads.length - 1);

    return AnnotatedRegion(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: _bg),
        duration: const Duration(milliseconds: 300),
        builder: (context, bg, child) => Scaffold(backgroundColor: bg, body: child),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: IconButton(
                    icon: Icon(Icons.close, color: fg, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
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
                _label(spreads[current]),
                style: TextStyle(color: fg, fontWeight: FontWeight.w600),
              ),
              if (spreads.length > 2)
                Slider(
                  value: _page.clamp(0, (spreads.length - 1).toDouble()),
                  max: (spreads.length - 1).toDouble(),
                  activeColor: fg,
                  inactiveColor: fg.withValues(alpha: 0.25),
                  onChanged: (v) => _controller.jumpToPage(v.round()),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RoundButton(icon: Icons.palette_outlined, onTap: _pickBackground),
                    _RoundButton(icon: Icons.shopping_cart_outlined, large: true, onTap: () => buyBook(context, vm)),
                    _RoundButton(icon: Icons.edit_outlined, onTap: () => Navigator.pop(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Popsa önizlemesindeki beyaz yuvarlak düğmeler.
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, this.large = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 76.0 : 64.0;
    return Material(
      color: Colors.white,
      shape: CircleBorder(side: large ? const BorderSide(color: Color(0xFFDDDDDD), width: 4) : BorderSide.none),
      elevation: 4,
      shadowColor: Colors.black38,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: AppColors.textStrong, size: large ? 30 : 28),
        ),
      ),
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
          child: Row(
            children: [
              for (var k = 0; k < (isCover ? 1 : 2); k++)
                Expanded(
                  child: k < pages.length && pages[k] >= 0
                      ? Stack(
                          children: [
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
                          ],
                        )
                      : const ColoredBox(color: Color(0xFFF7F7F7), child: SizedBox.expand()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
