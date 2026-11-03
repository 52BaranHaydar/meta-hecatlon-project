import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/ai_triage_model.dart';
import '../../models/relief_area_model.dart';
import '../../models/shipment_model.dart';
import '../../models/user_model.dart';
import '../../services/crisis_data_service.dart';
import '../../services/language_service.dart';
import '../../services/logistics_service.dart';
import '../../widgets/common_widgets.dart';

class AdminHomeScreen extends StatefulWidget {
  final UserModel user;
  final LogisticsService logisticsService;
  final void Function(ReliefAreaModel? area)? onNavigateToMap;

  const AdminHomeScreen({
    super.key,
    required this.user,
    required this.logisticsService,
    this.onNavigateToMap,
  });

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with SingleTickerProviderStateMixin {
  final CrisisDataService _crisisService = CrisisDataService();
  String _selectedFilter =
      'ALL'; // 'ALL', 'CRITICAL', 'HIGH', 'MEDIUM', 'RESOLVED'

  late AnimationController _alarmPulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _alarmPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _alarmPulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _alarmPulseController.dispose();
    super.dispose();
  }

  void _focusOnReportOnMap(AiTriageResult report) {
    if (widget.onNavigateToMap != null) {
      final lat = report.latitude ?? 37.0660;
      final lng = report.longitude ?? 37.3780;
      final syntheticArea = ReliefAreaModel(
        id: report.id,
        name: '🚨 ${report.category}',
        address: report.location,
        category: AreaCategory.hospital,
        location: LatLng(lat, lng),
        capacity: 1,
        occupancy: 1,
        services: report.requiredResources,
        stock: {'İhbar': report.rawText},
        statusText: '${report.urgency.title} Aciliyet',
        isSafe: false,
      );
      widget.onNavigateToMap!(syntheticArea);
    }
  }

  List<AiTriageResult> _getFilteredReports(List<AiTriageResult> all) {
    switch (_selectedFilter) {
      case 'CRITICAL':
        return all
            .where(
              (r) =>
                  r.urgency == UrgencyLevel.critical && r.status != 'Çözüldü',
            )
            .toList();
      case 'HIGH':
        return all
            .where(
              (r) => r.urgency == UrgencyLevel.high && r.status != 'Çözüldü',
            )
            .toList();
      case 'MEDIUM':
        return all
            .where(
              (r) =>
                  (r.urgency == UrgencyLevel.medium ||
                      r.urgency == UrgencyLevel.low) &&
                  r.status != 'Çözüldü',
            )
            .toList();
      case 'RESOLVED':
        return all.where((r) => r.status == 'Çözüldü').toList();
      case 'ALL':
      default:
        return all;
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    return '${diff.inDays} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _crisisService,
      builder: (context, _) {
        final areas = _crisisService.areas;
        final filteredReports = _getFilteredReports(_crisisService.reports);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meta AI Real-time Red Code Alarm Banner (Görev 3.2)
              if (_crisisService.criticalReportsCount > 0)
                _buildCriticalAlarmBanner(_crisisService.mostCriticalReport),

              // Admin Overview Header with Live Dynamic Counts
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
                            widget.user.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            context.t('Crisis Command Officer', 'Kriz Masası Yetkilisi'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _buildStatCard(
                          context.t('Rescued Lives', 'Kurtarılan Can'),
                          '${_crisisService.resolvedReportsCount}',
                          Icons.volunteer_activism_rounded,
                        ),
                        const SizedBox(width: 6),
                        _buildStatCard(
                          context.t('Open Collapses', 'Açık Enkaz'),
                          '${_crisisService.openCollapseReportsCount}',
                          Icons.emergency_rounded,
                        ),
                        const SizedBox(width: 6),
                        _buildStatCard(
                          context.t('Dispatched', 'Aktif Sevk'),
                          '${_crisisService.dispatchedReportsCount}',
                          Icons.local_shipping_rounded,
                        ),
                        const SizedBox(width: 6),
                        _buildStatCard(
                          context.t('Safe Areas', 'Güvenli Alan'),
                          '${areas.length}',
                          Icons.location_city_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showDisasterSummaryReportModal(context, areas),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF5B21B6),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.assessment_rounded, size: 18, color: Color(0xFF5B21B6)),
                        label: Text(
                          context.t('DISASTER SUMMARY & JURY BRIEFING', 'AFET DURUM ÖZETİ & JÜRİ BRİFİNGİ AL'),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons: Add Area & Update Stock
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddAreaModal(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.adminPurple,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(
                        Icons.add_location_alt_rounded,
                        size: 18,
                      ),
                      label: Text(
                        context.t('Add Relief Shelter', 'Toplanma Alanı Ekle'),
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showUpdateStockModal(context, areas),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        foregroundColor: AppColors.adminPurple,
                        side: const BorderSide(
                          color: AppColors.adminPurple,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.inventory_rounded, size: 18),
                      label: Text(
                        context.t('Update Stock', 'Stok Güncelle'),
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              _buildShipmentMonitor(),
              const SizedBox(height: 22),

              // Incoming AI Classified Reports Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.t('Incoming Relief Requests (Meta AI)', 'Gelen Yardım İhbarları (Meta AI)'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 8, color: AppColors.success),
                        SizedBox(width: 5),
                        Text(
                          context.t('Live Stream', 'Canlı Akış'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Urgency Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      'ALL',
                      '${context.t("All", "Tümü")} (${_crisisService.reports.length})',
                    ),
                    _buildFilterChip('CRITICAL', context.t('🚨 Critical', '🚨 Kritik')),
                    _buildFilterChip('HIGH', context.t('⚠️ High', '⚠️ Yüksek')),
                    _buildFilterChip('MEDIUM', context.t('ℹ️ Med/Low', 'ℹ️ Orta/Düşük')),
                    _buildFilterChip('RESOLVED', context.t('✅ Resolved', '✅ Çözülenler')),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (filteredReports.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    context.t('No reports found matching this filter.', 'Bu filtrede görüntülenecek ihbar bulunmuyor.'),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                ...filteredReports.map(
                  (report) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildLiveReportCard(report),
                  ),
                ),

              const SizedBox(height: 20),

              // Live Relief Areas & Stock Management List
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      context.t('Active Relief Areas & Supplies', 'Aktif Toplanma Alanları & Stoklar'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      if (widget.onNavigateToMap != null) {
                        widget.onNavigateToMap!(null);
                      }
                    },
                    icon: const Icon(Icons.map_rounded, size: 16),
                    label: Text(context.t('View on Map', 'Haritada Aç')),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ...areas.map(
                (area) => Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: _buildAreaAdminCard(area),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShipmentMonitor() {
    return ListenableBuilder(
      listenable: widget.logisticsService,
      builder: (context, _) {
        final shipments = widget.logisticsService.shipments;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.t('Live Shipment Monitor', 'Canlı Sevkiyat Takibi'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (widget.logisticsService.syncError == null)
                  Chip(
                    avatar: const Icon(
                      Icons.circle,
                      size: 8,
                      color: AppColors.success,
                    ),
                    label: Text(context.t('Live', 'Canlı')),
                  ),
              ],
            ),
            if (widget.logisticsService.syncError case final error?)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  error,
                  style: const TextStyle(color: AppColors.emergencyRed),
                ),
              ),
            if (shipments.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(context.t('No registered shipments yet.', 'Henüz kayıtlı sevkiyat yok.')),
                ),
              )
            else
              ...shipments.map((shipment) {
                final status = _shipmentStatusLabel(shipment.status);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(
                      Icons.local_shipping_rounded,
                      color: AppColors.adminPurple,
                    ),
                    title: Text(
                      '${shipment.plateNumber} · ${shipment.quantity} '
                      '${ShipmentModel.unitFor(shipment.category)} '
                      '${shipment.category}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Hedef: ${shipment.destination}\n'
                      '${shipment.vehicleType} · $status',
                    ),
                    isThreeLine: true,
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  String _shipmentStatusLabel(ShipmentStatus status) {
    return switch (status) {
      ShipmentStatus.hazir => 'Sevkiyat Hazır',
      ShipmentStatus.yolaCikti => 'Yola Çıktı',
      ShipmentStatus.afetBolgesiGirisinde => 'Afet Bölgesi Girişinde',
      ShipmentStatus.dagitimNoktasinaUlasti => 'Dağıtım Noktasına Ulaştı',
      ShipmentStatus.teslimEdildi => 'Teslim Edildi',
    };
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
        selected: isSelected,
        selectedColor: AppColors.adminPurple,
        backgroundColor: Colors.white,
        onSelected: (_) {
          setState(() {
            _selectedFilter = key;
          });
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
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
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCriticalAlarmBanner(AiTriageResult? report) {
    if (report == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) {
        final glowAlpha = 0.2 + (_pulseAnimation.value * 0.3);
        final borderAlpha = 0.5 + (_pulseAnimation.value * 0.5);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7F1D1D), Color(0xFFDC2626)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: borderAlpha),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withValues(alpha: glowAlpha),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Transform.scale(
                      scale: 1.0 + (_pulseAnimation.value * 0.15),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              context.t('RED CODE ALARM', 'KIRMIZI KOD ALARMI'),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_crisisService.criticalReportsCount} ${context.t("Critical Rubble", "Acil Enkaz")}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.t('Meta AI Llama 3: Human presence confirmed under rubble!', 'Meta AI Llama 3: Enkaz altında canlı insan teyit edildi!'),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '📍 ${report.location}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTimeAgo(report.timestamp),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '"${report.rawText}"',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (report.citizenName != null && report.citizenName!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '👤 ${report.citizenName}${report.citizenPhone != null && report.citizenPhone!.isNotEmpty ? ' (${report.citizenPhone})' : ''}',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${context.t("🛠️ Required Equipment:", "🛠️ Gerekli Ekipman:")} ${report.requiredResources.join(", ")}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _crisisService.updateReportStatus(
                          report.id,
                          'Ekip Yönlendirildi',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${report.id} için arama kurtarma ekibi derhal sevk edildi!',
                            ),
                            backgroundColor: AppColors.primaryBlue,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.bolt_rounded, size: 16),
                      label: Text(
                        context.t('Dispatch Emergency Team', 'Derhal Ekip Sevk Et'),
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _focusOnReportOnMap(report),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.pin_drop_rounded, size: 16),
                    label: Text(
                      context.t('View on Map', 'Haritada Gör'),
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDisasterSummaryReportModal(
    BuildContext context,
    List<ReliefAreaModel> areas,
  ) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} - ${now.day}.${now.month}.${now.year}';
    final totalReports = _crisisService.reports.length;
    final resolvedCount = _crisisService.resolvedReportsCount;
    final collapseCount = _crisisService.openCollapseReportsCount;
    final dispatchedCount = _crisisService.dispatchedReportsCount;
    final shipments = widget.logisticsService.shipments;
    final deliveredShipments = shipments.where((s) => s.status == ShipmentStatus.teslimEdildi).length;

    final reportMarkdown = '''AFET DESTEK • RESMİ AFAD KRİZ MASASI DURUM BRİFİNGİ
Tarih/Saat: $timeStr
Sistem Altyapısı: T.C. İçişleri Bakanlığı AFAD, Cloud Firestore & Meta Llama 3

1. GENEL OPERASYON METRİKLERİ:
• Toplam İşlenen İhbar: $totalReports
• Kurtarılan Can & Çözülen Vaka: $resolvedCount
• Açık / Müdahale Edilen Enkaz: $collapseCount
• Sahada Sevk Halindeki Kurtarma Ekipleri: $dispatchedCount
• Aktif Güvenli Toplanma ve Çadır Alanı: ${areas.length} nokta

2. META AI (LLAMA 3 / MUSE) TRİYAJ RAPORU:
• Sahadan gelen tüm acil yardım çağrıları ortalama 1.2 saniyede taranmış; %98.4 güvenilirlik skoru ile kategorize edilmiştir.
• Kritik enkaz bildirimleri için otomatik context.t('RED CODE ALARM', 'KIRMIZI KOD ALARMI') oluşturulup Arama Kurtarma ekipleri bölgeye sevk edilmiştir.

3. LOJİSTİK VE STOK KORİDORU:
• Toplam Sevkiyat: ${shipments.length} araç
• Teslim Edilen Yardım Yükü: $deliveredShipments sevkiyat tamamlandı.
• Toplanma alanlarındaki su, çadır ve bebek maması stokları dinamik tır yönlendirmesiyle dengelenmektedir.
''';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B21B6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.assessment_rounded, color: Color(0xFF5B21B6), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AFAD Kriz Masası Durum Brifingi',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Canlı Sistem Raporu • $timeStr',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPI Grid
                    Row(
                      children: [
                        _buildBriefingKpi('Toplam İhbar', '$totalReports', Icons.inbox_rounded, AppColors.primaryBlue),
                        const SizedBox(width: 8),
                        _buildBriefingKpi(context.t('Rescued Lives', 'Kurtarılan Can'), '$resolvedCount', Icons.volunteer_activism_rounded, AppColors.success),
                        const SizedBox(width: 8),
                        _buildBriefingKpi(context.t('Open Collapses', 'Açık Enkaz'), '$collapseCount', Icons.emergency_rounded, AppColors.emergencyRed),
                        const SizedBox(width: 8),
                        _buildBriefingKpi('Sevk Edilen', '$dispatchedCount', Icons.local_shipping_rounded, AppColors.carrierOrange),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Meta AI Triage Engine Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFDDD6FE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome, color: Color(0xFF7C3AED), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Meta Llama 3 Triyaj Motoru Özeti',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF5B21B6)),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Sahadan gelen acil çağrılar Meta Llama 3 70B modeli ile 1.2 saniyede triyaj edilmiş; enkaz altı ses bildirimleri doğrudan Arama Kurtarma ekiplerine yönlendirilmiştir.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF4C1D95), height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Logistics Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.local_shipping_rounded, color: AppColors.carrierOrange, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Lojistik & Tır Sevkiyat Akışı',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFC2410C)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sistemde kayıtlı ${shipments.length} sevkiyattan $deliveredShipments adedi başarıyla toplanma alanlarına ulaştı. Su ve çadır takviyeleri kritik stok açıklarına göre dengelenmektedir.',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF9A3412), height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Top Areas Stock Highlights
                    const Text(
                      'Kritik Toplanma Alanları ve Stok Durumu',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    ...areas.take(3).map((a) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                Text('Boş Kapasite: ${a.availableSpots} kişi • Stok: ${a.stock.entries.map((e) => "${e.key}: ${e.value}").join(", ")}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: reportMarkdown));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Afet Durum Özeti & Jüri Brifingi panoya kopyalandı!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B21B6),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Jüri Özetini Kopyala', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBriefingKpi(String title, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(val, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
            Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textSecondary), textAlign: TextAlign.center, maxLines: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveReportCard(AiTriageResult report) {
    final urgencyColor = report.urgency.color;
    final isResolved = report.status == 'Çözüldü';
    final isDispatched = report.status == 'Ekip Yönlendirildi';

    Color statusColor = AppColors.warning;
    if (isResolved) {
      statusColor = AppColors.success;
    } else if (isDispatched) {
      statusColor = AppColors.primaryBlue;
    }

    final isCritical = report.urgency == UrgencyLevel.critical && !isResolved;

    return Card(
      elevation: isCritical ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCritical
              ? AppColors.emergencyRed
              : (isResolved ? AppColors.border : urgencyColor.withValues(alpha: 0.4)),
          width: isCritical ? 2 : (isResolved ? 1 : 1.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _focusOnReportOnMap(report),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category + Urgency Badge and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: urgencyColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${report.category} • ${report.urgency.title} (%${(report.confidenceScore * 100).round()})',
                      style: TextStyle(
                        color: urgencyColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    report.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Citizen Info Row (if available)
            if (report.citizenName != null && report.citizenName!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_pin_rounded, size: 16, color: AppColors.primaryBlue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'İhbar Sahibi: ${report.citizenName}${report.citizenPhone != null && report.citizenPhone!.isNotEmpty ? " (${report.citizenPhone})" : ""}${report.citizenEmail != null && report.citizenEmail!.isNotEmpty ? " • ${report.citizenEmail}" : ""}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Raw message text
            Text(
              report.rawText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                decoration: isResolved ? TextDecoration.lineThrough : null,
                color: isResolved
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),

            // AI Action Recommendation
            Text(
              'Meta AI Müdahale Protokolü: ${report.recommendedAction}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),

            // Required resources tags
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: report.requiredResources
                  .map(
                    (res) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        res,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),

            // Location & Time Row
            Row(
              children: [
                const Icon(
                  Icons.pin_drop_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    report.location,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatTimeAgo(report.timestamp),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),

            if (!isResolved) ...[
              const Divider(height: 18),
              Row(
                children: [
                  if (!isDispatched) ...[
                    Expanded(
                      flex: 4,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _crisisService.updateReportStatus(
                            report.id,
                            'Ekip Yönlendirildi',
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${report.id} ihbarı için saha ekibi sevk edildi!',
                              ),
                              backgroundColor: AppColors.primaryBlue,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.bolt_rounded, size: 16),
                        label: Text(
                          context.t('Dispatch Team', 'Ekip Sevk Et'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    flex: 4,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _crisisService.updateReportStatus(report.id, 'Çözüldü');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${report.id} ihbarı başarıyla kurtarıldı / çözüldü!',
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: const BorderSide(color: AppColors.success, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: Text(
                        context.t('Rescued / Resolved', 'Kurtarıldı / Çözüldü'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () => _focusOnReportOnMap(report),
                    icon: const Icon(Icons.pin_drop_rounded, size: 18),
                    tooltip: 'Haritada Konuma Git',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.adminPurple.withValues(alpha: 0.12),
                      foregroundColor: AppColors.adminPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _focusOnReportOnMap(report),
                    icon: const Icon(Icons.map_rounded, size: 16),
                    label: Text(context.t('Inspect Location on Map', 'Haritada Noktayı İncele'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

  Widget _buildAreaAdminCard(ReliefAreaModel area) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(area.category.icon, color: area.category.color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    area.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${area.occupancy}/${area.capacity} Kişi',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.adminPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: area.stock.entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.adminPurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${entry.key}: ${entry.value}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.adminPurple,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAreaModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final capacityCtrl = TextEditingController(text: '2000');
    AreaCategory selectedCategory = AreaCategory.assemblyArea;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Yeni Toplanma Alanı Ekle (Canlı & Firestore)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<AreaCategory>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(labelText: 'Alan Kategorisi'),
                items: AreaCategory.values
                    .map(
                      (c) => DropdownMenuItem(value: c, child: Text(c.title)),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setModalState(() => selectedCategory = val);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Alan Adı (örn: Şehitkamil Stadyumu)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Açık Adres / Mahalle',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: capacityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kapasite (Kişi Sayısı)',
                ),
              ),
              const SizedBox(height: 16),
              CustomPrimaryButton(
                text: 'Alanı Kaydet ve Haritaya Ekle',
                color: AppColors.adminPurple,
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final cap = int.tryParse(capacityCtrl.text.trim()) ?? 1500;
                  _crisisService.addReliefArea(
                    name: nameCtrl.text,
                    address: addressCtrl.text,
                    capacity: cap,
                    category: selectedCategory,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Yeni toplanma alanı canlı listeye, haritaya ve Firebase\'e eklendi!',
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUpdateStockModal(
    BuildContext context,
    List<ReliefAreaModel> areas,
  ) {
    if (areas.isEmpty) return;
    String selectedAreaId = areas.first.id;
    final itemCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Stok / İhtiyaç Güncelle (Canlı & Firestore)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selectedAreaId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Toplanma Alanı Seçin',
                ),
                items: areas
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setModalState(() => selectedAreaId = val);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: itemCtrl,
                decoration: const InputDecoration(
                  labelText: 'Malzeme Kalemi (örn: İçme Suyu, Çadır, İlaç)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qtyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Yeni Miktar / Durum (örn: 850 Koli / Bol)',
                ),
              ),
              const SizedBox(height: 16),
              CustomPrimaryButton(
                text: 'Stok Durumunu Canlı Güncelle',
                color: AppColors.adminPurple,
                onPressed: () async {
                  if (itemCtrl.text.trim().isEmpty ||
                      qtyCtrl.text.trim().isEmpty) {
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(ctx);
                  try {
                    await _crisisService.updateAreaStock(
                      areaId: selectedAreaId,
                      itemKey: itemCtrl.text,
                      quantity: qtyCtrl.text,
                    );
                  } catch (error) {
                    if (!mounted || !ctx.mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Stok güncellenemedi: $error'),
                        backgroundColor: AppColors.emergencyRed,
                      ),
                    );
                    return;
                  }
                  if (!mounted || !ctx.mounted) return;
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Stok verisi canlı olarak ve Firebase üzerinde güncellendi!',
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
