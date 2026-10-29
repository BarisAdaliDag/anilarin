import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

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
