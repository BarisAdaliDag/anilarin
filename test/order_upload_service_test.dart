import 'dart:convert';
import 'dart:typed_data';

import 'package:anilarin/models/address.dart';
import 'package:anilarin/models/basket_item.dart';
import 'package:anilarin/models/order.dart';
import 'package:anilarin/models/photo_book.dart';
import 'package:anilarin/services/order_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

class _FakeBackend implements OrderBackend {
  final files = <String, Uint8List>{};
  final order = <String, dynamic>{};
  final uploaded = <String>{};
  final log = <String>[];
  int failAfter = -1;

  @override
  Future<String> signIn() async => 'u1';

  @override
  Future<Set<String>> uploadedPhotos(String orderRef) async => {...uploaded};

  @override
  Future<void> saveOrder(String orderRef, Map<String, dynamic> data) async {
    order.addAll(data);
    log.add('status:${data['status']}');
  }

  @override
  Future<void> putFile(String path, Uint8List bytes, String contentType) async {
    if (failAfter == 0) throw Exception('bağlantı koptu');
    if (failAfter > 0) failAfter--;
    files[path] = bytes;
    log.add(path);
  }

  @override
  Future<void> markPhotoUploaded(String orderRef, String fileName, int bytes) async => uploaded.add(fileName);
}

Order _order(List<BasketItem> items) => Order(
  reference: 'AN-TEST',
  createdAtMs: 0,
  items: items,
  address: Address(),
  shippingId: 'standard',
  paymentMethod: 'card',
  totalCents: 0,
);

OrderDesign _design(String id, List<BookPhoto> photos) => OrderDesign(
  BasketItem(bookId: id, title: id, productCode: 'x', pages: 1, options: ProductOptions.fromJson(null), quantity: 2),
  {'id': id},
  photos,
);

void main() {
  final encoded = <String>[];
  Future<Uint8List> encode(BookPhoto p, int w, int h) async {
    encoded.add('${p.id}:${w}x$h');
    return Uint8List(10);
  }

  setUp(encoded.clear);

  test('hedef boyut uzun kenarı 4000 px ile sınırlar, küçük fotoğrafı büyütmez', () {
    expect(OrderUploadService.targetSize(8000, 6000), (4000, 3000));
    expect(OrderUploadService.targetSize(3000, 4500), (2667, 4000));
    expect(OrderUploadService.targetSize(1200, 900), (1200, 900));
  });

  test('dosya adı Storage yolu için güvenli', () {
    expect(OrderUploadService.fileNameOf('ABC-12/L0/001'), 'ABC-12_L0_001');
  });

  test('fotoğraflar yüklenir, tasarım JSON en son, durum ready olur', () async {
    final photos = testPhotos(3);
    final backend = _FakeBackend();
    final designs = [
      _design('b1', photos),
      _design('b2', [photos.first]),
    ];
    final progress = <int>[];
    await OrderUploadService(
      backend: backend,
      encode: encode,
    ).upload(_order(designs.map((d) => d.item).toList()), designs, onProgress: (d, _) => progress.add(d));

    // Ortak fotoğraf bir kez gönderilir.
    expect(encoded, hasLength(3));
    expect(backend.files.keys.where((k) => k.contains('/photos/')), hasLength(3));
    expect(backend.files.keys, contains('orders/u1/AN-TEST/b1.json'));
    expect(backend.order['fileCount'], 5);
    expect(backend.order['uid'], 'u1');
    expect(backend.log.first, 'status:uploading');
    expect(backend.log.last, 'status:ready');
    final jsonIndex = backend.log.indexOf('orders/u1/AN-TEST/b1.json');
    expect(backend.log.lastIndexWhere((l) => l.contains('/photos/')), lessThan(jsonIndex));
    expect(progress.last, 5);

    final design = jsonDecode(utf8.decode(backend.files['orders/u1/AN-TEST/b1.json']!));
    expect(design['qty'], 2);
    expect(design['photoFiles'], {'p0': 'p0', 'p1': 'p1', 'p2': 'p2'});
  });

  test('yarıda kalan yükleme yüklenmiş fotoğrafları atlayarak devam eder', () async {
    final photos = testPhotos(4);
    final backend = _FakeBackend()..failAfter = 2;
    final designs = [_design('b1', photos)];
    final service = OrderUploadService(backend: backend, encode: encode, parallel: 1);
    final order = _order([designs.first.item]);

    await expectLater(service.upload(order, designs), throwsException);
    expect(backend.uploaded, hasLength(2));
    expect(backend.log.last, isNot('status:ready'));

    encoded.clear();
    backend.failAfter = -1;
    await service.upload(order, designs);
    expect(encoded, hasLength(2));
    expect(backend.uploaded, hasLength(4));
    expect(backend.log.last, 'status:ready');
  });
}
