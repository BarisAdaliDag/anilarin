import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/basket_item.dart';
import '../models/order.dart';
import '../models/photo_book.dart';
import '../models/print_set.dart';

/// Siparişin gönderildiği sunucu (Firebase). Testlerde sahtesi kullanılır.
abstract class OrderBackend {
  /// Oturum açar (gerekirse anonim) ve kullanıcı kimliğini döner.
  Future<String> signIn();

  /// Daha önce yüklenmiş fotoğraf dosya adları (yarıda kalan yüklemeye devam için).
  Future<Set<String>> uploadedPhotos(String orderRef);

  /// Sipariş kaydını birleştirerek yazar.
  Future<void> saveOrder(String orderRef, Map<String, dynamic> data);

  Future<void> putFile(String path, Uint8List bytes, String contentType);

  Future<void> markPhotoUploaded(String orderRef, String fileName, int bytes);
}

/// Fotoğrafı baskıya uygun boyutta JPEG olarak verir.
typedef PhotoEncoder = Future<Uint8List> Function(BookPhoto photo, int width, int height);

/// Gönderilecek bir tasarım: kitap ya da baskı seti.
class OrderDesign {
  final BasketItem item;
  final Map<String, dynamic> json;
  final List<BookPhoto> photos;

  const OrderDesign(this.item, this.json, this.photos);

  factory OrderDesign.book(BasketItem item, PhotoBook book) => OrderDesign(item, book.toJson(), [
    for (final id in book.usedPhotoIds)
      if (book.photos[id] != null) book.photos[id]!,
  ]);

  factory OrderDesign.prints(BasketItem item, PrintSet set) =>
      OrderDesign(item, set.toJson(), [for (final i in set.items) i.photo]);
}

/// Siparişi matbaaya gönderir: her fotoğraf ayrı dosya, en son tasarım JSON'u.
///
/// Storage düzeni: `orders/{uid}/{ref}/photos/{dosya}.jpg` ve `orders/{uid}/{ref}/{tasarım}.json`.
/// Yükleme kesilirse tekrar çağrıldığında yüklenmiş fotoğrafları atlar.
class OrderUploadService {
  OrderUploadService({required this.backend, required this.encode, this.parallel = 3});

  final OrderBackend backend;
  final PhotoEncoder encode;
  final int parallel;

  /// Baskı için uzun kenar sınırı (A4 tam sayfa 300 DPI ≈ 3508 px).
  static const maxLongSide = 4000;

  /// Orijinali büyütmeden, oranı koruyarak hedef piksel boyutu.
  static (int, int) targetSize(int width, int height) {
    final long = math.max(width, height);
    if (long <= maxLongSide || long == 0) return (width, height);
    final k = maxLongSide / long;
    return (math.max(1, (width * k).round()), math.max(1, (height * k).round()));
  }

  /// photo_manager kimlikleri `/` içerebilir; dosya adı için güvenli hale getirir.
  static String fileNameOf(String photoId) => photoId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  Future<void> upload(Order order, List<OrderDesign> designs, {void Function(int done, int total)? onProgress}) async {
    final uid = await backend.signIn();
    final root = 'orders/$uid/${order.reference}';
    final photos = <String, BookPhoto>{
      for (final d in designs)
        for (final p in d.photos) fileNameOf(p.id): p,
    };
    final total = photos.length + designs.length;

    await backend.saveOrder(order.reference, {
      'uid': uid,
      'status': 'uploading',
      'order': order.toJson(),
      'fileCount': total,
      'photos': {for (final e in photos.entries) e.key: e.value.id},
    });

    final done = await backend.uploadedPhotos(order.reference);
    var count = done.length;
    onProgress?.call(count, total);

    final queue = photos.entries.where((e) => !done.contains(e.key)).toList();
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final e = queue.removeLast();
        final (w, h) = targetSize(e.value.width, e.value.height);
        final bytes = await encode(e.value, w, h);
        await backend.putFile('$root/photos/${e.key}.jpg', bytes, 'image/jpeg');
        await backend.markPhotoUploaded(order.reference, e.key, bytes.length);
        onProgress?.call(++count, total);
      }
    }

    await Future.wait([for (var i = 0; i < math.min(parallel, math.max(1, queue.length)); i++) worker()]);

    // Tasarımlar en son: matbaa "ready" görmeden eksik sipariş indirmez.
    for (final d in designs) {
      final data = {
        ...d.json,
        'qty': d.item.quantity,
        'photoFiles': {for (final p in d.photos) p.id: fileNameOf(p.id)},
      };
      await backend.putFile(
        '$root/${d.item.bookId}.json',
        Uint8List.fromList(utf8.encode(jsonEncode(data))),
        'application/json',
      );
      onProgress?.call(++count, total);
    }

    await backend.saveOrder(order.reference, {'status': 'ready'});
  }
}
