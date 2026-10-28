import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/relief_area_model.dart';
import '../../models/user_model.dart';
import '../../widgets/common_widgets.dart';

class CarrierHomeScreen extends StatelessWidget {
  final UserModel user;
  final void Function(ReliefAreaModel? area)? onNavigateToMap;

  const CarrierHomeScreen({
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
          // Carrier Header Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.carrierOrange.withValues(alpha: 0.3),
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
                        'Taşıyıcı: ${user.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Lojistik Gönüllüsü',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aracınızdaki yardım yükünü girin. Meta AI optimizasyon algoritması sizi en acil ihtiyaç noktasına yönlendirsin.',
                  style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAddShipmentModal(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.carrierOrange,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_box_rounded, color: AppColors.carrierOrange),
                  label: const Text(
                    '+ YENİ YÜK & SEVKİYAT EKLE',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Recommended AI Delivery Route Card (B3: recommendDelivery)
          const Text(
            'Meta AI Önerilen Teslimat Noktası',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: AppColors.emergencyRed, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'YÜKSEK ACİLİYET',
                          style: TextStyle(
                            color: AppColors.emergencyRed,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      '18 dk (9.4 km)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Kamil Ocak 1 Nolu Çadır Kent',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Meta AI Gerekçesi: Bölgedeki içme suyu stoku %10 seviyesine inmiştir. 450 ailenin ivedilikle suya ihtiyacı vardır.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (onNavigateToMap != null) {
                            onNavigateToMap!(ReliefAreaModel.demoAreas[1]);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.navigation_rounded, size: 16),
                        label: const Text('Haritada Rotayı Aç'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Yetkili iletişim numarası: 0555 444 3322')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Icon(Icons.phone, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Active Shipments List
          const Text(
            'Mevcut Taşıma Kayıtlarınız (Shipments)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),

          _buildShipmentItem(
            id: '#TR-8492',
            title: '500 Koli İçme Suyu (0.5L)',
            origin: 'Adana Lojistik Deposu',
            destination: 'Şehitkamil Çadır Kent',
            status: 'Yolda / Dağıtımda',
            statusColor: AppColors.warning,
          ),
          const SizedBox(height: 10),
          _buildShipmentItem(
            id: '#TR-8410',
            title: '120 Adet Kışlık Battaniye',
            origin: 'Mersin Koordinasyon',
            destination: 'Atatürk Parkı Toplanma Alanı',
            status: 'Teslim Edildi',
            statusColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildShipmentItem({
    required String id,
    required String title,
    required String origin,
    required String destination,
    required String status,
    required Color statusColor,
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
                Text(id, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 12)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.trip_origin_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(origin, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 6),
                const Icon(Icons.location_on_rounded, size: 14, color: AppColors.emergencyRed),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    destination,
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
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

  void _showAddShipmentModal(BuildContext context) {
    final itemCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final originCtrl = TextEditingController();

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
                Icon(Icons.local_shipping_rounded, color: AppColors.carrierOrange),
                SizedBox(width: 8),
                Text('Yeni Yük Bildir (Firestore shipments)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: itemCtrl,
              decoration: const InputDecoration(labelText: 'Malzeme Kalemi (örn: Su, Battaniye, Çocuk Bezi)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'Miktar ve Birim (örn: 200 Koli)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: originCtrl,
              decoration: const InputDecoration(labelText: 'Çıkış Noktası / Mevcut Konum'),
            ),
            const SizedBox(height: 18),
            CustomPrimaryButton(
              text: 'Yükü Kaydet ve Rota Önerisi Al',
              color: AppColors.carrierOrange,
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Yük Firestore\'a eklendi ve Meta AI rota önerisi hesaplandı!'),
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
}
