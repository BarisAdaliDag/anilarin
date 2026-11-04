import 'dart:math';

import 'package:anilarin/matbaa/matbaa_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('grup kodu: 6 karakter, karışan karakter yok, okunaklı biçim', () {
    final random = Random(7);
    final codes = {for (var i = 0; i < 1000; i++) newGroupCode(random)};
    expect(codes.length, greaterThan(995));
    for (final c in codes) {
      expect(c.length, 6);
      expect(c.split('').every(groupCodeAlphabet.contains), isTrue, reason: c);
    }
    expect(groupCodeAlphabet.contains(RegExp('[01OIL]')), isFalse);
    expect(formatGroupCode('K7M4QX'), 'K7M-4QX');
    final g = MatbaaGroup.fromDoc('K7M4QX', {'name': '10-A', 'createdAtMs': 5});
    expect(g.display, 'K7M-4QX');
    expect(g.name, '10-A');
  });
}
