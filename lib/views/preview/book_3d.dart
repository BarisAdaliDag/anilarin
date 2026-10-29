import 'dart:math';

import 'package:flutter/material.dart';

/// Kapalı kitabın 3B görünümü (Popsa'daki Unity önizlemesinin hafif karşılığı).
///
/// Paket kullanmadan, Flutter'ın perspektifli `Transform`'uyla bir kutu kurulur: kapak, sırt ve
/// üç sayfa kenarı. Kutu dışbükey olduğundan yalnız kameraya bakan yüzler çizilir; sıralama gerekmez.
/// Kitap masada yatar gibi eğik durur, hafifçe salınır; dikey sürükleme eğimi değiştirir.
class Book3D extends StatefulWidget {
  const Book3D({
    super.key,
    required this.cover,
    required this.aspect,
    required this.pageCount,
    required this.spineColor,
  });

  final Widget cover;
  final double aspect; // genişlik / yükseklik
  final int pageCount;
  final Color spineColor;

  @override
  State<Book3D> createState() => _Book3DState();
}

class _Book3DState extends State<Book3D> with SingleTickerProviderStateMixin {
  late final _sway = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  double _pitch = 0.85; // radyan; 0 = dik, büyüdükçe masaya yatar

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = min(c.maxWidth * 0.66, c.maxHeight * 0.66 * widget.aspect);
        final h = w / widget.aspect;
        final t = w * (0.02 + widget.pageCount * 0.0007); // sayfa sayısıyla kalınlaşır
        return GestureDetector(
          onVerticalDragUpdate: (d) => setState(() => _pitch = (_pitch - d.delta.dy * 0.006).clamp(0.0, 1.1)),
          child: AnimatedBuilder(
            animation: _sway,
            builder: (context, _) {
              final yaw = -0.5 + sin(_sway.value * 2 * pi) * 0.12; // masadaki dönüş
              final view = Matrix4.identity()
                ..setEntry(3, 2, 0.0006)
                ..rotateX(-_pitch)
                ..rotateZ(yaw);
              final rot = Matrix4.identity()
                ..rotateX(-_pitch)
                ..rotateZ(yaw);

              Widget face(Size size, Matrix4 local, Widget child) {
                final m = rot.clone()..multiply(local);
                // Yüzün normali (0,0,-1) dönünce z'si -m[2][2]; kameraya bakmıyorsa çizilmez.
                if (m.entry(2, 2) <= 0) return const SizedBox.shrink();
                return Transform(
                  alignment: Alignment.center,
                  transform: view.clone()..multiply(local),
                  child: SizedBox.fromSize(size: size, child: child),
                );
              }

              final pagesEdge = _PageEdge(lines: (widget.pageCount / 2).clamp(6, 60).round());
              return SizedBox(
                width: c.maxWidth,
                height: c.maxHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Masadaki gölge
                    face(
                      Size(w * 1.08, h * 1.08),
                      Matrix4.translationValues(w * 0.04, h * 0.05, t / 2 + 1),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 30, spreadRadius: 4)],
                        ),
                      ),
                    ),
                    // Sırt (sol)
                    face(
                      Size(t, h),
                      Matrix4.translationValues(-w / 2, 0, 0)..rotateY(pi / 2),
                      _shade(widget.spineColor, 0.25),
                    ),
                    // Sayfa kenarları: sağ, alt, üst
                    face(Size(t, h), Matrix4.translationValues(w / 2, 0, 0)..rotateY(-pi / 2), pagesEdge),
                    face(
                      Size(w, t),
                      Matrix4.translationValues(0, h / 2, 0)..rotateX(pi / 2),
                      RotatedBox(quarterTurns: 1, child: pagesEdge),
                    ),
                    face(
                      Size(w, t),
                      Matrix4.translationValues(0, -h / 2, 0)..rotateX(-pi / 2),
                      RotatedBox(quarterTurns: 1, child: pagesEdge),
                    ),
                    // Kapak ve üzerinde açıya göre değişen ışık
                    face(
                      Size(w, h),
                      Matrix4.translationValues(0, 0, -t / 2),
                      Stack(
                        fit: StackFit.expand,
                        children: [
                          widget.cover,
                          IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(-1 + yaw, -1),
                                  end: Alignment(1 + yaw, 1),
                                  colors: const [Color(0x22FFFFFF), Color(0x00FFFFFF), Color(0x1A000000)],
                                ),
                              ),
                            ),
                          ),
                          // Sırttaki menteşe izi
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 6,
                              height: double.infinity,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [Color(0x33000000), Color(0x00000000)]),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  static Widget _shade(Color c, double dark) => ColoredBox(color: Color.lerp(c, Colors.black, dark)!);
}

/// Sayfa bloğunun kenarı: krem zemin üzerinde ince kâğıt çizgileri.
class _PageEdge extends StatelessWidget {
  const _PageEdge({required this.lines});

  final int lines;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _PageEdgePainter(lines));
}

class _PageEdgePainter extends CustomPainter {
  _PageEdgePainter(this.lines);

  final int lines;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF2EFE8));
    final p = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 0.6;
    for (var i = 1; i < lines; i++) {
      final x = size.width * i / lines;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_PageEdgePainter old) => old.lines != lines;
}
