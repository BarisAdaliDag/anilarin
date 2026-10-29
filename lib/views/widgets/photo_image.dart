import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../repositories/photo_repository.dart';

/// Galerideki bir fotoğrafı kimliğinden gösterir.
class PhotoImage extends StatefulWidget {
  const PhotoImage({super.key, required this.photoId, this.size = 400, this.fit = BoxFit.cover});

  final String photoId;
  final int size;
  final BoxFit fit;

  @override
  State<PhotoImage> createState() => _PhotoImageState();
}

class _PhotoImageState extends State<PhotoImage> {
  AssetEntity? _entity;
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(PhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoId != widget.photoId) _resolve();
  }

  void _resolve() {
    final hit = PhotoRepository.cached(widget.photoId);
    if (hit != null) {
      _entity = hit;
      _missing = false;
      return;
    }
    _entity = null;
    PhotoRepository.entity(widget.photoId)
        .then((e) {
          if (!mounted) return;
          setState(() {
            _entity = e;
            _missing = e == null;
          });
        })
        .catchError((_) {
          if (mounted) setState(() => _missing = true);
        });
  }

  @override
  Widget build(BuildContext context) {
    final e = _entity;
    if (e == null) {
      return ColoredBox(
        color: const Color(0xFFE6E6E6),
        child: _missing ? const Center(child: Icon(Icons.broken_image_outlined, color: Colors.black26)) : null,
      );
    }
    return Image(
      image: AssetEntityImageProvider(e, isOriginal: false, thumbnailSize: ThumbnailSize.square(widget.size)),
      fit: widget.fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFE6E6E6)),
    );
  }
}
