import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import 'emergency_sos_screen.dart';

class Emergency112Button extends StatelessWidget {
  final bool compact;

  const Emergency112Button({
    super.key,
    this.compact = false,
  });

  void _showEmergencySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const EmergencyActionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: ElevatedButton.icon(
          onPressed: () => _showEmergencySheet(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.emergencyRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 2,
          ),
          icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
          label: const Text(
            '112 ACİL',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showEmergencySheet(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE53935), Color(0xFFC62828)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.emergencyRed.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.emergency_rounded, color: Colors.white, size: 20),
              SizedBox(width: 6),
              Text(
                '112 ACİL ARAMA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmergencyActionSheet extends StatelessWidget {
  const EmergencyActionSheet({super.key});

  Future<void> _callNumber(BuildContext context, String number) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();

    try {
      final launched = await launchUrl(
        Uri(scheme: 'tel', path: number),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('$number için telefon arama ekranı açılamadı.'),
            backgroundColor: AppColors.emergencyRed,
          ),
        );
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Telefon araması başlatılamadı: $error'),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
    }
  }

  void _openSosScreen(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const EmergencySosScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  Widget _callButton(
    BuildContext context, {
    required String number,
    required String title,
    required IconData icon,
    Color color = AppColors.primaryBlue,
  }) {
    return ElevatedButton.icon(
      onPressed: () => _callNumber(context, number),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon),
      label: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.emergencyLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emergency_rounded,
                      color: AppColors.emergencyRed,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Acil Yardım Hatları',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Arama telefon uygulamasında açılır.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _callButton(
                context,
                number: '112',
                title: '112 Acil Çağrı Merkezi',
                icon: Icons.call_rounded,
                color: AppColors.emergencyRed,
              ),
              const SizedBox(height: 8),
              _callButton(
                context,
                number: '122',
                title: '122 AFAD',
                icon: Icons.support_agent_rounded,
              ),
              const SizedBox(height: 8),
              _callButton(
                context,
                number: '187',
                title: '187 Doğalgaz Acil',
                icon: Icons.local_fire_department_rounded,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _openSosScreen(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(
                    color: AppColors.emergencyRed,
                    width: 1.5,
                  ),
                  foregroundColor: AppColors.emergencyRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.flash_on_rounded),
                label: const Text(
                  'Tam Ekran SOS Flaşör + Enkaz Düdüğü',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Uygulama konumunuzu arama sırasında otomatik olarak iletmez; konumunuzu operatöre söyleyin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
