import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/emergency_112_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await _authService.sendPasswordResetEmail(_emailController.text);
    if (success && mounted) {
      setState(() {
        _emailSent = true;
      });
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
        title: const Text('Şifre Sıfırlama'),
        actions: const [
          Emergency112Button(compact: true),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _authService,
          builder: (context, _) {
            if (_emailSent) {
              return _buildSuccessView();
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          size: 52,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Şifrenizi mi Unuttunuz?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Endişelenmeyin! Hesabınıza bağlı e-posta adresinizi girdiğinizde size güvenli bir şifre yenileme bağlantısı göndereceğiz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),

                    CustomTextField(
                      controller: _emailController,
                      label: 'Kayıtlı E-Posta Adresi',
                      hint: 'ornek@afet.org',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Lütfen e-posta adresinizi giriniz';
                        }
                        if (!val.contains('@')) {
                          return 'Geçerli bir e-posta adresi giriniz';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    CustomPrimaryButton(
                      text: 'Sıfırlama Bağlantısı Gönder',
                      icon: Icons.send_rounded,
                      isLoading: _authService.isLoading,
                      onPressed: _handleReset,
                    ),
                    const SizedBox(height: 16),

                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Giriş Ekranına Geri Dön'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              size: 64,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Bağlantı Gönderildi!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_emailController.text} adresine şifre sıfırlama talimatları gönderildi. Lütfen gelen kutunuzu ve spam klasörünüzü kontrol edin.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          CustomPrimaryButton(
            text: 'Giriş Ekranına Dön',
            icon: Icons.check_circle_outline_rounded,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _emailSent = false;
              });
            },
            child: const Text('Farklı Bir E-posta Dene'),
          ),
        ],
      ),
    );
  }
}
