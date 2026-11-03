enum ShipmentStatus {
  hazir,
  yolaCikti,
  afetBolgesiGirisinde,
  dagitimNoktasinaUlasti,
  teslimEdildi,
}

class ShipmentModel {
  static const List<String> vehicleTypes = ['Tır', 'Kamyonet'];

  static const List<String> categories = [
    'Su',
    'Çadır',
    'İlaç',
    'Mama',
    'Gıda',
    'Battaniye',
  ];

  static String unitFor(String category) {
    return switch (category) {
      'Su' => 'Şişe',
      'Çadır' || 'Battaniye' => 'Adet',
      'İlaç' || 'Mama' => 'Kutu',
      'Gıda' => 'Koli',
      _ => 'Birim',
    };
  }

  final String id;
  final String carrierId;
  final String plateNumber;
  final String vehicleType;
  final String category;
  final int quantity;
  final String destination;
  final ShipmentStatus status;

  const ShipmentModel({
    required this.id,
    required this.carrierId,
    required this.plateNumber,
    required this.vehicleType,
    required this.category,
    required this.quantity,
    required this.destination,
    this.status = ShipmentStatus.hazir,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'carrierId': carrierId,
      'plateNumber': plateNumber,
      'vehicleType': vehicleType,
      'category': category,
      'quantity': quantity,
      'destination': destination,
      'status': status.name,
    };
  }

  factory ShipmentModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    final statusName = map['status'] as String?;
    final compatibleStatusName = statusName == 'bolgeyeUlasti'
        ? ShipmentStatus.dagitimNoktasinaUlasti.name
        : statusName;
    final status = ShipmentStatus.values.where(
      (value) => value.name == compatibleStatusName,
    );
    return ShipmentModel(
      id: docId ?? map['id']?.toString() ?? '',
      carrierId: map['carrierId']?.toString() ?? '',
      plateNumber: map['plateNumber']?.toString() ?? '',
      vehicleType: map['vehicleType']?.toString() ?? vehicleTypes.first,
      category: map['category']?.toString() ?? categories.first,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      destination: map['destination']?.toString() ?? '',
      status: status.isEmpty ? ShipmentStatus.hazir : status.first,
    );
  }

  ShipmentModel copyWith({ShipmentStatus? status}) {
    return ShipmentModel(
      id: id,
      carrierId: carrierId,
      plateNumber: plateNumber,
      vehicleType: vehicleType,
      category: category,
      quantity: quantity,
      destination: destination,
      status: status ?? this.status,
    );
  }
}
