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
      // Simulate network latency
      await Future.delayed(const Duration(milliseconds: 600));

      if (email.trim().isEmpty || password.trim().isEmpty) {
        _errorMessage = 'Lütfen e-posta ve şifrenizi giriniz.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Find matching demo user or create user with role
      UserModel? matched = demoUsers.firstWhere(
        (u) => u.email.toLowerCase() == email.trim().toLowerCase(),
        orElse: () => UserModel(
          uid: 'user_${DateTime.now().millisecondsSinceEpoch}',
          name: email.split('@').first,
          email: email.trim(),
          role: preferredRole ?? UserRole.citizen,
        ),
      );

      _currentUser = matched;
      _isLoading = false;
      notifyListeners();
      return true;
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
      await Future.delayed(const Duration(milliseconds: 700));

      if (name.trim().isEmpty || email.trim().isEmpty || password.length < 6) {
        _errorMessage = 'Lütfen tüm alanları doğru ve eksiksiz doldurun (Şifre en az 6 karakter).';
        _isLoading = false;
        notifyListeners();
        return false;
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
      await Future.delayed(const Duration(milliseconds: 700));
      if (email.trim().isEmpty || !email.contains('@')) {
        _errorMessage = 'Lütfen geçerli bir e-posta adresi giriniz.';
        _isLoading = false;
        notifyListeners();
        return false;
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

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
