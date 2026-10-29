import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../constants/strings_tr.dart';
import '../../../view_model/editor_view_model.dart';
import '../../widgets/print_page_view.dart';

/// Sayfaları sürükleyerek yeniden sırala (Popsa ReArrangePagesActivity).
///
/// Sayfalar Popsa'daki gibi açık kitap düzeninde durur: ilk satır "Boş Sayfa | Sayfa 1",
/// sonra 2|3, 4|5... Bir sayfa basılı tutulunca büyüyüp parmağı izler; üzerinden geçtiği
/// konuma girer ve aradaki sayfalar birer kayar.
class RearrangePagesScreen extends StatefulWidget {
  const RearrangePagesScreen({super.key});

  @override
  State<RearrangePagesScreen> createState() => _RearrangePagesScreenState();
}

class _RearrangePagesScreenState extends State<RearrangePagesScreen> {
  static const _side = 20.0;
  static const _labelHeight = 44.0;
  static const _rowGap = 34.0;
  static const _edge = 90.0;

  late final List<String> _initial = context.read<EditorViewModel>().book.innerPages.map((p) => p.id).toList();
  late List<String> _order = [..._initial];
  final _scroll = ScrollController();
  final _stackKey = GlobalKey();
  final _viewportKey = GlobalKey();

  String? _dragging;
  String? _settling;
  Offset _grab = Offset.zero;
  Offset _dragTopLeft = Offset.zero;
  Offset? _lastGlobal;
  Timer? _autoScroll;
  Timer? _settleTimer;

  Size _page = Size.zero;
  (int, int) _rows = (0, 6);

  bool get _changed => !listEquals(_order, _initial);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateVisibleRows);
  }

  @override
  void dispose() {
    _autoScroll?.cancel();
    _settleTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  // Konum 0 boş iç kapak, 1..n sayfalar.
  Rect _slotRect(int slot) {
    final row = slot ~/ 2;
    final top = row * (_labelHeight + _page.height + _rowGap) + _labelHeight;
    return Offset(_side + (slot.isOdd ? _page.width : 0), top) & _page;
  }

  int _rowOf(double y) => (y / (_labelHeight + _page.height + _rowGap)).floor();

  RenderBox? _box(GlobalKey key) => key.currentContext?.findRenderObject() as RenderBox?;

  /// Ekranda görünen satırlar (± bir ekran); yalnız bunlar çizilir.
  void _updateVisibleRows() {
    final stack = _box(_stackKey), viewport = _box(_viewportKey);
    if (stack == null || viewport == null || _page.isEmpty) return;
    final top = stack.globalToLocal(viewport.localToGlobal(Offset.zero)).dy;
    final h = viewport.size.height;
    final rows = (_rowOf(top - h), _rowOf(top + 2 * h));
    if (rows != _rows) setState(() => _rows = rows);
  }

  void _start(String id, LongPressStartDetails d) {
    final stack = _box(_stackKey);
    if (stack == null) return;
    HapticFeedback.mediumImpact();
    _settleTimer?.cancel();
    final home = _slotRect(_order.indexOf(id) + 1);
    final local = stack.globalToLocal(d.globalPosition);
    setState(() {
      _dragging = id;
      _settling = null;
      _grab = local - home.topLeft;
      _dragTopLeft = home.topLeft;
    });
    _lastGlobal = d.globalPosition;
    _autoScroll = Timer.periodic(const Duration(milliseconds: 16), (_) => _tickAutoScroll());
  }

  void _move(LongPressMoveUpdateDetails d) {
    _lastGlobal = d.globalPosition;
    _follow();
  }

  /// Sürüklenen sayfayı parmağa taşır ve merkezine en yakın konuma yerleştirir.
  void _follow() {
    final stack = _box(_stackKey), global = _lastGlobal, id = _dragging;
    if (stack == null || global == null || id == null) return;
    final topLeft = stack.globalToLocal(global) - _grab;
    final center = (topLeft & _page).center;
    var target = 1;
    var best = double.infinity;
    for (var slot = 1; slot <= _order.length; slot++) {
      final dist = (_slotRect(slot).center - center).distanceSquared;
      if (dist < best) {
        best = dist;
        target = slot;
      }
    }
    final order = EditorViewModel.movedOrder(_order, id, target - 1);
    if (!listEquals(order, _order)) HapticFeedback.selectionClick();
    setState(() {
      _dragTopLeft = topLeft;
      _order = order;
    });
  }

  void _tickAutoScroll() {
    final viewport = _box(_viewportKey), global = _lastGlobal;
    if (viewport == null || global == null || !_scroll.hasClients) return;
    final y = viewport.globalToLocal(global).dy;
    final h = viewport.size.height;
    final speed = y < _edge ? -(1 - y / _edge) * 14 : (y > h - _edge ? (1 - (h - y) / _edge) * 14 : 0.0);
    if (speed == 0) return;
    final pos = _scroll.position;
    final next = (pos.pixels + speed).clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if (next == pos.pixels) return;
    _scroll.jumpTo(next);
    _follow();
  }

  void _end() {
    _autoScroll?.cancel();
    _lastGlobal = null;
    final id = _dragging;
    setState(() {
      _dragging = null;
      _settling = id;
    });
    _settleTimer = Timer(const Duration(milliseconds: 320), () {
      if (mounted) setState(() => _settling = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<EditorViewModel>();
    final indexById = {for (var i = 0; i < vm.book.pages.length; i++) vm.book.pages[i].id: i};
    final slots = _order.length + 1 + (_order.length + 1).isOdd.toInt();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: const Text(S.rearrangeTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _changed
                  ? () {
                      vm.reorderInner(_order);
                      Navigator.pop(context);
                    }
                  : null,
              child: const Text(S.save),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final pageWidth = (c.maxWidth - 2 * _side) / 2;
          _page = Size(pageWidth, pageWidth / vm.product.aspect);
          final rowCount = slots ~/ 2;
          final height = rowCount * (_labelHeight + _page.height + _rowGap);
          final (firstRow, lastRow) = _rows;
          bool visible(int slot) => slot ~/ 2 >= firstRow && slot ~/ 2 <= lastRow;
          final labelStyle = TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: context.mutedText);

          Widget page(String id, int slot) {
            final lifted = id == _dragging;
            final rect = lifted ? _dragTopLeft & _page : _slotRect(slot);
            return AnimatedPositioned.fromRect(
              key: ValueKey(id),
              rect: rect,
              duration: lifted ? Duration.zero : const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: RawGestureDetector(
                gestures: {
                  LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                    () => LongPressGestureRecognizer(duration: const Duration(milliseconds: 250)),
                    (r) => r
                      ..onLongPressStart = ((d) => _start(id, d))
                      ..onLongPressMoveUpdate = _move
                      ..onLongPressEnd = ((_) => _end())
                      ..onLongPressCancel = () {
                        if (_dragging == id) _end();
                      },
                  ),
                },
                child: AnimatedScale(
                  scale: lifted ? 1.25 : 1,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      boxShadow: [
                        if (lifted) const BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 10)),
                      ],
                    ),
                    child: ClipRect(
                      child: PrintPageView(
                        book: vm.book,
                        pageIndex: indexById[id]!,
                        catalog: vm.catalog,
                        thumbSize: 300,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          final pages = [
            for (var i = 0; i < _order.length; i++)
              if (_order[i] != _dragging && _order[i] != _settling && visible(i + 1)) page(_order[i], i + 1),
            // Sürüklenen (ya da yerine oturan) sayfa en üstte çizilir.
            for (final id in [_settling, _dragging])
              if (id != null && _order.contains(id)) page(id, _order.indexOf(id) + 1),
          ];

          return SingleChildScrollView(
            key: _viewportKey,
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(_side, 4, _side, 20),
                  child: Text(S.rearrangeHint, style: TextStyle(fontSize: 16, height: 1.45, color: context.mutedText)),
                ),
                SizedBox(
                  key: _stackKey,
                  height: height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var slot = 0; slot < slots; slot++)
                        if (visible(slot)) ...[
                          Positioned(
                            left: _slotRect(slot).left,
                            width: _page.width,
                            top: _slotRect(slot).top - _labelHeight,
                            height: _labelHeight,
                            child: Align(
                              alignment: slot.isOdd ? Alignment.centerRight : Alignment.centerLeft,
                              child: Text(
                                slot == 0 || slot > _order.length ? S.blankPage : S.pageN(slot),
                                style: labelStyle,
                              ),
                            ),
                          ),
                          if (slot == 0 || slot > _order.length)
                            Positioned.fromRect(
                              rect: _slotRect(slot),
                              child: const ColoredBox(color: Color(0xFFF7F7F7)),
                            ),
                        ],
                      ...pages,
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

extension on bool {
  int toInt() => this ? 1 : 0;
}

/// Kaldırılacak sayfaları seç (Popsa RemovePagesActivity).
class RemovePagesScreen extends StatefulWidget {
  const RemovePagesScreen({super.key});

  @override
  State<RemovePagesScreen> createState() => _RemovePagesScreenState();
}

class _RemovePagesScreenState extends State<RemovePagesScreen> {
  final _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditorViewModel>();
    final removable = vm.book.pageCount - vm.product.pagesMin;
    return Scaffold(
      appBar: AppBar(title: const Text(S.removePages)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(S.minPagesWarning(vm.product.pagesMin), style: TextStyle(color: context.mutedText)),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: vm.book.pages.length - 1,
              itemBuilder: (_, i) {
                final index = i + 1;
                final selected = _selected.contains(index);
                final disabled = !selected && _selected.length >= removable;
                return GestureDetector(
                  onTap: disabled
                      ? null
                      : () => setState(() => selected ? _selected.remove(index) : _selected.add(index)),
                  child: Opacity(
                    opacity: disabled ? 0.4 : 1,
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            DecoratedBox(
                              position: DecorationPosition.foreground,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: selected ? AppColors.failure : context.divider,
                                  width: selected ? 3 : 1,
                                ),
                              ),
                              child: PrintPageView(
                                book: vm.book,
                                pageIndex: index,
                                catalog: vm.catalog,
                                thumbSize: 200,
                              ),
                            ),
                            if (selected)
                              const Positioned(
                                top: 4,
                                right: 4,
                                child: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: AppColors.failure,
                                  child: Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(S.pageN(index), style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.failure),
                onPressed: _selected.isEmpty
                    ? null
                    : () {
                        if (vm.removePages(_selected)) Navigator.pop(context);
                      },
                child: Text(S.removePagesN(_selected.length)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
