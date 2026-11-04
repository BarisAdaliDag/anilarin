import 'dart:math';

/// Grup kodu alfabesi: karışan karakterler (0/O, 1/I/L) yok.
const groupCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const groupCodeLength = 6;

/// Rastgele grup kodu (tiresiz, büyük harf).
String newGroupCode([Random? random]) {
  final r = random ?? Random.secure();
  return String.fromCharCodes([
    for (var i = 0; i < groupCodeLength; i++) groupCodeAlphabet.codeUnitAt(r.nextInt(groupCodeAlphabet.length)),
  ]);
}

/// `K7M4QX` → `K7M-4QX`.
String formatGroupCode(String code) =>
    code.length == groupCodeLength ? '${code.substring(0, 3)}-${code.substring(3)}' : code;

/// Kullanıcının yazdığı kodu saklanan biçime çevirir: boşluk/tire atılır, büyük harfe çevrilir.
String normalizeGroupCode(String input) => input.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
