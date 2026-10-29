import 'package:anilarin/views/preview/preview_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('önizleme sayfaları Popsa gibi eşlenir: boş|1, 2|3, ...', () {
    // kapak + 4 iç sayfa
    expect(bookSpreads(5), [
      [0],
      [-1, 1],
      [2, 3],
      [4, -1],
    ]);
    // kapak + 3 iç sayfa
    expect(bookSpreads(4), [
      [0],
      [-1, 1],
      [2, 3],
    ]);
  });
}
