import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../constants/strings_tr.dart';
import '../models/user_profile.dart';
import 'firebase_order_backend.dart';

/// E-posta ile kayıt / giriş ve kullanıcı profili. Firebase yoksa her zaman "giriş yapılmamış"tır.
class AuthService extends ChangeNotifier {
  AuthService() {
    if (!FirebaseSetup.available) return;
    FirebaseAuth.instance.userChanges().listen((u) async {
      _user = u;
      profile = u == null || u.isAnonymous ? null : await _loadProfile(u.uid);
      ready = true;
      notifyListeners();
    });
  }

  User? _user;
  UserProfile? profile;

  /// İlk oturum durumu geldi mi?
  bool ready = !FirebaseSetup.available;

  bool get available => FirebaseSetup.available;

  /// E-posta ile kayıtlı ve oturum açık mı (anonim değil)?
  bool get signedIn => _user != null && !_user!.isAnonymous;

  bool get emailVerified => _user?.emailVerified ?? false;

  String? get email => _user?.email;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => FirebaseFirestore.instance.collection('users').doc(uid);

  Future<UserProfile?> _loadProfile(String uid) async {
    try {
      final snap = await _doc(uid).get();
      return snap.exists ? UserProfile.fromJson(snap.data()!) : null;
    } catch (_) {
      return null;
    }
  }

  /// Yeni hesap. Anonim oturum varsa ona bağlanır; önceki siparişler aynı kullanıcıda kalır.
  Future<void> register(UserProfile p, String password) async {
    await _guard(() async {
      final auth = FirebaseAuth.instance;
      final cred = EmailAuthProvider.credential(email: p.email, password: password);
      final current = auth.currentUser;
      final user = current != null && current.isAnonymous
          ? (await current.linkWithCredential(cred)).user!
          : (await auth.createUserWithEmailAndPassword(email: p.email, password: password)).user!;
      final now = DateTime.now().millisecondsSinceEpoch;
      p
        ..createdAtMs = now
        ..kvkkAcceptedAtMs = now;
      await _doc(user.uid).set(p.toJson());
      profile = p;
      await user.sendEmailVerification();
      await user.reload();
    });
  }

  Future<void> signIn(String email, String password) =>
      _guard(() => FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password));

  Future<void> signOut() => FirebaseAuth.instance.signOut();

  Future<void> resetPassword(String email) => _guard(() => FirebaseAuth.instance.sendPasswordResetEmail(email: email));

  Future<void> resendVerification() => _guard(() => _user!.sendEmailVerification());

  /// Doğrulama bağlantısına tıkladıktan sonra durumu tazeler.
  Future<void> refresh() async {
    await _user?.reload();
    _user = FirebaseAuth.instance.currentUser;
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile p) async {
    await _guard(() => _doc(_user!.uid).set(p.toJson(), SetOptions(merge: true)));
    profile = p;
    notifyListeners();
  }

  /// Hesabı ve profil kaydını siler. Güvenlik gereği şifre tekrar sorulur.
  Future<void> deleteAccount(String password) async {
    await _guard(() async {
      final user = _user!;
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: password));
      await _doc(user.uid).delete();
      await user.delete();
    });
  }

  /// Firebase hatalarını kullanıcıya gösterilecek Türkçe mesaja çevirir.
  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on FirebaseAuthException catch (e) {
      throw AuthError(switch (e.code) {
        'email-already-in-use' || 'credential-already-in-use' => S.authEmailInUse,
        'invalid-email' => S.authInvalidEmail,
        'weak-password' => S.authWeakPassword,
        'user-not-found' || 'wrong-password' || 'invalid-credential' => S.authWrongCredentials,
        'too-many-requests' => S.authTooMany,
        'network-request-failed' => S.authNetwork,
        _ => '${S.authGeneric} (${e.code})',
      });
    }
  }
}

class AuthError implements Exception {
  final String message;
  const AuthError(this.message);

  @override
  String toString() => message;
}
