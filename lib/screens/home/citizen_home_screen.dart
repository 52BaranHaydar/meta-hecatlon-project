import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/relief_area_model.dart';
import '../../models/user_model.dart';
import '../../widgets/common_widgets.dart';

class CitizenHomeScreen extends StatelessWidget {
  final UserModel user;
  final void Function(ReliefAreaModel? area)? onNavigateToMap;

  const CitizenHomeScreen({
    super.key,
    required this.user,
    this.onNavigateToMap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & Status Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Merhaba, ${user.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Vatandaş Portalı',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Güvende misiniz? Yardıma ihtiyacınız olduğunda butona basarak AI destekli afet merkezine bildirimde bulunabilirsiniz.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showHelpRequestModal(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryBlue,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.sos_rounded, color: AppColors.emergencyRed),
                        label: const Text(
                          'YARDIM İSTE',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showAiAssistantModal(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded, color: Colors.amberAccent, size: 18),
                        label: const Text('Meta AI Asistan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Big Banner: "Nereye Gitmeli? Haritada Gör"
          InkWell(
            onTap: () {
              if (onNavigateToMap != null) {
                onNavigateToMap!(ReliefAreaModel.demoAreas.first);
              }
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.map_rounded, color: AppColors.primaryBlue, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Nereye Gitmeli? (Harita & Rota)',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Canlı haritada toplanma alanlarını ve yol tariflerini görün.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.primaryBlue),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick Action Cards
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Yakın Toplanma Alanları',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              TextButton(
                onPressed: () {
                  if (onNavigateToMap != null) {
                    onNavigateToMap!(null);
                  }
                },
                child: const Text('Haritada Aç', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 6),

          ...ReliefAreaModel.demoAreas.take(3).map((area) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: _buildAreaCard(context, area),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAreaCard(BuildContext context, ReliefAreaModel area) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    area.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: area.category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    area.category.title,
                    style: TextStyle(color: area.category.color, fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              area.address,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kapasite: ${area.occupancy} / ${area.capacity} Kişi',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  'Boş Kontenjan: ${area.availableSpots}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (onNavigateToMap != null) {
                    onNavigateToMap!(area);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.navigation_rounded, size: 16),
                label: const Text('Haritada Rotayı Çiz & Buraya Git', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpRequestModal(BuildContext context) {
    final textCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: const [
                Icon(Icons.report_problem_rounded, color: AppColors.emergencyRed),
                SizedBox(width: 8),
                Text('Acil Yardım Talebi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Durumunuzu kısaca yazın. Meta AI mesajınızı aciliyetine göre (enkaz, sağlık, su/gıda, barınma) otomatik sınıflandıracaktır.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Örn: Binamızın önünde su ve bebek mamasına acil ihtiyaç var, 3 aileyiz...',
              ),
            ),
            const SizedBox(height: 16),
            CustomPrimaryButton(
              text: 'Yardım Çağrısını Gönder (AI Sınıflandırma)',
              color: AppColors.emergencyRed,
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Yardım talebiniz Meta AI (classifyReport) ile acil olarak kriz merkezine iletildi!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAiAssistantModal(BuildContext context) {
    final queryCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: const [
                Icon(Icons.auto_awesome, color: AppColors.primaryBlue),
                SizedBox(width: 8),
                Text('Meta Llama Afet Asistanı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Afet rehberleri ve resmi AFAD/Kızılay kılavuzlarından kaynaklı cevaplar üretir.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: queryCtrl,
              decoration: const InputDecoration(
                hintText: 'Sorunuzu yazın (örn. Deprem anında ne yapmalıyım?)',
              ),
            ),
            const SizedBox(height: 16),
            CustomPrimaryButton(
              text: 'Asistana Sor (askAssistant)',
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Meta Llama Asistanı: Doğalgaz ve elektriği ana vanadan kapatıp toplanma alanına geçiniz.'),
                    backgroundColor: AppColors.primaryBlue,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
