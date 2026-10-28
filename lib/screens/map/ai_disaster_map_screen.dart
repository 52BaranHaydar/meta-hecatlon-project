import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../constants/app_colors.dart';
import '../../models/relief_area_model.dart';
import '../../services/location_service.dart';
import '../../widgets/emergency_112_button.dart';

class AiDisasterMapScreen extends StatefulWidget {
  final ReliefAreaModel? initialSelectedArea;
  final AreaCategory? initialFilterCategory;
  final LatLng? safeReportLocation;
  final bool isActive;

  const AiDisasterMapScreen({
    super.key,
    this.initialSelectedArea,
    this.initialFilterCategory,
    this.safeReportLocation,
    this.isActive = true,
  });

  @override
  State<AiDisasterMapScreen> createState() => _AiDisasterMapScreenState();
}

class _AiDisasterMapScreenState extends State<AiDisasterMapScreen>
    with SingleTickerProviderStateMixin {
  LatLng? _userLocation;
  ReliefAreaModel? _selectedArea;
  AreaCategory? _filterCategory;
  final TextEditingController _searchController = TextEditingController();
  bool _isNavigating = false;
  bool _isLoadingLocation = false;
  String? _locationError;
  late AnimationController _pulseController;

  // Canvas pan & zoom state
  Offset _mapOffset = const Offset(0, 0);
  final double _mapScale = 1.0;

  @override
  void initState() {
    super.initState();
    _filterCategory = widget.initialFilterCategory;
    _selectedArea =
        widget.initialSelectedArea ?? _firstAreaForFilter(_filterCategory);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    if (widget.isActive) _loadUserLocation();
  }

  @override
  void didUpdateWidget(covariant AiDisasterMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilterCategory != widget.initialFilterCategory) {
      _filterCategory = widget.initialFilterCategory;
      if (_selectedArea == null ||
          (_filterCategory != null &&
              _selectedArea!.category != _filterCategory)) {
        _selectedArea = _firstAreaForFilter(_filterCategory);
      }
    }
    if (oldWidget.initialSelectedArea != widget.initialSelectedArea &&
        widget.initialSelectedArea != null) {
      _selectedArea = widget.initialSelectedArea;
    }
    if (!oldWidget.isActive && widget.isActive) _loadUserLocation();
  }

  ReliefAreaModel _firstAreaForFilter(AreaCategory? category) {
    return ReliefAreaModel.demoAreas.firstWhere(
      (area) => category == null || area.category == category,
      orElse: () => ReliefAreaModel.demoAreas.first,
    );
  }

  Future<void> _loadUserLocation() async {
    if (_isLoadingLocation) return;
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      final location = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _userLocation = location;
        _isLoadingLocation = false;
        _mapOffset = Offset.zero;
      });
    } on LocationServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _locationError = error.message;
        _isLoadingLocation = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _locationError = 'GPS konumu alınamadı: $error';
        _isLoadingLocation = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  List<ReliefAreaModel> get _filteredAreas {
    return ReliefAreaModel.demoAreas.where((area) {
      if (_filterCategory != null && area.category != _filterCategory) {
        return false;
      }
      final q = _searchController.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        return area.name.toLowerCase().contains(q) ||
            area.address.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  double _calculateDistanceKm(LatLng p1, LatLng p2) {
    const double earthRadiusKm = 6371.0;
    final dLat = (p2.latitude - p1.latitude) * (pi / 180.0);
    final dLon = (p2.longitude - p1.longitude) * (pi / 180.0);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(p1.latitude * (pi / 180.0)) *
            cos(p2.latitude * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  @override
  Widget build(BuildContext context) {
    final activeDestination = _selectedArea;
    final userLocation = _userLocation;
    final mapOrigin = userLocation ?? ReliefAreaModel.demoAreas.first.location;
    final distanceKm = activeDestination != null && userLocation != null
        ? _calculateDistanceKm(userLocation, activeDestination.location)
        : null;
    final walkMin = distanceKm == null
        ? null
        : (distanceKm * 12).round().clamp(1, 120);
    final carMin = distanceKm == null
        ? null
        : (distanceKm * 2.5).round().clamp(1, 60);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Tactical Dark Map
      body: Stack(
        children: [
          // 1. Interactive Tactical Vector Map Canvas (100% Offline & Reliable)
          GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _mapOffset += details.delta;
              });
            },
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _TacticalMapPainter(
                    userLocation: userLocation,
                    mapOrigin: mapOrigin,
                    selectedArea: activeDestination,
                    areas: _filteredAreas,
                    offset: _mapOffset,
                    scale: _mapScale,
                    pulseValue: _pulseController.value,
                    safeReportLocation: widget.safeReportLocation,
                    onSelectArea: (area) {
                      setState(() {
                        _selectedArea = area;
                      });
                    },
                  ),
                );
              },
            ),
          ),

          // 2. Interactive Markers Overlay (Tap to select)
          LayoutBuilder(
            builder: (context, constraints) {
              final center =
                  Offset(constraints.maxWidth / 2, constraints.maxHeight / 2) +
                  _mapOffset;
              return Stack(
                children: [
                  // User Location Pin
                  if (_userLocation != null)
                    Positioned(
                      left: center.dx - 18,
                      top: center.dy - 18,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withValues(
                                alpha: 0.6,
                              ),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.my_location_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),

                  if (widget.safeReportLocation != null)
                    Positioned(
                      left:
                          center.dx +
                          (widget.safeReportLocation!.longitude -
                                  mapOrigin.longitude) *
                              12000 -
                          12,
                      top:
                          center.dy -
                          (widget.safeReportLocation!.latitude -
                                  mapOrigin.latitude) *
                              12000 -
                          12,
                      child: const Tooltip(
                        message: 'Güvendeyim bildirimi',
                        child: Icon(
                          Icons.verified_user_rounded,
                          color: AppColors.success,
                          size: 24,
                        ),
                      ),
                    ),

                  // Area Pins
                  ..._filteredAreas.map((area) {
                    // Coordinate projection relative to center
                    final dx =
                        center.dx +
                        (area.location.longitude - mapOrigin.longitude) * 12000;
                    final dy =
                        center.dy -
                        (area.location.latitude - mapOrigin.latitude) * 12000;
                    final isSelected = activeDestination?.id == area.id;

                    return Positioned(
                      left: dx - (isSelected ? 26 : 20),
                      top: dy - (isSelected ? 26 : 20),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedArea = area;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isSelected ? 52 : 40,
                          height: isSelected ? 52 : 40,
                          decoration: BoxDecoration(
                            color: area.category.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: isSelected ? 3 : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: area.category.color.withValues(
                                  alpha: 0.6,
                                ),
                                blurRadius: isSelected ? 16 : 8,
                                spreadRadius: isSelected ? 2 : 0,
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
              );
            },
          ),

          // 3. Top Floating Search & Filters (Spacious)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18.0,
                vertical: 10.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isNavigating && activeDestination != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.navigation_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Meta AI Güvenli Rota: ${activeDestination.name}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _isNavigating = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Kapat',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Search Bar + 112 Button
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText:
                                  'Nereye gitmek istiyorsunuz? (Toplanma alanı ara)',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: AppColors.primaryBlue,
                              ),
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
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Emergency112Button(compact: true),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip(
                          null,
                          'Tümü (${ReliefAreaModel.demoAreas.length})',
                          Icons.dashboard_rounded,
                        ),
                        const SizedBox(width: 8),
                        ...AreaCategory.values.map((cat) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _filterChip(cat, cat.title, cat.icon),
                          );
                        }),
                      ],
                    ),
                  ),
                  if (_isLoadingLocation ||
                      _locationError != null ||
                      _userLocation != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _userLocation != null
                                ? Icons.my_location_rounded
                                : _isLoadingLocation
                                ? Icons.gps_not_fixed_rounded
                                : Icons.location_off_rounded,
                            color: _userLocation != null
                                ? AppColors.success
                                : AppColors.warning,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _userLocation != null
                                  ? 'GPS: ${_userLocation!.latitude.toStringAsFixed(5)}, ${_userLocation!.longitude.toStringAsFixed(5)}'
                                  : _isLoadingLocation
                                  ? 'Gerçek GPS konumu alınıyor...'
                                  : _locationError!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!_isLoadingLocation)
                            IconButton(
                              tooltip: 'GPS konumunu yenile',
                              visualDensity: VisualDensity.compact,
                              onPressed: _loadUserLocation,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 4. Center Current Location Button
          Positioned(
            right: 18,
            bottom: activeDestination != null ? 280 : 36,
            child: FloatingActionButton(
              heroTag: 'recenter_gps_btn',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryBlue,
              elevation: 4,
              onPressed: _isLoadingLocation ? null : _loadUserLocation,
              child: _isLoadingLocation
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.gps_fixed_rounded),
            ),
          ),

          // 5. Destination Card ("Nereye Gidilecek?")
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
          if (category != null && _selectedArea?.category != category) {
            _selectedArea = _firstAreaForFilter(category);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
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
              color: isSelected
                  ? Colors.white
                  : (category?.color ?? AppColors.primaryBlue),
            ),
            const SizedBox(width: 6),
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
    required double? distanceKm,
    required int? walkMin,
    required int? carMin,
  }) {
    final distFormatted = distanceKm == null
        ? 'GPS konumu bekleniyor'
        : distanceKm < 1.0
        ? '${(distanceKm * 1000).round()} metre'
        : '${distanceKm.toStringAsFixed(1)} km';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: area.category.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      area.category.icon,
                      size: 14,
                      color: area.category.color,
                    ),
                    const SizedBox(width: 6),
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
                  const Icon(
                    Icons.directions_walk_rounded,
                    size: 16,
                    color: AppColors.primaryBlue,
                  ),
                  Text(
                    walkMin == null ? ' --' : ' $walkMin dk',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.directions_car_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  Text(
                    carMin == null ? ' --' : ' $carMin dk',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            area.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            distanceKm == null
                ? area.address
                : '${area.address} • $distFormatted mesafede',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Capacity Bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Doluluk Durumu',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${area.occupancy} / ${area.capacity} Kişi',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: area.occupancyRate,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          area.occupancyRate > 0.8
                              ? AppColors.emergencyRed
                              : AppColors.success,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: distanceKm == null
                      ? null
                      : () {
                          if (walkMin == null) return;
                          setState(() {
                            _isNavigating = true;
                          });
                          _showTurnByTurnModal(area, distFormatted, walkMin);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: const Text(
                    'Detaylar',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTurnByTurnModal(
    ReliefAreaModel area,
    String distance,
    int walkMin,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.near_me_rounded,
                    color: AppColors.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hedef: ${area.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$distance • Tahmini $walkMin dakika yürüyüş',
                        style: const TextStyle(
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
            const Divider(),
            const SizedBox(height: 10),
            _buildNavStep(
              '1',
              'Bulunduğunuz konumdan kuzeye doğru 150m düz ilerleyin.',
              Icons.arrow_upward_rounded,
            ),
            _buildNavStep(
              '2',
              'Ana caddeden sağa dönün ve 350m yürüyün.',
              Icons.turn_right_rounded,
            ),
            _buildNavStep(
              '3',
              '${area.name} giriş kapısına ulaştınız.',
              Icons.pin_drop_rounded,
              isLast: true,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _isNavigating = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${area.name} için canlı rota takibi başlatıldı.',
                    ),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(
                'Canlı Navigasyonu Başlat',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavStep(
    String stepNumber,
    String text,
    IconData icon, {
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: isLast ? AppColors.success : AppColors.primaryBlue,
            child: Text(
              stepNumber,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showAreaDetailSheet(ReliefAreaModel area) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.35,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                area.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                area.address,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Mevcut Hizmetler & Olanaklar',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: area.services.map((srv) {
                  return Chip(
                    label: Text(
                      srv,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: AppColors.background,
                    side: const BorderSide(color: AppColors.border),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Güncel İhtiyaç & Stok Durumu (Firestore stock)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...area.stock.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: const TextStyle(fontSize: 13)),
                      Text(
                        entry.value,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.primaryBlue,
                        ),
                      ),
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

// Tactical Vector Map Canvas Painter (Fast, clean, 100% offline)
class _TacticalMapPainter extends CustomPainter {
  final LatLng? userLocation;
  final LatLng mapOrigin;
  final LatLng? safeReportLocation;
  final ReliefAreaModel? selectedArea;
  final List<ReliefAreaModel> areas;
  final Offset offset;
  final double scale;
  final double pulseValue;
  final void Function(ReliefAreaModel area) onSelectArea;

  _TacticalMapPainter({
    required this.userLocation,
    required this.mapOrigin,
    required this.safeReportLocation,
    required this.selectedArea,
    required this.areas,
    required this.offset,
    required this.scale,
    required this.pulseValue,
    required this.onSelectArea,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2) + offset;

    // 1. Background Grid & Radar Circle
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1.0;

    const step = 60.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Radar Rings
    final ringPaint = Paint()
      ..color = const Color(0xFF334155).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, 120, ringPaint);
    canvas.drawCircle(center, 240, ringPaint);
    canvas.drawCircle(center, 380, ringPaint);

    // Pulse Ring around user
    final pulsePaint = Paint()
      ..color = AppColors.primaryBlue.withValues(
        alpha: (1.0 - pulseValue).clamp(0.0, 1.0) * 0.4,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    if (userLocation != null) {
      canvas.drawCircle(center, 20 + (pulseValue * 45), pulsePaint);
    }

    // 2. Main Street Vectors (Simulating city grid)
    final streetPaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx - 300, center.dy - 100),
      Offset(center.dx + 300, center.dy + 150),
      streetPaint,
    );
    canvas.drawLine(
      Offset(center.dx - 200, center.dy + 250),
      Offset(center.dx + 250, center.dy - 200),
      streetPaint,
    );
    canvas.drawLine(
      Offset(center.dx - 250, center.dy),
      Offset(center.dx + 250, center.dy),
      streetPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 300),
      Offset(center.dx, center.dy + 300),
      streetPaint,
    );

    // 3. Draw Route Path to selected area (Meta AI Recommended Route)
    if (selectedArea != null && userLocation != null) {
      final destX =
          center.dx +
          (selectedArea!.location.longitude - mapOrigin.longitude) * 12000;
      final destY =
          center.dy -
          (selectedArea!.location.latitude - mapOrigin.latitude) * 12000;

      final routePaint = Paint()
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 5.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo((center.dx + destX) / 2 + 20, (center.dy + destY) / 2 - 20)
        ..lineTo(destX, destY);

      canvas.drawPath(path, routePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TacticalMapPainter oldDelegate) {
    return oldDelegate.userLocation != userLocation ||
        oldDelegate.mapOrigin != mapOrigin ||
        oldDelegate.safeReportLocation != safeReportLocation ||
        oldDelegate.offset != offset ||
        oldDelegate.selectedArea != selectedArea ||
        oldDelegate.areas != areas ||
        oldDelegate.pulseValue != pulseValue;
  }
}
