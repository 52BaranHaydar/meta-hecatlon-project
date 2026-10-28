import 'package:flutter/material.dart';
import 'constants/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/main_shell.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AfetDestekApp());
}

class AfetDestekApp extends StatelessWidget {
  const AfetDestekApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return MaterialApp(
      title: 'Afet Destek - Meta AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: ListenableBuilder(
        listenable: authService,
        builder: (context, _) {
          if (authService.isAuthenticated) {
            return const MainShell();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
