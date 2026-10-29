import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'constants/app_theme.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/main_shell.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (DefaultFirebaseOptions.hasConfiguredApiKey) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      // Uses native android/app/google-services.json automatically on Android
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }
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
