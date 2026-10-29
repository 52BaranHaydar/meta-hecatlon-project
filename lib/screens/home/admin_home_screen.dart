import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/ai_triage_model.dart';
import '../../models/relief_area_model.dart';
import '../../models/user_model.dart';
import '../../services/crisis_data_service.dart';
import '../../widgets/common_widgets.dart';

class AdminHomeScreen extends StatefulWidget {
  final UserModel user;
  final void Function(ReliefAreaModel? area)? onNavigateToMap;

  const AdminHomeScreen({
    super.key,
    required this.user,
    this.onNavigateToMap,
  });

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final CrisisDataService _crisisService = CrisisDataService();
  String _selectedFilter = 'ALL'; // 'ALL', 'CRITICAL', 'HIGH', 'MEDIUM', 'RESOLVED'

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
                          child: const Text(
                            'Kriz Masası Yetkilisi',
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
                          'Aktif İhbar',
                          '${_crisisService.activeReportsCount}',
                          Icons.warning_amber_rounded,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          'Kritik Vaka',
                          '${_crisisService.criticalReportsCount}',
                          Icons.emergency_rounded,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          'Güvenli Alan',
                          '${areas.length}',
                          Icons.location_city_rounded,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          'Sevk Edilen',
                          '${_crisisService.dispatchedReportsCount}',
                          Icons.local_shipping_rounded,
                        ),
                      ],
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
                      icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                      label: const Text(
                        'Toplanma Alanı Ekle',
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
                      label: const Text(
                        'Stok Güncelle',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Incoming AI Classified Reports Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gelen Yardım İhbarları (Meta AI)',
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
                      children: const [
                        Icon(Icons.circle, size: 8, color: AppColors.success),
                        SizedBox(width: 5),
                        Text(
                          'Canlı Akış',
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
                    _buildFilterChip('ALL', 'Tümü (${_crisisService.reports.length})'),
                    _buildFilterChip('CRITICAL', '🚨 Kritik'),
                    _buildFilterChip('HIGH', '⚠️ Yüksek'),
                    _buildFilterChip('MEDIUM', 'ℹ️ Orta/Düşük'),
                    _buildFilterChip('RESOLVED', '✅ Çözülenler'),
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
                  child: const Text(
                    'Bu filtrede görüntülenecek ihbar bulunmuyor.',
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Aktif Toplanma Alanları & Stoklar',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      if (widget.onNavigateToMap != null) {
                        widget.onNavigateToMap!(null);
                      }
                    },
                    icon: const Icon(Icons.map_rounded, size: 16),
                    label: const Text('Haritada Aç'),
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

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isResolved
              ? AppColors.border
              : urgencyColor.withValues(alpha: 0.4),
          width: isResolved ? 1 : 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 8),
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
            Text(
              'AI Önerisi: ${report.recommendedAction}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
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
                  if (!isDispatched)
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
                                '${report.id} ihbarı için saha ekibi sevk edildi!',
                              ),
                              backgroundColor: AppColors.primaryBlue,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.bolt_rounded, size: 16),
                        label: const Text(
                          'Ekip Sevk Et',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (!isDispatched) const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _crisisService.updateReportStatus(
                          report.id,
                          'Çözüldü',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${report.id} ihbarı çözüldü olarak işaretlendi.',
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: const BorderSide(color: AppColors.success),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text(
                        'Çözüldü İşaretle',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
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
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.title),
                      ),
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
                        child: Text(
                          a.name,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                onPressed: () {
                  if (itemCtrl.text.trim().isEmpty ||
                      qtyCtrl.text.trim().isEmpty) {
                    return;
                  }
                  _crisisService.updateAreaStock(
                    areaId: selectedAreaId,
                    itemKey: itemCtrl.text,
                    quantity: qtyCtrl.text,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
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
