import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/emergency_112_button.dart';
import '../home/main_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  UserRole _selectedRole = UserRole.citizen;
  final _authService = AuthService();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şifreler eşleşmiyor!'),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
      return;
    }

    final success = await _authService.register(
      name: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
      role: _selectedRole,
    );

    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } else if (mounted && _authService.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_authService.errorMessage!),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Yeni Hesap Oluştur'),
        actions: const [
          Emergency112Button(compact: true),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _authService,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Aramıza Katılın',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Afet anında dayanışma ve hızlı koordinasyon için hesabınızı oluşturun.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Role Picker
                    const Text(
                      'Kullanıcı Rolü Seçiniz',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildRoleSelectorCard(
                            role: UserRole.citizen,
                            subtitle: 'Toplanma alanı, yardım talebi & asistan',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildRoleSelectorCard(
                            role: UserRole.carrier,
                            subtitle: 'Yardım malzemesi taşıma & lojistik',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Inputs
                    CustomTextField(
                      controller: _nameController,
                      label: 'Ad Soyad',
                      hint: 'örn. Ahmet Yılmaz',
                      prefixIcon: Icons.person_outline_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Ad soyad zorunludur' : null,
                    ),
                    const SizedBox(height: 16),

                    CustomTextField(
                      controller: _phoneController,
                      label: 'Telefon Numarası',
                      hint: '05XX XXX XX XX',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().length < 10) ? 'Geçerli bir telefon girin' : null,
                    ),
                    const SizedBox(height: 16),

                    CustomTextField(
                      controller: _emailController,
                      label: 'E-Posta Adresi',
                      hint: 'ornek@afet.org',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'E-posta zorunludur';
                        if (!v.contains('@')) return 'Geçerli bir e-posta girin';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    CustomTextField(
                      controller: _passwordController,
                      label: 'Şifre',
                      hint: 'En az 6 karakter',
                      prefixIcon: Icons.lock_outline_rounded,
                      isPassword: true,
                      validator: (v) => (v == null || v.length < 6) ? 'Şifre en az 6 karakter olmalı' : null,
                    ),
                    const SizedBox(height: 16),

                    CustomTextField(
                      controller: _confirmPasswordController,
                      label: 'Şifre Tekrar',
                      hint: 'Şifrenizi tekrar giriniz',
                      prefixIcon: Icons.lock_reset_rounded,
                      isPassword: true,
                      validator: (v) => (v == null || v.isEmpty) ? 'Şifre tekrarı zorunludur' : null,
                    ),
                    const SizedBox(height: 28),

                    CustomPrimaryButton(
                      text: 'Hesap Oluştur ve Giriş Yap',
                      icon: Icons.check_circle_rounded,
                      isLoading: _authService.isLoading,
                      onPressed: _handleRegister,
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Zaten bir hesabınız var mı? ',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'Giriş Yap',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRoleSelectorCard({
    required UserRole role,
    required String subtitle,
  }) {
    final isSelected = _selectedRole == role;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? role.color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? role.color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  role.icon,
                  color: isSelected ? role.color : AppColors.textSecondary,
                  size: 24,
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: role.color, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              role.title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isSelected ? role.color : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
