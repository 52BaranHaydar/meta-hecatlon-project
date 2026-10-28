import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../constants/app_colors.dart';
import '../../models/relief_area_model.dart';
import '../../widgets/emergency_112_button.dart';

class ReliefMapScreen extends StatefulWidget {
  final ReliefAreaModel? initialSelectedArea;

  const ReliefMapScreen({super.key, this.initialSelectedArea});

  @override
  State<ReliefMapScreen> createState() => _ReliefMapScreenState();
}

class _ReliefMapScreenState extends State<ReliefMapScreen> {
  final MapController _mapController = MapController();
  final LatLng _userLocation = const LatLng(37.0662, 37.3833);

  ReliefAreaModel? _selectedArea;
  AreaCategory? _filterCategory;
  final TextEditingController _searchController = TextEditingController();
  bool _isNavigationActive = false;

  @override
  void initState() {
    super.initState();
    _selectedArea = widget.initialSelectedArea ?? ReliefAreaModel.demoAreas.first;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ReliefAreaModel> get _filteredAreas {
    return ReliefAreaModel.demoAreas.where((area) {
      if (_filterCategory != null && area.category != _filterCategory) {
        return false;
      }
      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        return area.name.toLowerCase().contains(query) ||
            area.address.toLowerCase().contains(query);
      }
      return true;
    }).toList();
  }

  double _calculateDistanceKm(LatLng p1, LatLng p2) {
    const double earthRadiusKm = 6371.0;
    final dLat = (p2.latitude - p1.latitude) * (pi / 180.0);
    final dLon = (p2.longitude - p1.longitude) * (pi / 180.0);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(p1.latitude * (pi / 180.0)) *
            cos(p2.latitude * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  void _selectArea(ReliefAreaModel area) {
    setState(() {
      _selectedArea = area;
    });
    _mapController.move(area.location, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    final activeDestination = _selectedArea;
    final distanceKm = activeDestination != null
        ? _calculateDistanceKm(_userLocation, activeDestination.location)
        : 0.0;
    final walkMin = (distanceKm * 12).round().clamp(1, 120);
    final carMin = (distanceKm * 2.5).round().clamp(1, 60);

    return Scaffold(
      body: Stack(
        children: [
          // 1. OpenStreetMap Interactive Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation,
              initialZoom: 14.5,
              minZoom: 10.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.metaai.afetdestek',
              ),

              // Route Polyline (Draws road towards selected destination)
              if (activeDestination != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        _userLocation,
                        LatLng(
                          (_userLocation.latitude + activeDestination.location.latitude) / 2 + 0.001,
                          (_userLocation.longitude + activeDestination.location.longitude) / 2 - 0.001,
                        ),
                        activeDestination.location,
                      ],
                      strokeWidth: 4.5,
                      color: AppColors.primaryBlue,
                    ),
                  ],
                ),

              // Markers Layer
              MarkerLayer(
                markers: [
                  // User Location Pin
                  Marker(
                    point: _userLocation,
                    width: 50,
                    height: 50,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryBlue.withValues(alpha: 0.4),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.my_location_rounded, color: AppColors.primaryBlue, size: 22),
                        ),
                      ],
                    ),
                  ),

                  // Relief Areas Pins
                  ..._filteredAreas.map((area) {
                    final isSelected = activeDestination?.id == area.id;
                    return Marker(
                      point: area.location,
                      width: isSelected ? 56 : 44,
                      height: isSelected ? 56 : 44,
                      child: GestureDetector(
                        onTap: () => _selectArea(area),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: area.category.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: isSelected ? 10 : 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            area.category.icon,
                            color: Colors.white,
                            size: isSelected ? 26 : 20,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // 2. Top Header & Floating Search Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isNavigationActive && activeDestination != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Canlı Rota: ${activeDestination.name}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isNavigationActive = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Bitir',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      // Search Card
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Nereye gitmek istiyorsunuz?',
                              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryBlue, size: 20),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Emergency 112 Button (Mandatory)
                      const Emergency112Button(compact: true),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Category Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip(null, 'Tümü (${ReliefAreaModel.demoAreas.length})', Icons.dashboard_rounded),
                        const SizedBox(width: 6),
                        ...AreaCategory.values.map((cat) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: _filterChip(cat, cat.title, cat.icon),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Current Location Quick Center Button
          Positioned(
            right: 16,
            bottom: activeDestination != null ? 240 : 32,
            child: FloatingActionButton.small(
              heroTag: 'my_loc_btn',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryBlue,
              elevation: 4,
              onPressed: () {
                _mapController.move(_userLocation, 15.0);
              },
              child: const Icon(Icons.gps_fixed_rounded),
            ),
          ),

          // 4. Bottom Destination Card ("Nereye Gidilecek?")
          if (activeDestination != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildDestinationCard(
                area: activeDestination,
                distanceKm: distanceKm,
                walkMin: walkMin,
                carMin: carMin,
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(AreaCategory? category, String title, IconData icon) {
    final isSelected = _filterCategory == category;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterCategory = category;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : (category?.color ?? AppColors.primary),
            ),
            const SizedBox(width: 5),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationCard({
    required ReliefAreaModel area,
    required double distanceKm,
    required int walkMin,
    required int carMin,
  }) {
    final distFormatted = distanceKm < 1.0
        ? '${(distanceKm * 1000).round()} metre'
        : '${distanceKm.toStringAsFixed(1)} km';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category & Distance Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: area.category.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(area.category.icon, size: 14, color: area.category.color),
                    const SizedBox(width: 5),
                    Text(
                      area.category.title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: area.category.color,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.directions_walk_rounded, size: 16, color: AppColors.primaryBlue),
                  Text(' $walkMin dk', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primaryBlue)),
                  const SizedBox(width: 8),
                  const Icon(Icons.directions_car_rounded, size: 16, color: AppColors.textSecondary),
                  Text(' $carMin dk', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Area Name & Address
          Text(
            area.name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${area.address} • $distFormatted mesafede',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          // Capacity & Stock Bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Doluluk Durumu', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        Text('${area.occupancy} / ${area.capacity} Kişi', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: area.occupancyRate,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          area.occupancyRate > 0.8 ? AppColors.emergencyRed : AppColors.success,
                        ),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons: Route & Details
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showTurnByTurnModal(area, distFormatted, walkMin);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text(
                    'BURAYA GİT (YOL TARİFİ)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () => _showAreaDetailSheet(area),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: const Text('Detaylar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTurnByTurnModal(ReliefAreaModel area, String distance, int walkMin) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.near_me_rounded, color: AppColors.primaryBlue, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hedef: ${area.name}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(
                        '$distance • Tahmini $walkMin dakika yürüyüş',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildNavStep('1', 'Bulunduğunuz konumdan kuzeye doğru 150m düz ilerleyin.', Icons.arrow_upward_rounded),
            _buildNavStep('2', 'Ana caddeden sağa dönün ve 350m yürüyün.', Icons.turn_right_rounded),
            _buildNavStep('3', '${area.name} giriş kapısına ulaştınız.', Icons.pin_drop_rounded, isLast: true),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _isNavigationActive = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${area.name} için canlı rota takibi başlatıldı.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Canlı Navigasyonu Başlat', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavStep(String stepNumber, String text, IconData icon, {bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: isLast ? AppColors.success : AppColors.primaryBlue,
            child: Text(stepNumber, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showAreaDetailSheet(ReliefAreaModel area) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        minChildSize: 0.35,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 16),
              Text(area.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(area.address, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              const Text('Mevcut Hizmetler & Olanaklar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: area.services.map((srv) {
                  return Chip(
                    label: Text(srv, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    backgroundColor: AppColors.background,
                    side: const BorderSide(color: AppColors.border),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Güncel İhtiyaç & Stok Durumu (Firestore stock)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              ...area.stock.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: const TextStyle(fontSize: 13)),
                      Text(entry.value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primaryBlue)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
