import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  AuthService._internal() {
    _restoreSession();
  }

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Only specific authorized emails are granted AFAD / Admin role
  static bool isAuthorizedAdminEmail(String email) {
    final lower = email.trim().toLowerCase();
    return lower == 'baranhaydar80@gmail.com' ||
        lower == 'admin@afet.org' ||
        lower == 'afad@afet.org' ||
        lower.endsWith('@afad.gov.tr') ||
        lower.startsWith('admin@') ||
        lower.startsWith('afad@') ||
        lower.startsWith('kriz@');
  }

  static UserRole resolveRoleForEmail(String email, UserRole requestedRole) {
    if (isAuthorizedAdminEmail(email)) {
      return UserRole.admin;
    }
    // Never allow non-admin emails to become admin
    if (requestedRole == UserRole.admin) {
      return UserRole.citizen;
    }
    return requestedRole;
  }

  Future<void> _restoreSession() async {
    try {
      final fbUser = _firebaseAuth.currentUser;
      if (fbUser != null && fbUser.email != null) {
        _currentUser = await _loadUserProfile(fbUser);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Session restore note: $e');
    }
  }

  Future<UserModel> _loadUserProfile(
    User fbUser, {
    UserRole? fallbackRole,
    String? fallbackName,
    String? fallbackPhone,
  }) async {
    final email = (fbUser.email ?? '').trim().toLowerCase();

    // 1. Try reading from Firestore 'users/{uid}'
    try {
      final doc = await _firestore.collection('users').doc(fbUser.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final loaded = UserModel.fromMap(data, id: fbUser.uid);
        final enforcedRole = isAuthorizedAdminEmail(email)
            ? UserRole.admin
            : loaded.role;
        final finalUser = loaded.copyWith(role: enforcedRole);
        await _cacheRoleLocally(email, finalUser.role, finalUser.name);
        return finalUser;
      }
    } catch (e) {
      debugPrint('Firestore user read note: $e');
    }

    // 2. Try reading from local SharedPreferences cache by email
    UserRole? cachedRole;
    String? cachedName;
    try {
      final prefs = await SharedPreferences.getInstance();
      final roleStr = prefs.getString('user_role_$email');
      cachedName = prefs.getString('user_name_$email');
      if (roleStr != null) {
        cachedRole = UserRole.fromString(roleStr);
      }
    } catch (_) {}

    final resolvedRole = resolveRoleForEmail(
      email,
      cachedRole ?? fallbackRole ?? UserRole.citizen,
    );

    final model = UserModel(
      uid: fbUser.uid,
      name:
          fallbackName ??
          fbUser.displayName ??
          cachedName ??
          email.split('@').first,
      email: email,
      phone: fallbackPhone,
      role: resolvedRole,
    );

    // Ensure Firestore document is written if missing
    try {
      await _firestore
          .collection('users')
          .doc(fbUser.uid)
          .set(model.toMap(), SetOptions(merge: true));
    } catch (_) {}

    await _cacheRoleLocally(email, model.role, model.name);
    return model;
  }

  Future<void> _cacheRoleLocally(
    String email,
    UserRole role,
    String name,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role_${email.toLowerCase()}', role.id);
      await prefs.setString('user_name_${email.toLowerCase()}', name);
    } catch (_) {}
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final cleanEmail = email.trim().toLowerCase();

    try {
      if (cleanEmail.isEmpty || password.isEmpty) {
        _errorMessage = 'Lütfen e-posta ve şifrenizi giriniz.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final fbUser = credential.user;
      if (fbUser == null) {
        _errorMessage = 'Kullanıcı doğrulanamadı.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentUser = await _loadUserProfile(fbUser);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-credential':
        case 'wrong-password':
          _errorMessage =
              'E-posta veya şifre hatalı. Hesabınız yoksa lütfen "Kayıt Ol" ekranından kayıt olun.';
          break;
        case 'invalid-email':
          _errorMessage = 'Geçersiz e-posta adresi formatı.';
          break;
        case 'user-disabled':
          _errorMessage = 'Bu kullanıcı hesabı devre dışı bırakılmış.';
          break;
        case 'too-many-requests':
          _errorMessage =
              'Çok fazla başarısız deneme yapıldı. Lütfen biraz bekleyip tekrar deneyin.';
          break;
        case 'network-request-failed':
          _errorMessage =
              'İnternet bağlantısı kurulamadı. Lütfen cihazınızın internet/Wi-Fi bağlantısını kontrol ediniz.';
          break;
        case 'operation-not-allowed':
        case 'configuration-not-found':
          _errorMessage =
              'Firebase Console üzerinde Email/Password girişi henüz etkinleştirilmemiş.';
          break;
        default:
          _errorMessage = 'Firebase giriş hatası: ${e.message ?? e.code}';
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

    final cleanEmail = email.trim().toLowerCase();

    try {
      if (name.trim().isEmpty || cleanEmail.isEmpty || password.length < 6) {
        _errorMessage =
            'Lütfen tüm alanları eksiksiz doldurun (Şifre en az 6 karakter olmalıdır).';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final assignedRole = resolveRoleForEmail(cleanEmail, role);

      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final fbUser = credential.user;
      if (fbUser == null) {
        _errorMessage = 'Hesap oluşturulamadı.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await fbUser.updateDisplayName(name.trim());

      final newUser = UserModel(
        uid: fbUser.uid,
        name: name.trim(),
        email: cleanEmail,
        phone: phone?.trim(),
        role: assignedRole,
        createdAt: DateTime.now(),
      );

      await _cacheRoleLocally(cleanEmail, assignedRole, name.trim());

      try {
        await _firestore
            .collection('users')
            .doc(fbUser.uid)
            .set(newUser.toMap());
      } catch (fe) {
        debugPrint('Firestore user write note: $fe');
      }

      _currentUser = newUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _errorMessage =
            'Bu e-posta adresi zaten Firebase\'de kayıtlı. Lütfen Giriş Yap ekranından giriş yapın.';
      } else if (e.code == 'weak-password') {
        _errorMessage = 'Şifre çok zayıf (en az 6 karakter giriniz).';
      } else if (e.code == 'invalid-email') {
        _errorMessage = 'Geçerli bir e-posta adresi giriniz.';
      } else if (e.code == 'network-request-failed' ||
          (e.message != null && e.message!.contains('network error'))) {
        _errorMessage =
            'İnternet bağlantısı kurulamadı. Lütfen emülatör veya cihazın internet/Wi-Fi bağlantısını kontrol ediniz.';
      } else {
        _errorMessage = 'Firebase kayıt hatası: ${e.message ?? e.code}';
      }
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
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = 'Şifre sıfırlama hatası: ${e.message ?? e.code}';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Şifre sıfırlama e-postası gönderilemedi: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  @visibleForTesting
  void switchDemoRole(UserRole role) {
    _currentUser = UserModel(
      uid: 'demo-',
      name: 'Demo ',
      email: role == UserRole.admin ? 'baranhaydar80@gmail.com' : 'demo@afet.org',
      role: role,
    );
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
    } catch (_) {}
    _currentUser = null;
    notifyListeners();
  }
}
