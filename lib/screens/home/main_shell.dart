import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
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
  int _currentIndex = 0;
  UserRole? _lastRole;
  ReliefAreaModel? _selectedMapArea;
  AreaCategory? _selectedMapCategory;
  LatLng? _safeReportLocation;

  @override
  void initState() {
    super.initState();
    _lastRole = _authService.currentUser?.role;
    _authService.addListener(_handleAuthChanged);
  }

  @override
  void dispose() {
    _authService.removeListener(_handleAuthChanged);
    super.dispose();
  }

  void _handleAuthChanged() {
    final role = _authService.currentUser?.role;
    if (role == _lastRole) return;

    _lastRole = role;
    if (!mounted) return;
    setState(() {
      _currentIndex = 0;
      _selectedMapArea = null;
      _selectedMapCategory = null;
      _safeReportLocation = null;
    });
  }

  void _navigateToMapWithArea(ReliefAreaModel? area) {
    setState(() {
      _selectedMapArea = area;
      _selectedMapCategory = null;
      _currentIndex = 1;
    });
  }

  void _navigateToMapWithFilter(AreaCategory? category) {
    setState(() {
      _selectedMapArea = null;
      _selectedMapCategory = category;
      _currentIndex = 1;
    });
  }

  void _recordSafeReport(LatLng? location) {
    setState(() {
      _safeReportLocation = location;
    });
  }

  List<NavigationDestination> _destinationsFor(UserRole role) {
    final homeLabel = switch (role) {
      UserRole.citizen => 'Vatandaş Ana Sayfa',
      UserRole.carrier => 'Lojistik Paneli',
      UserRole.admin => 'Kriz Yönetimi',
    };
    final mapLabel = switch (role) {
      UserRole.citizen => 'Toplanma Alanları',
      UserRole.carrier => 'Sevkiyat Haritası',
      UserRole.admin => 'Afet Haritası',
    };
    final triageLabel = switch (role) {
      UserRole.citizen => 'AI Triage',
      UserRole.carrier => 'İhtiyaç Analizi',
      UserRole.admin => 'İhbar Analizi',
    };

    NavigationDestination destination(IconData icon, String label) {
      return NavigationDestination(
        icon: Icon(icon),
        selectedIcon: Icon(icon, color: role.color),
        label: label,
      );
    }

    return [
      destination(role.icon, homeLabel),
      destination(Icons.map_outlined, mapLabel),
      destination(Icons.psychology_outlined, triageLabel),
      destination(Icons.auto_awesome_outlined, 'Llama Asistan'),
    ];
  }

  Widget _screenForIndex(UserModel user, int index) {
    switch (index) {
      case 0:
        return _buildRoleScreen(user);
      case 1:
        return AiDisasterMapScreen(
          key: ValueKey(
            '${_selectedMapArea?.id ?? 'tactical_map'}_${user.role.id}',
          ),
          initialSelectedArea: _selectedMapArea,
          initialFilterCategory: _selectedMapCategory,
          safeReportLocation: _safeReportLocation,
          isActive: _currentIndex == 1,
        );
      case 2:
        return const AiTriageScreen();
      case 3:
        return const AiAssistantScreen();
      default:
        throw RangeError.index(index, _destinationsFor(user.role));
    }
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
            Text(
              'Rol Değiştir (Demo)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
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
                  color: isCurrent
                      ? role.color.withValues(alpha: 0.1)
                      : Colors.transparent,
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
                  trailing: isCurrent
                      ? Icon(Icons.check_circle_rounded, color: role.color)
                      : null,
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
            child: const Text(
              'Kapat',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      user.role.title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: user.role.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              const Emergency112Button(compact: true),
              IconButton(
                tooltip: 'Rol Değiştir (Demo)',
                icon: const Icon(Icons.swap_horiz_rounded),
                onPressed: () => _showRoleSwitcherDialog(context, user),
              ),
              IconButton(
                tooltip: 'Çıkış Yap',
                icon: const Icon(Icons.logout_rounded, size: 20),
                onPressed: _handleLogout,
              ),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: List.generate(
              _destinationsFor(user.role).length,
              (index) => _screenForIndex(user, index),
            ),
          ),
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
              indicatorColor: user.role.color.withValues(alpha: 0.14),
              height: 68,
              destinations: _destinationsFor(user.role),
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
          onNavigateToMapWithFilter: _navigateToMapWithFilter,
          onSafeReport: _recordSafeReport,
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
