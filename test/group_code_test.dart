import 'dart:math';

import 'package:anilarin/matbaa/matbaa_service.dart';
import 'package:anilarin/models/photo_book.dart';
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
    expect(normalizeGroupCode(' k7m-4qx '), 'K7M4QX');
  });

  test('kitabın grup bilgisi JSON gidiş-dönüş; eski kitapta yok', () {
    final g = GroupMembership(
      code: 'K7M4QX',
      name: '10-A',
      studentName: 'Ali Veli',
      studentPhoto: const BookPhoto(id: 'x', width: 4, height: 5),
    );
    final back = GroupMembership.fromJson(g.toJson());
    expect(back.code, 'K7M4QX');
    expect(back.studentName, 'Ali Veli');
    expect(back.studentPhoto!.id, 'x');
    expect(back.complete, isTrue);
    expect(GroupMembership(code: 'K7M4QX', name: '').complete, isFalse);
  });

  test('matbaa: siparişte gruplu ürün ayırt edilir (satır, iş emri, baskı klasörü)', () {
    final o = ShopOrder('AN-1', {
      'products': [
        {'ad': 'Normal', 'urunKodu': 'PBK-14', 'adet': 1, 'sayfa': 20, 'tasarimDosyasi': 'b1.json'},
        {'ad': 'Yillik', 'urunKodu': 'PBK-14', 'adet': 1, 'sayfa': 24, 'tasarimDosyasi': 'b2.json'},
      ],
      'groups': [
        {'code': 'K7M4QX', 'name': '10-A', 'studentName': 'Ali Veli', 'studentPhoto': 'x.jpg', 'design': 'b2.json'},
      ],
    });
    expect(o.groupOf(o.products[0]), isNull);
    expect(o.groupOf(o.products[1])!['name'], '10-A');
    expect(ShopOrder.groupSuffix(null), '');
    expect(ShopOrder.groupSuffix(o.groupOf(o.products[1])), ' - Okul Yilligi 10-A');
    expect(ShopOrder.groupLabel(o.groupOf(o.products[1])!), contains('Ali Veli'));
  });
}
