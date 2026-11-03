import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:photo_manager/photo_manager.dart';

import '../firebase_options.dart';
import '../models/photo_book.dart';
import '../repositories/photo_repository.dart';
import 'order_upload_service.dart';

/// Firebase başlatılamazsa (ör. ağ/yapılandırma sorunu) uygulama yerel çalışmaya devam eder;
/// yalnız sipariş gönderilemez.
class FirebaseSetup {
  static bool available = false;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      available = true;
    } catch (_) {
      available = false;
    }
  }
}

/// Siparişler: Firestore `orders/{ref}`, dosyalar Storage `orders/{uid}/{ref}/...`.
class FirebaseOrderBackend implements OrderBackend {
  final _auth = FirebaseAuth.instance;
  final _orders = FirebaseFirestore.instance.collection('orders');
  final _storage = FirebaseStorage.instance;

  @override
  Future<String> signIn() async {
    final user = _auth.currentUser ?? (await _auth.signInAnonymously()).user!;
    return user.uid;
  }

  @override
  Future<Set<String>> uploadedPhotos(String orderRef) async {
    final snap = await _orders.doc(orderRef).get();
    return {...(snap.data()?['uploadedIds'] as List? ?? const []).cast<String>()};
  }

  @override
  Future<void> saveOrder(String orderRef, Map<String, dynamic> data) =>
      _orders.doc(orderRef).set({...data, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  @override
  Future<void> putFile(String path, Uint8List bytes, String contentType) async {
    await _storage.ref(path).putData(bytes, SettableMetadata(contentType: contentType));
  }

  @override
  Future<void> markPhotoUploaded(String orderRef, String fileName, int bytes) => _orders.doc(orderRef).update({
    'uploadedIds': FieldValue.arrayUnion([fileName]),
    'totalBytes': FieldValue.increment(bytes),
  });
}

/// Galeriden fotoğrafı istenen boyutta, kalite 90 JPEG olarak alır (cihazda, yerel kodla).
Future<Uint8List> encodeGalleryPhoto(BookPhoto photo, int width, int height) async {
  final entity = await PhotoRepository.entity(photo.id);
  if (entity == null) throw StateError('Fotoğraf bulunamadı: ${photo.id}');
  final size = ThumbnailSize(width, height);
  final option = Platform.isIOS
      ? ThumbnailOption.ios(
          size: size,
          quality: 90,
          deliveryMode: DeliveryMode.highQualityFormat,
          resizeMode: ResizeMode.exact,
        )
      : ThumbnailOption(size: size, quality: 90);
  final bytes = await entity.thumbnailDataWithOption(option);
  if (bytes == null) throw StateError('Fotoğraf okunamadı: ${photo.id}');
  return bytes;
}
