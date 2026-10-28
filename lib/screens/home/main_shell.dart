import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/relief_area_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/emergency_112_button.dart';
import '../ai/ai_assistant_screen.dart';
import '../ai/ai_triage_screen.dart';
import '../auth/login_screen.dart';
import '../map/ai_disaster_map_screen.dart';
import 'admin_home_screen.dart';
import 'carrier_home_screen.dart';
import 'citizen_home_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _authService = AuthService();
  int _currentIndex = 0; // 0: Harita, 1: AI Triage, 2: Llama Asistan, 3: Panel & Profil
  ReliefAreaModel? _selectedMapArea;

  void _navigateToMapWithArea(ReliefAreaModel? area) {
    setState(() {
      _selectedMapArea = area;
      _currentIndex = 0;
    });
  }

  void _showRoleSwitcherDialog(BuildContext context, UserModel currentUser) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: const [
            Icon(Icons.switch_account_rounded, color: AppColors.primaryBlue),
            SizedBox(width: 8),
            Text('Rol Değiştir (Demo)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Hackathon sunumunda tüm rolleri test etmek için anlık rol değiştirebilirsiniz:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ...UserRole.values.map((role) {
              final isCurrent = currentUser.role == role;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isCurrent ? role.color.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCurrent ? role.color : AppColors.border,
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  leading: Icon(role.icon, color: role.color),
                  title: Text(
                    role.title,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                      color: isCurrent ? role.color : AppColors.textPrimary,
                    ),
                  ),
                  trailing: isCurrent ? Icon(Icons.check_circle_rounded, color: role.color) : null,
                  onTap: () {
                    _authService.switchDemoRole(role);
                    Navigator.pop(ctx);
                  },
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _handleLogout() {
    _authService.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _authService,
      builder: (context, _) {
        final user = _authService.currentUser ?? AuthService.demoUsers.first;

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 1,
            backgroundColor: Colors.white,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: user.role.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(user.role.icon, color: user.role.color, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AFET DESTEK',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.3),
                    ),
                    Text(
                      user.role.title,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: user.role.color),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              // Mandatory 112 Emergency Button
              const Emergency112Button(compact: true),

              // Fast Role Switcher
              IconButton(
                tooltip: 'Rol Değiştir (Demo)',
                icon: const Icon(Icons.swap_horiz_rounded),
                onPressed: () => _showRoleSwitcherDialog(context, user),
              ),

              // Logout
              IconButton(
                tooltip: 'Çıkış Yap',
                icon: const Icon(Icons.logout_rounded, size: 20),
                onPressed: _handleLogout,
              ),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: [
              // 0: Harita & Rota (Nereye Gitmeli?)
              AiDisasterMapScreen(
                key: ValueKey(_selectedMapArea?.id ?? 'tactical_map'),
                initialSelectedArea: _selectedMapArea,
              ),

              // 1: Meta AI Triage İstasyonu (Sesli / Metin İhbar Sınıflandırma)
              const AiTriageScreen(),

              // 2: Meta Llama 3 Afet Asistanı (Soru & Cevap)
              const AiAssistantScreen(),

              // 3: Rol Bazlı Ana Panel (Vatandaş, Taşıyıcı, Admin)
              _buildRoleScreen(user),
            ],
          ),

          // Spacious, Modern Bottom Navigation Bar
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundColor: Colors.white,
              indicatorColor: AppColors.primaryBlue.withValues(alpha: 0.14),
              height: 68,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map_rounded, color: AppColors.primaryBlue),
                  label: 'Nereye Gitmeli?',
                ),
                NavigationDestination(
                  icon: Icon(Icons.psychology_outlined),
                  selectedIcon: Icon(Icons.psychology_rounded, color: AppColors.primaryBlue),
                  label: 'Meta AI Triage',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  selectedIcon: Icon(Icons.auto_awesome_rounded, color: AppColors.primaryBlue),
                  label: 'Llama Asistan',
                ),
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.primaryBlue),
                  label: 'Kriz Paneli',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleScreen(UserModel user) {
    switch (user.role) {
      case UserRole.citizen:
        return CitizenHomeScreen(
          user: user,
          onNavigateToMap: _navigateToMapWithArea,
        );
      case UserRole.carrier:
        return CarrierHomeScreen(
          user: user,
          onNavigateToMap: _navigateToMapWithArea,
        );
      case UserRole.admin:
        return AdminHomeScreen(
          user: user,
          onNavigateToMap: _navigateToMapWithArea,
        );
    }
  }
}
