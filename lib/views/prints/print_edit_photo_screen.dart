import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../constants/strings_tr.dart';
import '../../models/photo_book.dart';
import '../editor/edit_photo_screen.dart' show EditToolCard;
import '../photo_picker/photo_picker_screen.dart';
import '../widgets/photo_image.dart';
import '../widgets/print_page_view.dart' show photoRect;

/// Baskıdaki fotoğrafı düzenle (Popsa Edit Photo): Değiştir, Kaldır, Doldur, Sığdır, Döndür.
/// Yakınlaştırma ve kaydırma yalnız çerçeveyi dolduran fotoğrafta olur; kenarda boşluk açılamaz.
/// Sonuç: güncel [PhotoSlot] ve (değiştirildiyse) yeni fotoğraf; Kaldır'da `removed: true`.
class PrintEditResult {
  const PrintEditResult({this.slot, this.photo, this.removed = false});

  final PhotoSlot? slot;
  final BookPhoto? photo;
  final bool removed;
}

class PrintEditPhotoScreen extends StatefulWidget {
  const PrintEditPhotoScreen({super.key, required this.photo, required this.slot, required this.frameAspect});

  final BookPhoto photo;
  final PhotoSlot slot;
  final double frameAspect;

  @override
  State<PrintEditPhotoScreen> createState() => _PrintEditPhotoScreenState();
}

class _PrintEditPhotoScreenState extends State<PrintEditPhotoScreen> {
  late PhotoSlot _slot = PhotoSlot.fromJson(widget.slot.toJson());
  late BookPhoto _photo = widget.photo;
  double _startScale = 1;
  Offset _startFocal = Offset.zero;
  double _startDx = 0, _startDy = 0;
  bool _gesturing = false;
  static const _anim = Duration(milliseconds: 320);

  Future<void> _replace() async {
    final picked = await Navigator.of(
      context,
    ).push<List<BookPhoto>>(MaterialPageRoute(builder: (_) => const PhotoPickerScreen(single: true)));
    if (picked == null || picked.isEmpty) return;
    setState(() {
      _photo = picked.first;
      _slot = PhotoSlot(photoId: _photo.id);
    });
  }

  void _mode(bool fit) => setState(() {
    _slot
      ..fit = fit
      ..scale = 1
      ..dx = 0
      ..dy = 0;
  });

  @override
  Widget build(BuildContext context) {
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
              onPressed: () => Navigator.pop(
                context,
                PrintEditResult(slot: _slot, photo: _photo.id == widget.photo.id ? null : _photo),
              ),
              child: const Text(S.save),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ClipRect(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: widget.frameAspect,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final size = Size(c.maxWidth, c.maxHeight);
                        final target = photoRect(size, _photo.aspect, _slot);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onScaleStart: (d) {
                            _gesturing = true;
                            // Sığdır'da yakınlaştırma/kaydırma boşluk açar: önce çerçeveyi dolduran moda geçilir.
                            if (_slot.fit) _mode(false);
                            _startScale = _slot.scale;
                            _startFocal = d.localFocalPoint;
                            _startDx = _slot.dx;
                            _startDy = _slot.dy;
                          },
                          onScaleUpdate: (d) => setState(() {
                            _slot.scale = (_startScale * d.scale).clamp(1.0, 4.0);
                            final cur = photoRect(size, _photo.aspect, _slot);
                            final ox = max(1.0, (cur.width - size.width) / 2);
                            final oy = max(1.0, (cur.height - size.height) / 2);
                            final delta = d.localFocalPoint - _startFocal;
                            _slot.dx = (_startDx + delta.dx / ox).clamp(-1.0, 1.0);
                            _slot.dy = (_startDy + delta.dy / oy).clamp(-1.0, 1.0);
                          }),
                          onScaleEnd: (_) => setState(() => _gesturing = false),
                          child: TweenAnimationBuilder<Rect?>(
                            tween: RectTween(end: target),
                            duration: _gesturing ? Duration.zero : _anim,
                            curve: Curves.easeOutCubic,
                            builder: (context, rect, _) {
                              final r = rect ?? target;
                              Widget photo() => RotatedBox(
                                quarterTurns: _slot.quarterTurns,
                                child: PhotoImage(photoId: _photo.id, size: 1200),
                              );
                              // Taşan kısım karartılmış görünür; çerçevenin içi her zaman fotoğrafla dolu.
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fromRect(
                                    rect: r,
                                    child: Opacity(opacity: 0.3, child: photo()),
                                  ),
                                  Positioned.fill(
                                    child: ClipRect(
                                      child: Stack(
                                        children: [Positioned.fromRect(rect: r, child: photo())],
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(border: Border.all(color: Colors.white70)),
                                      ),
                                    ),
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
                  EditToolCard(icon: Icons.image_outlined, label: S.replace, onTap: _replace),
                  EditToolCard(
                    icon: Icons.delete_outline,
                    label: S.remove,
                    onTap: () => Navigator.pop(context, const PrintEditResult(removed: true)),
                  ),
                  EditToolCard(icon: Icons.open_in_full, label: S.fill, active: !_slot.fit, onTap: () => _mode(false)),
                  EditToolCard(icon: Icons.close_fullscreen, label: S.fit, active: _slot.fit, onTap: () => _mode(true)),
                  EditToolCard(
                    icon: Icons.rotate_left,
                    label: S.rotate,
                    onTap: () => setState(() {
                      _slot
                        ..quarterTurns = (_slot.quarterTurns + 3) % 4
                        ..scale = 1
                        ..dx = 0
                        ..dy = 0;
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
