import 'package:anilarin/views/editor/edit_photo_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Popsa kalite puanı: piksel / (gereken × yakınlaştırma), 1–10', () {
    expect(photoQuality(photoPx: 4000, requiredPx: 3000, zoom: 1).$1, 10);
    final (score, exact) = photoQuality(photoPx: 1500, requiredPx: 3000, zoom: 1);
    expect(score, 5);
    expect((1 / exact * 100).round(), 200);
    expect(photoQuality(photoPx: 4000, requiredPx: 3000, zoom: 4).$1, 3);
    expect(photoQuality(photoPx: 10, requiredPx: 3000, zoom: 1).$1, 1);
  });
}
