import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SafeArea(
        top: false,
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
                  decoration: BoxDecoration(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '112 Acil Çağrı Merkezi',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Hayati tehlike durumunda doğrudan arayınız',
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
            const SizedBox(height: 20),

            // Emergency GPS Box for operator
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.my_location_rounded, color: AppColors.primaryBlue, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Mevcut Konumunuz (Operatöre iletiniz):',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '37.0662° K, 37.3833° D (Gaziantep / Şehitkamil)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Big Call Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('112 Acil Çağrı simüle ediliyor... (Gerçek cihazda tel:112 arama ekranı açılır)'),
                    backgroundColor: AppColors.emergencyRed,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emergencyRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.call, size: 24),
              label: const Text(
                '112\'Yİ HEMEN ARA',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(height: 12),

            // Whistle / Alarm Button
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Düdük ve yüksek sesli siren çalınıyor!'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.emergencyRed, width: 1.5),
                foregroundColor: AppColors.emergencyRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.volume_up_rounded, size: 20),
              label: const Text(
                'Sesli Düdük / Siren Çal',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
