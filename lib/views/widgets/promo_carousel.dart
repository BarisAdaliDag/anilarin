import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../config/theme.dart';
import '../../constants/asset_paths.dart';
import 'ref_image.dart';

/// Ana sayfadaki tanıtım karuseli (Popsa'daki marketing carousel). Video varsa sessiz döngüde oynatır.
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key});

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  final _controller = PageController(viewportFraction: 0.9);
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_controller.hasClients) return;
      final next = (_index + 1) % AssetPaths.promos.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
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
    return Column(children: [
      SizedBox(
        height: 300,
        child: PageView.builder(
          controller: _controller,
          itemCount: AssetPaths.promos.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _PromoCard(promo: AssetPaths.promos[i], active: i == _index),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < AssetPaths.promos.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _index ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == _index ? AppColors.accent : AppColors.grey,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    ]);
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.promo, required this.active});

  final Promo promo;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(fit: StackFit.expand, children: [
        if (promo.video != null)
          AssetVideo(path: promo.video!, playing: active, fallback: _image())
        else
          _image(),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black54],
              stops: [0.45, 1],
            ),
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 18,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              promo.title,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(promo.body, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ]),
        ),
      ]),
    );
  }

  Widget _image() => Image.asset(
        promo.image,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => RefImage(promo.fallback),
      );
}

/// Asset videoyu sessiz döngüde oynatır; dosya yoksa veya oynatılamazsa [fallback] gösterir.
class AssetVideo extends StatefulWidget {
  const AssetVideo({super.key, required this.path, required this.fallback, this.playing = true});

  final String path;
  final Widget fallback;
  final bool playing;

  @override
  State<AssetVideo> createState() => _AssetVideoState();
}

class _AssetVideoState extends State<AssetVideo> {
  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await rootBundle.load(widget.path); // dosya yoksa hata fırlatır
      final c = VideoPlayerController.asset(widget.path);
      await c.initialize();
      await c.setVolume(0);
      await c.setLooping(true);
      if (widget.playing) await c.play();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _video = c);
    } catch (_) {
      // video yok: görsel kalır
    }
  }

  @override
  void didUpdateWidget(AssetVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    final c = _video;
    if (c == null) return;
    widget.playing ? c.play() : c.pause();
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _video;
    if (c == null || !c.value.isInitialized) return widget.fallback;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
    );
  }
}
