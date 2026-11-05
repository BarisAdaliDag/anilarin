import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/catalog.dart';
import '../models/group_code.dart';
import '../models/photo_book.dart';
import '../models/print_set.dart';
import '../print/print_renderer.dart';
import '../print/print_spec.dart';
import 'work_order.dart';

export '../models/group_code.dart';

/// Okul yıllığı sınıf grubu (Firestore `groups/{kod}`). Öğrenciler müşteri uygulamasında bu kodla girer.
class MatbaaGroup {
  final String code;
  final String name;
  final int createdAtMs;
  final String createdByEmail;

  const MatbaaGroup({required this.code, required this.name, required this.createdAtMs, this.createdByEmail = ''});

  factory MatbaaGroup.fromDoc(String code, Map<String, dynamic> j) => MatbaaGroup(
    code: code,
    name: j['name'] ?? '',
    createdAtMs: (j['createdAtMs'] as num?)?.toInt() ?? 0,
    createdByEmail: j['createdByEmail'] ?? '',
  );

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);

  /// Ekranda okunaklı biçim: `K7M-4QX`.
  String get display => formatGroupCode(code);
}

/// Matbaanın gördüğü sipariş (Firestore `orders/{ref}`).
class ShopOrder {
  final String ref;
  final Map<String, dynamic> data;

  const ShopOrder(this.ref, this.data);

  String get uid => data['uid'] ?? '';

  /// Okul yıllığı: siparişteki grup(lar) ve öğrenci (ad, fotoğraf dosyası). Normal siparişte boş.
  List<Map<String, dynamic>> get groups => [
    for (final g in (data['groups'] as List? ?? const [])) Map<String, dynamic>.from(g as Map),
  ];

  /// Bu ürün okul yıllığı grubuna mı ait? (grup kaydındaki tasarım dosyası ürününkiyle eşleşir)
  Map<String, dynamic>? groupOf(Map<String, dynamic> product) =>
      groups.where((g) => g['design'] == product['tasarimDosyasi']).firstOrNull;

  /// Klasör ve dosyalarda gruplu ürünü ayırmak için ek: ` - Okul Yilligi 10-A` (grupsuzda boş).
  static String groupSuffix(Map<String, dynamic>? g) =>
      g == null ? '' : ' - Okul Yilligi ${'${g['name'] ?? ''}'.replaceAll(RegExp(r'[/\\:]'), '-')}'.trimRight();

  /// İnsan okur grup etiketi: `Okul Yıllığı · 10-A (857-KTX) · Öğrenci: Ali Veli · Fotoğraf: photos/x.jpg`.
  static String groupLabel(Map<String, dynamic> g) => [
    'Okul Yıllığı · ${g['name'] ?? ''} (${formatGroupCode('${g['code'] ?? ''}')})',
    if ('${g['studentName'] ?? ''}'.isNotEmpty) 'Öğrenci: ${g['studentName']}',
    if (g['studentPhoto'] != null) 'Fotoğraf: photos/${g['studentPhoto']}',
  ].join(' · ');
  String get status => data['status'] ?? '';
  Map<String, dynamic> get _order => Map<String, dynamic>.from(data['order'] ?? const {});

  /// Müşteri; eski siparişlerde (müşteri alanı eklenmeden önce) teslimat adresinden.
  Map<String, dynamic> get customer {
    final c = data['customer'] as Map?;
    if (c != null && c.isNotEmpty) return Map<String, dynamic>.from(c);
    final a = (_order['address'] as Map?) ?? const {};
    return {'firstName': a['first'] ?? '', 'lastName': a['last'] ?? '', 'email': '', 'phone': a['phone'] ?? ''};
  }

  /// Ürünler; eski siparişlerde sipariş kalemlerinden türetilir (tasarım dosyası `<ürün kimliği>.json`).
  List<Map<String, dynamic>> get products {
    final list = data['products'] as List?;
    if (list != null && list.isNotEmpty) return [for (final p in list) Map<String, dynamic>.from(p as Map)];
    return [
      for (final i in (_order['items'] as List? ?? const []))
        {
          'ad': i['title'] ?? i['book'],
          'urunKodu': i['product'],
          'adet': i['qty'] ?? 1,
          'sayfa': i['pages'],
          'tasarimDosyasi': '${i['book']}.json',
        },
    ];
  }

  /// Admin buluttaki dosyaları sildiyse yalnız yerel arşiv kalır.
  bool get filesDeleted => data['filesDeleted'] == true;

  String get trackingNo => data['trackingNo'] ?? '';

  DateTime? get shippedAt => (data['shippedAt'] as Timestamp?)?.toDate();

  /// Teslimat adresi satırları.
  List<String> get addressLines {
    final a = (_order['address'] as Map?) ?? const {};
    return [
      '${a['first'] ?? ''} ${a['last'] ?? ''}',
      a['line1'],
      a['line2'],
      '${a['post'] ?? ''} ${a['district'] ?? ''} ${a['city'] ?? ''}',
      a['phone'],
    ].where((s) => s != null && '$s'.trim().isNotEmpty).map((s) => '$s'.trim()).toList();
  }

  String get customerName => '${customer['firstName'] ?? ''} ${customer['lastName'] ?? ''}'.trim();

  DateTime get createdAt {
    final iso = data['createdAtIso'] as String?;
    if (iso != null) return DateTime.parse(iso);
    return DateTime.fromMillisecondsSinceEpoch((data['order'] as Map?)?['created'] ?? 0);
  }

  /// Yerel klasör adı: `2026-11-03_AN-20261103-K7Q2_Ali-Veli`.
  String get folderName {
    final name = customerName.isEmpty ? (customer['email'] ?? 'musteri') : customerName;
    final safe = name.toString().replaceAll(RegExp(r'[^\wçğıöşüÇĞİÖŞÜ]+'), '-');
    return '${DateFormat('yyyy-MM-dd').format(createdAt)}_${ref}_$safe';
  }
}

/// Yetki, sipariş listesi, indirme, PDF üretimi ve buluttan silme.
class MatbaaService {
  final _auth = FirebaseAuth.instance;
  final _orders = FirebaseFirestore.instance.collection('orders');
  final _groups = FirebaseFirestore.instance.collection('groups');
  final _storage = FirebaseStorage.instance;

  /// Yeni sınıf grubu: benzersiz kod üretilir (aynı kod varsa yeniden), `groups/{kod}` yazılır.
  Future<MatbaaGroup> createGroup(String name) async {
    final data = {
      'name': name.trim(),
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      'createdByEmail': _auth.currentUser?.email ?? '',
    };
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = newGroupCode();
      final ref = _groups.doc(code);
      final created = await FirebaseFirestore.instance.runTransaction((tx) async {
        if ((await tx.get(ref)).exists) return false;
        tx.set(ref, data);
        return true;
      });
      if (created) return MatbaaGroup.fromDoc(code, data);
    }
    throw StateError('Benzersiz grup kodu üretilemedi, tekrar dene.');
  }

  /// Gruplar, en yenisi üstte.
  Stream<List<MatbaaGroup>> groups() => _groups.snapshots().map(
    (s) =>
        [for (final d in s.docs) MatbaaGroup.fromDoc(d.id, d.data())]
          ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs)),
  );

  /// Giriş yapan hesabın rolü (Firestore `users/{uid}.role`): `editor`, `admin` ya da boş.
  /// Rol yalnız Firebase konsolundan verilir.
  Future<String> role() async {
    final user = _auth.currentUser;
    if (user == null) return '';
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return (doc.data()?['role'] as String?) ?? '';
  }

  /// Gönderimi tamamlanmış siparişler, en yenisi üstte. Silinenler gösterilmez.
  Stream<List<ShopOrder>> orders() => _orders
      .where('status', whereIn: ['ready', 'downloaded', 'printed', 'shipped'])
      .snapshots()
      .map(
        (s) => [for (final d in s.docs) ShopOrder(d.id, d.data())]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  Future<void> setStatus(ShopOrder o, String status) =>
      _orders.doc(o.ref).update({'status': status, 'updatedAt': FieldValue.serverTimestamp()});

  /// Kargoya verildi: takip numarasıyla.
  Future<void> ship(ShopOrder o, String trackingNo) => _orders.doc(o.ref).update({
    'status': 'shipped',
    'trackingNo': trackingNo,
    'shippedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Reference _root(ShopOrder o) => _storage.ref('orders/${o.uid}/${o.ref}');

  Future<List<Reference>> _files(Reference dir) async {
    final list = await dir.listAll();
    return [...list.items, for (final p in list.prefixes) ...await _files(p)];
  }

  /// Siparişin daha önce indirilmiş yerel klasörü (adı değişmiş olsa da sipariş numarasından bulunur).
  Future<Directory?> localFolder(ShopOrder o, Directory saveRoot) async {
    if (!await saveRoot.exists()) return null;
    await for (final e in saveRoot.list()) {
      if (e is Directory && e.path.split('/').last.contains('_${o.ref}_')) return e;
    }
    return null;
  }

  /// Üretim için gereken her dosya (tasarım JSON'ları ve kullandıkları fotoğraflar) diskte mi?
  /// İnternete çıkmadan karar verir.
  Future<bool> isLocalComplete(ShopOrder o, Directory dir) async {
    if (o.products.isEmpty) return false;
    for (final p in o.products) {
      final f = File('${dir.path}/${p['tasarimDosyasi']}');
      if (!await f.exists()) return false;
      try {
        final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        final names = ((json['photoFiles'] as Map?) ?? const {}).values;
        for (final n in names) {
          if (!await File('${dir.path}/photos/$n.jpg').exists()) return false;
        }
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  /// Dosyaları `<kayıt klasörü>/<sipariş klasörü>/` altına indirir. Diskte aynı boyutta olan dosya
  /// tekrar indirilmez. [onFile]: (işlenen, toplam, atlanan).
  Future<Directory> download(ShopOrder o, Directory saveRoot, {void Function(int, int, int)? onFile}) async {
    final dir = await localFolder(o, saveRoot) ?? Directory('${saveRoot.path}/${o.folderName}');
    final root = _root(o);
    final files = await _files(root);
    var skipped = 0;
    for (var i = 0; i < files.length; i++) {
      final rel = files[i].fullPath.substring(root.fullPath.length + 1);
      final f = File('${dir.path}/$rel');
      if (await f.exists() && await f.length() == (await files[i].getMetadata()).size) {
        skipped++;
      } else {
        await f.parent.create(recursive: true);
        await files[i].writeToFile(f);
      }
      onFile?.call(i + 1, files.length, skipped);
    }
    return dir;
  }

  /// Her ürünün baskı dosyalarını `<sipariş klasörü>/baski/<ürün>/` altına üretir; önceki `baski/` silinir.
  /// Fotokitap: `kapak.pdf` (taşma paylı) ve `ic-sayfalar.pdf` (net). Baskı: `baskilar.pdf` ve
  /// `jpeg/<ölçü>/`. Ayrıca `is-emri.pdf` ve `baski-bilgisi.txt` yazılır. Bir ürün hata verirse
  /// diğerleri yine üretilir.
  Future<RenderResult> render(
    BuildContext context,
    Catalog catalog,
    ShopOrder o,
    Directory dir, {
    void Function(String)? onStep,
  }) async {
    final renderer = PrintRenderer(context: context, catalog: catalog, loadPhoto: (p, maxPx) => _photo(dir, p, maxPx));
    final baski = Directory('${dir.path}/baski');
    if (await baski.exists()) await baski.delete(recursive: true);
    await baski.create(recursive: true);
    final files = <File>[], lines = <String>[], errors = <String>[], lowRes = <String>[];
    if (o.products.isEmpty) errors.add('Siparişte ürün bilgisi bulunamadı.');
    for (final p in o.products) {
      final group = o.groupOf(p);
      final name = '${p['ad']}'.replaceAll(RegExp(r'[/\\:]'), '-') + ShopOrder.groupSuffix(group);
      final copies = (p['adet'] as num?)?.toInt() ?? 1;
      try {
        final json =
            jsonDecode(await File('${dir.path}/${p['tasarimDosyasi']}').readAsString()) as Map<String, dynamic>;
        _photoFiles = {
          for (final e in ((json['photoFiles'] as Map?) ?? const {}).entries) e.key as String: e.value as String,
        };
        final target = Directory('${baski.path}/$name');
        void onPage(int d, int t) => onStep?.call('$name: $d / $t');
        if (PrintCatalog.isPrintCode(p['urunKodu'])) {
          final set = PrintSet.fromJson(json);
          final tag = PrintSpec.sizeTag(set.product);
          files.addAll(await renderer.renderPrintSet(set, target, copies: copies, onPage: onPage));
          lines.addAll([
            '$name × $copies (Baskı): ${set.items.length} baskı',
            '  ${PrintSpec.print(set.product, portrait: false).label}',
            '  Baskı makinesi için JPEG: $name/jpeg/$tag/',
          ]);
        } else {
          final book = PhotoBook.fromJson(json);
          final product = catalog.product(book.productCode);
          files.addAll(await renderer.renderBook(book, target, onPage: onPage));
          final inner = book.pages.where((pg) => !pg.isCover).length;
          lines.addAll([
            '$name × $copies (Fotokitap${group == null ? '' : ' · OKUL YILLIĞI'})',
            if (group != null) '  ${ShopOrder.groupLabel(group)}',
            '  Kapak: ${PrintSpec.book(product, cover: true).label}',
            '  İç sayfalar: $inner sayfa, ${PrintSpec.book(product).label}',
          ]);
        }
        for (final l in renderer.lowRes) {
          lowRes.add('$name · ${l.place} · ${_photoFiles[l.photoId] ?? l.photoId}.jpg · ${l.dpi} DPI');
        }
      } catch (e) {
        errors.add('$name: $e');
      }
    }
    try {
      files.add(await WorkOrder.write(o, catalog, File('${baski.path}/is-emri.pdf')));
    } catch (e) {
      errors.add('İş emri: $e');
    }
    await File('${baski.path}/baski-bilgisi.txt').writeAsString(
      [
        'Sipariş: ${o.ref}',
        'Tarih: ${DateFormat('d MMMM y HH:mm', 'tr').format(o.createdAt)}',
        'Müşteri: ${o.customerName} ${o.customer['email'] ?? ''} ${o.customer['phone'] ?? ''}'.trim(),
        '',
        ...lines,
        if (lowRes.isNotEmpty) ...[
          '',
          'DÜŞÜK ÇÖZÜNÜRLÜK (${PrintRenderer.lowResDpi} DPI altı, baskıda yumuşak görünebilir):',
          ...lowRes,
        ],
        if (errors.isNotEmpty) ...['', 'HATALAR:', ...errors],
        '',
        'Kapakta kesim her kenardan ${PrintSpec.coverBleedMm.toInt()} mm içeride; iç sayfalar ve baskılar net ölçüde.',
      ].join('\n'),
    );
    return RenderResult(files: files, lines: lines, errors: errors, lowRes: lowRes);
  }

  Map<String, String> _photoFiles = {};

  Future<ui.Image> _photo(Directory dir, BookPhoto p, int maxPx) async {
    final name = _photoFiles[p.id] ?? p.id;
    return decodePhoto(await File('${dir.path}/photos/$name.jpg').readAsBytes(), maxPx);
  }

  /// Buluttaki tüm dosyaları siler; yerel arşiv kalır. Sipariş durumu korunur, listede kalır.
  Future<void> deleteFromCloud(ShopOrder o) async {
    for (final f in await _files(_root(o))) {
      await f.delete();
    }
    await _orders.doc(o.ref).update({'filesDeleted': true, 'updatedAt': FieldValue.serverTimestamp()});
  }
}

/// PDF üretiminin özeti.
class RenderResult {
  final List<File> files;
  final List<String> lines;
  final List<String> errors;

  /// Baskıda çözünürlüğü düşük kalan fotoğraflar (ürün · yer · dosya · DPI).
  final List<String> lowRes;

  const RenderResult({required this.files, required this.lines, required this.errors, required this.lowRes});
}

/// Kayıt klasörü tercihi (ör. harici SSD). Uygulama destek klasöründe saklanır.
class MatbaaSettings {
  static Future<File> _file() async => File('${(await getApplicationSupportDirectory()).path}/ayarlar.json');

  static Future<String?> loadSaveRoot() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      return (jsonDecode(await f.readAsString()) as Map)['saveRoot'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveSaveRoot(String path) async {
    final f = await _file();
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode({'saveRoot': path}));
  }
}
