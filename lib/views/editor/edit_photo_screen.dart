import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/photo_book.dart';
import '../../view_model/editor_view_model.dart';
import '../photo_picker/photo_picker_screen.dart';
import '../widgets/photo_image.dart';
import '../widgets/print_page_view.dart';

/// Fotoğraf düzenleme: kırp (sürükle/yakınlaştır), Doldur/Sığdır, Döndür, Değiştir, Kaldır
/// ve baskı kalitesi göstergesi (Popsa EditPhotoActivity).
class EditPhotoScreen extends StatefulWidget {
  const EditPhotoScreen({super.key, required this.ref});

  final SlotRef ref;

  @override
  State<EditPhotoScreen> createState() => _EditPhotoScreenState();
}

class _EditPhotoScreenState extends State<EditPhotoScreen> {
  late PhotoSlot _slot;
  double _startScale = 1;
  Offset _startFocal = Offset.zero;
  double _startDx = 0, _startDy = 0;

  @override
  void initState() {
    super.initState();
    final s = context.read<EditorViewModel>().slotAt(widget.ref)!;
    _slot = PhotoSlot.fromJson(s.toJson());
  }

  /// Baskıda alanın kapladığı yaklaşık inç başına nokta.
  int _dpi(EditorViewModel vm, BookPhoto photo, Size slotFraction) {
    final dims = vm.product.dimensionsCm.split('×').map((e) => double.tryParse(e.trim()) ?? 20).toList();
    final slotWidthInch = dims.first / 2.54 * slotFraction.width;
    final visible = _slot.fit ? 1.0 : 1 / _slot.scale;
    final px = (_slot.quarterTurns.isOdd ? photo.height : photo.width) * visible;
    return slotWidthInch <= 0 ? 300 : (px / slotWidthInch).round();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditorViewModel>();
    final photo = vm.photo(_slot.photoId);
    final tpl = vm.templateOf(widget.ref.page);
    final frame = tpl.photoSlots(vm.format)[widget.ref.slot].frame;
    final slotAspect = frame.width * vm.product.aspect / frame.height;
    final dpi = photo == null ? 300 : _dpi(vm, photo, Size(frame.width / 100, frame.height / 100));
    final (qLabel, qColor, qValue) = dpi >= 200
        ? (S.qualityGood, AppColors.success, 1.0)
        : dpi >= 120
            ? (S.qualityOk, AppColors.warning, 0.6)
            : (S.qualityPoor, AppColors.failure, 0.25);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        title: const Text(S.editPhoto, style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              vm.updateSlot(widget.ref, _slot);
              Navigator.pop(context);
            },
            child: const Text(S.save, style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(children: [
            const Text(S.photoQuality, style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1)),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: qValue, color: qColor, backgroundColor: Colors.white12, minHeight: 6),
              ),
            ),
            const SizedBox(width: 12),
            Text(qLabel, style: TextStyle(color: qColor, fontWeight: FontWeight.w700)),
          ]),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AspectRatio(
                aspectRatio: slotAspect,
                child: LayoutBuilder(builder: (context, c) {
                  final size = Size(c.maxWidth, c.maxHeight);
                  final r = photoRect(size, photo?.aspect ?? 1, _slot);
                  return GestureDetector(
                    onScaleStart: (d) {
                      _startScale = _slot.scale;
                      _startFocal = d.localFocalPoint;
                      _startDx = _slot.dx;
                      _startDy = _slot.dy;
                    },
                    onScaleUpdate: (d) => setState(() {
                      _slot.scale = (_startScale * d.scale).clamp(1.0, 4.0);
                      final cur = photoRect(size, photo?.aspect ?? 1, _slot);
                      final ox = max(1.0, (cur.width - size.width).abs() / 2);
                      final oy = max(1.0, (cur.height - size.height).abs() / 2);
                      final delta = d.localFocalPoint - _startFocal;
                      _slot.dx = (_startDx + delta.dx / ox).clamp(-1.0, 1.0);
                      _slot.dy = (_startDy + delta.dy / oy).clamp(-1.0, 1.0);
                    }),
                    child: ClipRect(
                      child: ColoredBox(
                        color: Colors.white,
                        child: Stack(children: [
                          Positioned.fromRect(
                            rect: r,
                            child: RotatedBox(
                              quarterTurns: _slot.quarterTurns % 4,
                              child: PhotoImage(photoId: _slot.photoId, size: 1400, fit: BoxFit.fill),
                            ),
                          ),
                          // üçte bir ızgarası
                          IgnorePointer(child: CustomPaint(size: size, painter: _GridPainter())),
                        ]),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _ToolButton(
                icon: Icons.crop_free,
                label: S.fill,
                active: !_slot.fit,
                onTap: () => setState(() {
                  _slot.fit = false;
                  _slot.resetCrop();
                }),
              ),
              _ToolButton(
                icon: Icons.fit_screen,
                label: S.fit,
                active: _slot.fit,
                onTap: () => setState(() {
                  _slot.fit = true;
                  _slot.resetCrop();
                }),
              ),
              _ToolButton(
                icon: Icons.rotate_90_degrees_cw_outlined,
                label: S.rotate,
                onTap: () => setState(() {
                  _slot.quarterTurns = (_slot.quarterTurns + 1) % 4;
                  _slot.resetCrop();
                }),
              ),
              _ToolButton(
                icon: Icons.swap_horiz,
                label: S.replace,
                onTap: () async {
                  final nav = Navigator.of(context);
                  final picked = await nav.push<List<BookPhoto>>(
                    MaterialPageRoute(builder: (_) => const PhotoPickerScreen(single: true)),
                  );
                  if (picked != null && picked.isNotEmpty) {
                    vm.replacePhoto(widget.ref, picked.first);
                    nav.pop();
                  }
                },
              ),
              _ToolButton(
                icon: Icons.delete_outline,
                label: S.remove,
                color: AppColors.failure,
                onTap: () {
                  vm.removePhoto(widget.ref);
                  Navigator.pop(context);
                },
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.icon, required this.label, required this.onTap, this.active = false, this.color});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? (active ? AppColors.accent : Colors.white);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: c),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: c, fontSize: 12)),
        ]),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white54
      ..strokeWidth = 0.7;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(size.width * i / 3, 0), Offset(size.width * i / 3, size.height), p);
      canvas.drawLine(Offset(0, size.height * i / 3), Offset(size.width, size.height * i / 3), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
