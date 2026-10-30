import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/address.dart';
import '../models/basket_item.dart';
import '../models/order.dart';
import '../models/photo_book.dart';
import '../models/print_set.dart';

/// Tasarımları ve sepeti uygulama belgeler dizininde JSON dosyaları olarak saklar.
class DesignRepository {
  DesignRepository({Directory? root}) : _root = root;

  Directory? _root;

  Future<Directory> _dir(String name) async {
    _root ??= await getApplicationDocumentsDirectory();
    final d = Directory('${_root!.path}/$name');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<List<PhotoBook>> loadBooks() async {
    final d = await _dir('designs');
    final books = <PhotoBook>[];
    await for (final f in d.list()) {
      if (f is File && f.path.endsWith('.json')) {
        try {
          books.add(PhotoBook.fromJson(jsonDecode(await f.readAsString())));
        } catch (_) {
          // bozuk dosyayı atla
        }
      }
    }
    books.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return books;
  }

  Future<void> saveBook(PhotoBook book) async {
    final d = await _dir('designs');
    final f = File('${d.path}/${book.id}.json');
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(book.encode());
    await tmp.rename(f.path);
  }

  Future<void> deleteBook(String id) async {
    final d = await _dir('designs');
    final f = File('${d.path}/$id.json');
    if (await f.exists()) await f.delete();
  }

  Future<List<PrintSet>> loadPrintSets() async {
    final d = await _dir('prints');
    final sets = <PrintSet>[];
    await for (final f in d.list()) {
      if (f is File && f.path.endsWith('.json')) {
        try {
          sets.add(PrintSet.fromJson(jsonDecode(await f.readAsString())));
        } catch (_) {
          // bozuk dosyayı atla
        }
      }
    }
    sets.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return sets;
  }

  Future<void> savePrintSet(PrintSet set) async {
    final d = await _dir('prints');
    final f = File('${d.path}/${set.id}.json');
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(set.toJson()));
    await tmp.rename(f.path);
  }

  Future<void> deletePrintSet(String id) async {
    final f = File('${(await _dir('prints')).path}/$id.json');
    if (await f.exists()) await f.delete();
  }

  Future<List<BasketItem>> loadBasket() async {
    final d = await _dir('basket');
    final f = File('${d.path}/basket.json');
    if (!await f.exists()) return [];
    try {
      return (jsonDecode(await f.readAsString()) as List).map((e) => BasketItem.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Uygulanan indirim kodu. Dosya yoksa (ilk kullanım) Popsa'daki gibi hoş geldin indirimi gelir.
  Future<String?> loadCoupon() async {
    final f = File('${(await _dir('basket')).path}/coupon.json');
    if (!await f.exists()) return Coupon.welcome.code;
    try {
      return (jsonDecode(await f.readAsString()) as Map)['code'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCoupon(String? code) async {
    await File('${(await _dir('basket')).path}/coupon.json').writeAsString(jsonEncode({'code': code}));
  }

  Future<Address?> loadAddress() async {
    final f = File('${(await _dir('checkout')).path}/address.json');
    if (!await f.exists()) return null;
    try {
      return Address.fromJson(jsonDecode(await f.readAsString()));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAddress(Address a) async {
    await File('${(await _dir('checkout')).path}/address.json').writeAsString(jsonEncode(a.toJson()));
  }

  Future<List<Order>> loadOrders() async {
    final f = File('${(await _dir('checkout')).path}/orders.json');
    if (!await f.exists()) return [];
    try {
      return (jsonDecode(await f.readAsString()) as List).map((e) => Order.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveOrders(List<Order> orders) async {
    await File(
      '${(await _dir('checkout')).path}/orders.json',
    ).writeAsString(jsonEncode(orders.map((e) => e.toJson()).toList()));
  }

  Future<void> saveBasket(List<BasketItem> items) async {
    final d = await _dir('basket');
    await File('${d.path}/basket.json').writeAsString(jsonEncode(items.map((e) => e.toJson()).toList()));
  }
}
