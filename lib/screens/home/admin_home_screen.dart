import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/relief_area_model.dart';
import '../../models/user_model.dart';
import '../../widgets/common_widgets.dart';

class AdminHomeScreen extends StatelessWidget {
  final UserModel user;
  final void Function(ReliefAreaModel? area)? onNavigateToMap;

  const AdminHomeScreen({
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
          // Admin Overview Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.adminPurple.withValues(alpha: 0.3),
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
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
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
                        'Kriz Masası Yetkilisi',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatCard('Aktif İhbar', '28', Icons.warning_amber_rounded),
                    const SizedBox(width: 8),
                    _buildStatCard('Toplanma Alanı', '14', Icons.location_city_rounded),
                    const SizedBox(width: 8),
                    _buildStatCard('Sevkiyat', '42', Icons.local_shipping_rounded),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Map Shortcut Button
          InkWell(
            onTap: () {
              if (onNavigateToMap != null) {
                onNavigateToMap!(null);
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.adminPurple.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.map_rounded, color: AppColors.adminPurple),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tüm Toplanma Alanlarını Haritada İncele',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.adminPurple),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons: Add Area & Update Stock
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddAreaModal(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.adminPurple,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                  label: const Text('Toplanma Alanı Ekle'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showUpdateStockModal(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: AppColors.adminPurple,
                    side: const BorderSide(color: AppColors.adminPurple),
                  ),
                  icon: const Icon(Icons.inventory_rounded, size: 18),
                  label: const Text('Stok Güncelle'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Incoming AI Classified Reports (B6: classifyReport output list)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Gelen Yardım İhbarları (Meta AI)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              Text(
                'Canlı Akış',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildReportCard(
            category: 'SAĞLIK & İLAÇ',
            urgency: 'YÜKSEK',
            urgencyColor: AppColors.emergencyRed,
            time: '3 dk önce',
            text: 'İnsülin ilacımız bitti, 72 yaşında şeker hastası için acil temin gerekiyor.',
            location: 'Şehitkamil, Osmangazi Mah. No: 14',
          ),
          const SizedBox(height: 10),
          _buildReportCard(
            category: 'SU & GIDA',
            urgency: 'ORTA',
            urgencyColor: AppColors.warning,
            time: '11 dk önce',
            text: 'Çadır kent 2. bölgede içme suyu dağıtımı tükendi, 50 koli su talebi.',
            location: 'Atatürk Parkı Çadır Alanı',
          ),
          const SizedBox(height: 10),
          _buildReportCard(
            category: 'BARINMA',
            urgency: 'DÜŞÜK',
            urgencyColor: AppColors.info,
            time: '24 dk önce',
            text: '3 aile için kışlık battaniye ve mat talebi mevcut.',
            location: 'Fuar Toplanma Bölgesi',
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required String category,
    required String urgency,
    required Color urgencyColor,
    required String time,
    required String text,
    required String location,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: urgencyColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$category • $urgency',
                    style: TextStyle(color: urgencyColor, fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
                Text(time, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.pin_drop_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAreaModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Yeni Toplanma Alanı Ekle (areas)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: 'Alan Adı (örn: Şehitkamil Stadyumu)')),
            const SizedBox(height: 10),
            const TextField(decoration: InputDecoration(labelText: 'Kapasite (Kişi Sayısı)')),
            const SizedBox(height: 16),
            CustomPrimaryButton(
              text: 'Alanı Firestore\'a Kaydet',
              color: AppColors.adminPurple,
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Toplanma alanı başarıyla eklendi!'), backgroundColor: AppColors.success),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateStockModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Stok / İhtiyaç Güncelle (needs)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: 'Malzeme Kalemi (örn: Çadır, Su, Battaniye)')),
            const SizedBox(height: 10),
            const TextField(decoration: InputDecoration(labelText: 'Eksik Miktar (Adet / Koli)')),
            const SizedBox(height: 16),
            CustomPrimaryButton(
              text: 'Stok Durumunu Güncelle',
              color: AppColors.adminPurple,
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Stok verisi güncellendi!'), backgroundColor: AppColors.success),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
