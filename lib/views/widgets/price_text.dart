import 'package:flutter/material.dart';

import '../../models/catalog.dart';
import '../../config/theme.dart';

/// Üstü çizili eski fiyat + güncel fiyat (Popsa: "TRY1.400 TRY700").
class PriceText extends StatelessWidget {
  const PriceText({super.key, required this.price, required this.compareAt, this.size = 16});

  final int price;
  final int compareAt;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          if (compareAt > price)
            TextSpan(
              text: '${formatPrice(compareAt)} ',
              style: TextStyle(decoration: TextDecoration.lineThrough, color: context.mutedText, fontSize: size * 0.85),
            ),
          TextSpan(
            text: formatPrice(price),
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: size),
          ),
        ],
      ),
    );
  }
}
