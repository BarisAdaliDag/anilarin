import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants/strings_tr.dart';
import 'asset_video.dart';
import 'ref_image.dart';

/// Ürün sayfası medya karuseli (Popsa): görsel ve sessiz döngü videoları, nokta göstergesi,
/// "16.500.000'den fazla satıldı" şeridi. Kendiliğinden ilerler; [media] değişince başa döner.
class MediaCarousel extends StatefulWidget {
  const MediaCarousel({
    super.key,
    required this.media,
    this.aspectRatio = 1.1,
    this.interval = const Duration(seconds: 4),
  });

  final List<String> media;
  final double aspectRatio;
  final Duration interval;

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  final _controller = PageController();
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(MediaCarousel old) {
    super.didUpdateWidget(old);
    if (old.media.join() != widget.media.join()) {
      _index = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
      _restart();
    }
  }

  void _restart() {
    _timer?.cancel();
    if (widget.media.length < 2) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        (_index + 1) % widget.media.length,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Stack(
        children: [
          // Elle kaydırınca otomatik ilerleme baştan sayar.
          NotificationListener<ScrollStartNotification>(
            onNotification: (n) {
              if (n.dragDetails != null) _restart();
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              itemCount: media.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => media[i].endsWith('.mp4')
                  ? AssetVideo(
                      key: ValueKey(media[i]),
                      path: media[i],
                      playing: _index == i,
                      fallback: const RefPlaceholder(icon: Icons.photo_library_outlined),
                    )
                  : RefImage(media[i], icon: Icons.photo_library_outlined),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 14,
            child: Row(
              children: [
                for (var i = 0; i < media.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 6),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _index ? Colors.white : Colors.white54,
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              color: const Color(0xCC1E1E1E),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: const Text(S.soldBanner, style: TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 1.2)),
            ),
          ),
        ],
      ),
    );
  }
}
