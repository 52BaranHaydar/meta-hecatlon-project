import 'package:flutter/material.dart';
import '../../models/relief_area_model.dart';
import '../../models/shipment_model.dart';
import '../../models/user_model.dart';
import '../../services/logistics_service.dart';
import '../../services/language_service.dart';

class CarrierHomeScreen extends StatefulWidget {
  final UserModel user;
  final LogisticsService logisticsService;
  final void Function(ReliefAreaModel? area)? onNavigateToMap;

  const CarrierHomeScreen({
    super.key,
    required this.user,
    required this.logisticsService,
    this.onNavigateToMap,
  });

  @override
  State<CarrierHomeScreen> createState() => _CarrierHomeScreenState();
}

class _CarrierHomeScreenState extends State<CarrierHomeScreen> {
  final _plateController = TextEditingController();
  final _quantityController = TextEditingController();
  String _selectedVehicle = 'Tır';
  String _selectedCategory = 'Su';

  LogisticsService get _logisticsService => widget.logisticsService;

  @override
  void dispose() {
    _plateController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _logisticsService,
      builder: (context, child) {
        final aiRecommendedDestination = _logisticsService
            .getAIRecommendedDestination(_selectedCategory);
        final shipments = _logisticsService.shipmentsFor(widget.user.uid);
        final activeShipments = shipments
            .where((shipment) => shipment.status != ShipmentStatus.teslimEdildi)
            .toList();
        final activeCargoQuantity = activeShipments.fold<int>(
          0,
          (total, shipment) => total + shipment.quantity,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Yeni Yük Ekleme Butonu
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _showAddShipmentBottomSheet(context),
                  icon: const Icon(Icons.add_location_alt),
                  label: Text(
                    context.t('ADD NEW CARGO & SHIPMENT', 'YENİ YÜK & SEVKİYAT EKLE'),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _buildCargoSummary(activeShipments.length, activeCargoQuantity),
              if (_logisticsService.syncError case final error?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    error,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 16),
              _buildUrgentNeedPoints(),
              const SizedBox(height: 20),

              Card(
                color: Colors.orange.shade50,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.deepOrange, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.deepOrange),
                          const SizedBox(width: 8),
                          Text(
                            context.t('Meta AI Recommended Route', 'Meta AI Önerilen Rota'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.t('Selected Cargo Type: $_selectedCategory', 'Seçili Yük Türü: $_selectedCategory'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.t('Highest Need Location: $aiRecommendedDestination', 'İhtiyacı En Yüksek Alan: $aiRecommendedDestination'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Stok kritik: $_selectedCategory ihtiyacı en yüksek '
                        '$aiRecommendedDestination noktasına gitmeniz önerilir.',
                        style: TextStyle(
                          color: Colors.deepOrange.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${context.t("Current \$_selectedCategory stock: ", "Mevcut \$_selectedCategory stoku: ")}\${_logisticsService.stockLabel(aiRecommendedDestination, _selectedCategory)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      if (widget.onNavigateToMap != null)
                        TextButton.icon(
                          onPressed: () {
                            final area = _logisticsService.areaByName(
                              aiRecommendedDestination,
                            );
                            if (area != null) {
                              widget.onNavigateToMap!(area);
                            }
                          },
                          icon: const Icon(Icons.map_outlined),
                          label: Text(context.t('Open Destination on Map', 'Hedefi Haritada Aç')),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                context.t('Your Active Shipments', 'Mevcut Taşımalarınız (Shipments)'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              shipments.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(context.t('No active shipment record yet.', 'Henüz aktif bir sevkiyat kaydı yok.')),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: shipments.length,
                      itemBuilder: (context, index) {
                        final shipment = shipments[index];
                        return _buildShipmentCard(shipment);
                      },
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCargoSummary(int shipmentCount, int quantity) {
    return Card(
      color: Colors.deepOrange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.local_shipping_rounded,
              color: Colors.deepOrange,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('Active Cargo in Vehicles', 'Araçlarımdaki Aktif Yük'),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(context.t('$shipmentCount shipments · $quantity cargo units', '$shipmentCount sevkiyat · $quantity birim yük')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgentNeedPoints() {
    final urgentPoints = _logisticsService
        .getUrgentNeedPoints(_selectedCategory)
        .take(3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('Urgent Relief Points', 'Acil İhtiyaç Noktaları'),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...urgentPoints.map((point) {
          final areaMatches = ReliefAreaModel.demoAreas
              .where((area) => area.name == point.key)
              .toList();
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(
                Icons.priority_high_rounded,
                color: Colors.deepOrange,
              ),
              title: Text(point.key),
              subtitle: Text('Mevcut $_selectedCategory stoku: ${point.value}'),
              trailing: const Icon(Icons.map_outlined),
              onTap: widget.onNavigateToMap == null || areaMatches.isEmpty
                  ? null
                  : () => widget.onNavigateToMap!(areaMatches.first),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildShipmentCard(ShipmentModel shipment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${shipment.vehicleType} - ${shipment.plateNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                _buildStatusChip(shipment.status),
              ],
            ),
            const Divider(),
            Text(
              'Yük: ${shipment.quantity} '
              '${ShipmentModel.unitFor(shipment.category)} ${shipment.category}',
            ),
            Text('Hedef: ${shipment.destination}'),
            Text(
              'Hedef stok: ${_logisticsService.stockLabel(shipment.destination, shipment.category)}',
            ),
            const SizedBox(height: 12),

            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          shipment.status.index >=
                              ShipmentStatus.yolaCikti.index
                          ? Colors.orange
                          : Colors.grey.shade300,
                    ),
                    onPressed: shipment.status == ShipmentStatus.hazir
                        ? () => _updateShipmentStatus(
                            shipment.id,
                            ShipmentStatus.yolaCikti,
                          )
                        : null,
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: Text(context.t('1. Departed', '1. Yola Çıktım')),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          shipment.status.index >=
                              ShipmentStatus.afetBolgesiGirisinde.index
                          ? Colors.blue
                          : Colors.grey.shade300,
                    ),
                    onPressed: shipment.status == ShipmentStatus.yolaCikti
                        ? () => _updateShipmentStatus(
                            shipment.id,
                            ShipmentStatus.afetBolgesiGirisinde,
                          )
                        : null,
                    icon: const Icon(Icons.place_outlined),
                    label: Text(context.t('2. At Disaster Zone', '2. Afet Bölgesi Girişinde')),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          shipment.status.index >=
                              ShipmentStatus.dagitimNoktasinaUlasti.index
                          ? Colors.teal
                          : Colors.grey.shade300,
                    ),
                    onPressed:
                        shipment.status == ShipmentStatus.afetBolgesiGirisinde
                        ? () => _updateShipmentStatus(
                            shipment.id,
                            ShipmentStatus.dagitimNoktasinaUlasti,
                          )
                        : null,
                    icon: const Icon(Icons.location_on_outlined),
                    label: Text(context.t('3. Arrived at Destination', '3. Dağıtım Noktasına Ulaştım')),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          shipment.status == ShipmentStatus.teslimEdildi
                          ? Colors.green
                          : Colors.grey.shade300,
                    ),
                    onPressed:
                        shipment.status == ShipmentStatus.dagitimNoktasinaUlasti
                        ? () => _updateShipmentStatus(
                            shipment.id,
                            ShipmentStatus.teslimEdildi,
                          )
                        : null,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text(context.t('4. Delivered', '4. Teslim Ettim')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateShipmentStatus(
    String shipmentId,
    ShipmentStatus status,
  ) async {
    try {
      await _logisticsService.updateShipmentStatus(shipmentId, status);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sevkiyat durumu güncellenemedi: $error')),
      );
    }
  }

  Widget _buildStatusChip(ShipmentStatus status) {
    String label;
    Color color;
    switch (status) {
      case ShipmentStatus.yolaCikti:
        label = 'Yola Çıktı';
        color = Colors.orange;
        break;
      case ShipmentStatus.afetBolgesiGirisinde:
        label = 'Afet Bölgesi Girişinde';
        color = Colors.deepOrange;
        break;
      case ShipmentStatus.hazir:
        label = 'Sevkiyat Hazır';
        color = Colors.blueGrey;
        break;
      case ShipmentStatus.dagitimNoktasinaUlasti:
        label = 'Dağıtım Noktasına Ulaştı';
        color = Colors.teal;
        break;
      case ShipmentStatus.teslimEdildi:
        label = context.t('Delivered (+Stock Updated)', 'Teslim Edildi (+Stok Artırıldı)');
        color = Colors.green;
        break;
    }
    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      backgroundColor: color,
    );
  }

  void _showAddShipmentBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        var selectedVehicle = _selectedVehicle;
        var selectedCategory = _selectedCategory;
        return StatefulBuilder(
          builder: (context, setModalState) => ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yeni Sevkiyat Kaydı',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _plateController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Plaka (Örn: 34 ABC 123)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedVehicle,
                          items: ShipmentModel.vehicleTypes
                              .map(
                                (vehicle) => DropdownMenuItem(
                                  value: vehicle,
                                  child: Text(vehicle),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setModalState(() => selectedVehicle = value);
                            setState(() => _selectedVehicle = value);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Araç Tipi',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          items: ShipmentModel.categories
                              .map(
                                (category) => DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setModalState(() => selectedCategory = value);
                            setState(() => _selectedCategory = value);
                          },
                          decoration: InputDecoration(
                            labelText: context.t('Cargo Type', 'Yük Türü'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                    ),
                    decoration: InputDecoration(
                      labelText: context.t('Quantity', 'Miktar'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final plateNumber = _plateController.text.trim();
                        final quantity = int.tryParse(
                          _quantityController.text.trim(),
                        );
                        if (plateNumber.isEmpty ||
                            quantity == null ||
                            quantity <= 0) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Plaka ve pozitif bir miktar girin.',
                              ),
                            ),
                          );
                          return;
                        }

                        final newShipment = ShipmentModel(
                          id: DateTime.now().microsecondsSinceEpoch.toString(),
                          carrierId: widget.user.uid,
                          plateNumber: plateNumber.toUpperCase(),
                          vehicleType: selectedVehicle,
                          category: selectedCategory,
                          quantity: quantity,
                          destination: _logisticsService
                              .getAIRecommendedDestination(selectedCategory),
                        );
                        final messenger = ScaffoldMessenger.of(context);

                        try {
                          await _logisticsService.addShipment(newShipment);
                        } catch (error) {
                          if (!mounted || !context.mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Sevkiyat kaydedilemedi: $error'),
                            ),
                          );
                          return;
                        }
                        if (!mounted || !context.mounted) return;
                        Navigator.of(context).pop();
                        _plateController.clear();
                        _quantityController.clear();
                      },
                      child: Text(context.t('ADD SHIPMENT', 'SEVKİYATI EKLE')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
