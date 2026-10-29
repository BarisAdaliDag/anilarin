import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// `assets/ref/` altındaki (yerel, repoya girmeyen) görseli gösterir; yoksa gradyan yer tutucuya düşer.
class RefImage extends StatelessWidget {
  const RefImage(this.path, {super.key, this.fit = BoxFit.cover, this.icon = Icons.photo_album_outlined});

  final String path;
  final BoxFit fit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      fit: fit,
      errorBuilder: (_, _, _) => RefPlaceholder(icon: icon),
    );
  }
}

class RefPlaceholder extends StatelessWidget {
  const RefPlaceholder({super.key, this.icon = Icons.photo_album_outlined});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB2EBF2), AppColors.accent],
        ),
      ),
      child: Center(child: Icon(icon, size: 48, color: Colors.white70)),
    );
  }
}
