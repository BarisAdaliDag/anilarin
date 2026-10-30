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

/// Baskı çözünürlüğü (Popsa'nın sayfa piksel boyutlarına karşılık).
const printDpi = 300.0;

/// Popsa PhotoQualityMeter: kalite = fotoğraf pikseli / (baskıda gereken piksel × yakınlaştırma);
/// puan = kalite × 10, 1–10 arası. Döndürülen ikinci değer "fotoğrafı % kaçına ölçekleyeceğiz" oranıdır.
(int, double) photoQuality({required double photoPx, required double requiredPx, required double zoom}) {
  if (requiredPx <= 0 || zoom <= 0) return (10, 1);
  final exact = photoPx / (requiredPx * zoom);
  return ((exact * 10).round().clamp(1, 10), exact);
}

/// Fotoğraf düzenleme (Popsa EditPhotoActivity): kalite kartı, kırpma (sürükle/yakınlaştır),
/// Değiştir, Kaldır, Doldur, Sığdır, Döndür, Izgara.
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
  bool _grid = false;
  bool _gesturing = false; // parmakla sürüklerken animasyon olmaz
  int _rotateTick = 0; // her döndürmede dönüş animasyonunu yeniden başlatır
  static const _anim = Duration(milliseconds: 320);

  @override
  void initState() {
    super.initState();
    final s = context.read<EditorViewModel>().slotAt(widget.ref)!;
    _slot = PhotoSlot.fromJson(s.toJson());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EditorViewModel>();
    final photo = vm.photo(_slot.photoId);
    final tpl = vm.templateOf(widget.ref.page);
    final frame = tpl.photoSlots(vm.format)[widget.ref.slot].frame;
    final slotAspect = frame.width * vm.product.aspect / frame.height;

    // Alanın baskıdaki genişliği (piksel) ve fotoğrafın bu genişliğe düşen pikseli.
    final pageWidthCm = double.tryParse(vm.product.dimensionsCm.split('×').first.trim()) ?? 21;
    final requiredPx = pageWidthCm / 2.54 * printDpi * frame.width / 100;
    final pa = photo?.aspect ?? 1;
    final rotatedAspect = _slot.quarterTurns.isOdd ? 1 / pa : pa;
    final photoW = photo == null ? requiredPx : (_slot.quarterTurns.isOdd ? photo.height : photo.width).toDouble();
    // Doldur: fotoğraf alanı dolduracak kadar büyütülür; alan genişliğine düşen kaynak piksel azalır.
    final coverZoom = _slot.fit ? 1.0 : max(1.0, slotAspect / rotatedAspect);
    final (score, exact) = photoQuality(photoPx: photoW, requiredPx: requiredPx, zoom: coverZoom * _slot.scale);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: const Text(S.editPhoto),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: context.pillColor,
                foregroundColor: context.strongText,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                vm.updateSlot(widget.ref, _slot);
                Navigator.pop(context);
              },
              child: const Text(S.save),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _QualityCard(score: score, onTap: () => _explain(exact)),
          ),
          Expanded(
            // Taşan kısım bu alanın içinde kalsın (kalite kartının ve araçların üstüne binmesin).
            child: ClipRect(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: slotAspect,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final size = Size(c.maxWidth, c.maxHeight);
                        final target = photoRect(size, pa, _slot);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onScaleEnd: (_) => setState(() => _gesturing = false),
                          onScaleStart: (d) {
                            _gesturing = true;
                            // Yakınlaştırma/kaydırma yalnız çerçeveyi dolduran fotoğrafta: Sığdır'dan Doldur'a geçilir.
                            if (_slot.fit) {
                              _slot
                                ..fit = false
                                ..scale = 1
                                ..dx = 0
                                ..dy = 0;
                            }
                            _startScale = _slot.scale;
                            _startFocal = d.localFocalPoint;
                            _startDx = _slot.dx;
                            _startDy = _slot.dy;
                          },
                          onScaleUpdate: (d) => setState(() {
                            _slot.scale = (_startScale * d.scale).clamp(1.0, 4.0);
                            final cur = photoRect(size, pa, _slot);
                            final ox = max(1.0, (cur.width - size.width) / 2);
                            final oy = max(1.0, (cur.height - size.height) / 2);
                            final delta = d.localFocalPoint - _startFocal;
                            _slot.dx = (_startDx + delta.dx / ox).clamp(-1.0, 1.0);
                            _slot.dy = (_startDy + delta.dy / oy).clamp(-1.0, 1.0);
                          }),
                          // Doldur/Sığdır/Döndür geçişleri yumuşak: dikdörtgen animasyonla hedefe gider.
                          child: TweenAnimationBuilder<Rect?>(
                            tween: RectTween(end: target),
                            duration: _gesturing ? Duration.zero : _anim,
                            curve: Curves.easeOutCubic,
                            builder: (context, rect, _) {
                              final r = rect ?? target;
                              // Popsa gibi: alanın dışına taşan kısım da karartılmış olarak görünür.
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fromRect(
                                    rect: r,
                                    child: Opacity(opacity: 0.3, child: _photo()),
                                  ),
                                  Positioned.fill(
                                    child: ClipRect(
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: ColoredBox(color: Colors.white.withValues(alpha: 0.04)),
                                          ),
                                          Positioned.fromRect(rect: r, child: _photo()),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (_grid)
                                    IgnorePointer(
                                      child: CustomPaint(size: size, painter: _GridPainter()),
                                    ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
            child: Text(
              S.panPinchHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 13),
            ),
          ),
          SafeArea(
            top: false,
            child: SizedBox(
              height: 140,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  EditToolCard(icon: Icons.image_outlined, label: S.replace, onTap: () => _replace(vm)),
                  EditToolCard(
                    icon: Icons.delete_outline,
                    label: S.remove,
                    onTap: () {
                      vm.removePhoto(widget.ref);
                      Navigator.pop(context);
                    },
                  ),
                  EditToolCard(
                    icon: Icons.open_in_full,
                    label: S.fill,
                    active: !_slot.fit,
                    onTap: () => setState(() {
                      _slot.fit = false;
                      _slot.resetCrop();
                    }),
                  ),
                  EditToolCard(
                    icon: Icons.close_fullscreen,
                    label: S.fit,
                    active: _slot.fit,
                    onTap: () => setState(() {
                      _slot.fit = true;
                      _slot.resetCrop();
                    }),
                  ),
                  EditToolCard(
                    icon: Icons.rotate_right,
                    label: S.rotate,
                    onTap: () => setState(() {
                      _slot.quarterTurns = (_slot.quarterTurns + 1) % 4;
                      _slot.resetCrop();
                      _rotateTick++;
                    }),
                  ),
                  EditToolCard(
                    icon: Icons.grid_on,
                    label: S.grid,
                    active: _grid,
                    onTap: () => setState(() => _grid = !_grid),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Döndürmeden sonra fotoğraf -90°'den 0°'ye dönerek yeni yönüne oturur.
  Widget _photo() => TweenAnimationBuilder<double>(
    key: ValueKey(_rotateTick),
    tween: Tween(begin: _rotateTick == 0 ? 0 : -pi / 2, end: 0),
    duration: _anim,
    curve: Curves.easeOutCubic,
    builder: (_, angle, child) => Transform.rotate(angle: angle, child: child),
    child: RotatedBox(
      quarterTurns: _slot.quarterTurns % 4,
      child: PhotoImage(photoId: _slot.photoId, size: 1400, fit: BoxFit.fill),
    ),
  );

  Future<void> _replace(EditorViewModel vm) async {
    final nav = Navigator.of(context);
    final picked = await nav.push<List<BookPhoto>>(
      MaterialPageRoute(builder: (_) => const PhotoPickerScreen(single: true)),
    );
    if (picked != null && picked.isNotEmpty) {
      vm.replacePhoto(widget.ref, picked.first);
      nav.pop();
    }
  }

  Future<void> _explain(double exact) {
    final pct = exact <= 0 ? 100 : (1 / exact * 100).round();
    return showDialog(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(
          '${S.qualityExplanationA}\n\n${S.qualityExplanationB}\n\n${S.qualityExplanationC(pct)}',
          style: const TextStyle(fontSize: 17, height: 1.5),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text(S.ok))],
      ),
    );
  }
}

/// Popsa'nın kalite kartı: sabit, sade koyu kart; solda başlık, sağda puan. Dokununca açıklama.
class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.score, required this.onTap});

  final int score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final low = score < 4;
    return Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Text(
                  S.photoQuality,
                  style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.4, color: context.strongText),
                ),
                const Spacer(),
                if (low)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                  ),
                Text(
                  '$score/10',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: low ? AppColors.warning : context.strongText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Popsa'nın alttaki büyük araç kartları.
class EditToolCard extends StatelessWidget {
  const EditToolCard({super.key, required this.icon, required this.label, required this.onTap, this.active = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.accent : context.strongText;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 92,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 30, color: fg),
                const SizedBox(height: 8),
                Text(label, style: TextStyle(fontSize: 15, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(size.width * i / 3, 0), Offset(size.width * i / 3, size.height), p);
      canvas.drawLine(Offset(0, size.height * i / 3), Offset(size.width, size.height * i / 3), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
