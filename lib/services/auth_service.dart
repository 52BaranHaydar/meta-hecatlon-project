import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  FirebaseAuth? get _firebaseAuth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  // Pre-configured demo test users for quick hackathon testing
  static final List<UserModel> demoUsers = [
    UserModel(
      uid: 'demo_citizen_01',
      name: 'Ahmet Yılmaz',
      email: 'vatandas@afet.org',
      phone: '+90 555 123 4567',
      role: UserRole.citizen,
    ),
    UserModel(
      uid: 'demo_carrier_01',
      name: 'Mehmet Demir (Lojistik)',
      email: 'tasiyici@afet.org',
      phone: '+90 532 987 6543',
      role: UserRole.carrier,
    ),
    UserModel(
      uid: 'demo_admin_01',
      name: 'Kriz Masası Koordinatörü',
      email: 'admin@afet.org',
      phone: '+90 505 000 1122',
      role: UserRole.admin,
    ),
  ];

  Future<bool> login({
    required String email,
    required String password,
    UserRole? preferredRole,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (email.trim().isEmpty || password.trim().isEmpty) {
        _errorMessage = 'Lütfen e-posta ve şifrenizi giriniz.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Check if it is a quick demo user first
      final demoMatch = demoUsers.where(
        (u) => u.email.toLowerCase() == email.trim().toLowerCase(),
      );
      if (demoMatch.isNotEmpty) {
        _currentUser = demoMatch.first;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      // Try real Firebase Auth login
      final auth = _firebaseAuth;
      final db = _firestore;
      if (auth != null) {
        final credential = await auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        final fbUser = credential.user;
        if (fbUser != null) {
          if (db != null) {
            final doc = await db.collection('users').doc(fbUser.uid).get();
            if (doc.exists && doc.data() != null) {
              _currentUser = UserModel.fromMap(doc.data()!, id: fbUser.uid);
              _isLoading = false;
              notifyListeners();
              return true;
            }
          }
          _currentUser = UserModel(
            uid: fbUser.uid,
            name: fbUser.displayName ?? email.split('@').first,
            email: fbUser.email ?? email.trim(),
            role: preferredRole ?? UserRole.citizen,
          );
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      // Fallback if Firebase Auth is not yet enabled in Console
      _currentUser = UserModel(
        uid: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: email.split('@').first,
        email: email.trim(),
        role: preferredRole ?? UserRole.citizen,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        _errorMessage = 'E-posta veya şifre hatalı.';
      } else if (e.code == 'operation-not-allowed' || e.code == 'configuration-not-found') {
        // Fallback to local session if Email/Password provider isn't toggled on yet in Firebase Console
        _currentUser = UserModel(
          uid: 'user_${DateTime.now().millisecondsSinceEpoch}',
          name: email.split('@').first,
          email: email.trim(),
          role: preferredRole ?? UserRole.citizen,
        );
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Giriş hatası: ${e.message ?? e.code}';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Giriş yapılırken bir hata oluştu: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (name.trim().isEmpty || email.trim().isEmpty || password.length < 6) {
        _errorMessage = 'Lütfen tüm alanları doğru ve eksiksiz doldurun (Şifre en az 6 karakter).';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final auth = _firebaseAuth;
      final db = _firestore;
      if (auth != null) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        final fbUser = credential.user;
        if (fbUser != null) {
          await fbUser.updateDisplayName(name.trim());
          final newUser = UserModel(
            uid: fbUser.uid,
            name: name.trim(),
            email: email.trim(),
            phone: phone?.trim(),
            role: role,
            createdAt: DateTime.now(),
          );
          if (db != null) {
            try {
              await db.collection('users').doc(fbUser.uid).set(newUser.toMap());
            } catch (fe) {
              debugPrint('Firestore user write note: $fe');
            }
          }
          _currentUser = newUser;
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      _currentUser = UserModel(
        uid: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: name.trim(),
        email: email.trim(),
        phone: phone?.trim(),
        role: role,
        createdAt: DateTime.now(),
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _errorMessage = 'Bu e-posta adresi zaten kayıtlı.';
        _isLoading = false;
        notifyListeners();
        return false;
      } else if (e.code == 'operation-not-allowed' || e.code == 'configuration-not-found') {
        // Fallback if Email/Password provider isn't enabled yet in Console
        final fallbackUser = UserModel(
          uid: 'user_${DateTime.now().millisecondsSinceEpoch}',
          name: name.trim(),
          email: email.trim(),
          phone: phone?.trim(),
          role: role,
          createdAt: DateTime.now(),
        );
        try {
          await _firestore?.collection('users').doc(fallbackUser.uid).set(fallbackUser.toMap());
        } catch (_) {}
        _currentUser = fallbackUser;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = 'Kayıt hatası: ${e.message ?? e.code}';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Kayıt sırasında hata oluştu: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (email.trim().isEmpty || !email.contains('@')) {
        _errorMessage = 'Lütfen geçerli bir e-posta adresi giriniz.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final auth = _firebaseAuth;
      if (auth != null) {
        try {
          await auth.sendPasswordResetEmail(email: email.trim());
        } catch (_) {}
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Şifre sıfırlama e-postası gönderilemedi: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void switchDemoRole(UserRole role) {
    final demo = demoUsers.firstWhere((u) => u.role == role);
    _currentUser = demo;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _firebaseAuth?.signOut();
    } catch (_) {}
    _currentUser = null;
    notifyListeners();
  }
}
