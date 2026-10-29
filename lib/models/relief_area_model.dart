import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_colors.dart';

enum AreaCategory {
  assemblyArea('toplanma_alani', 'Toplanma Alanı', Icons.nature_people_rounded, AppColors.success),
  tentCity('cadir_kent', 'Çadır Kent', Icons.holiday_village_rounded, AppColors.carrierOrange),
  hospital('sahra_hastanesi', 'Sahra Hastanesi / İlk Yardım', Icons.local_hospital_rounded, AppColors.emergencyRed),
  aidStation('asevi_gida', 'Aşevi & Su Dağıtım', Icons.restaurant_rounded, AppColors.primaryBlue);

  final String id;
  final String title;
  final IconData icon;
  final Color color;

  const AreaCategory(this.id, this.title, this.icon, this.color);

  static AreaCategory fromString(String? id) {
    return AreaCategory.values.firstWhere(
      (c) => c.id == id,
      orElse: () => AreaCategory.assemblyArea,
    );
  }
}

class ReliefAreaModel {
  final String id;
  final String name;
  final String address;
  final AreaCategory category;
  final LatLng location;
  final int capacity;
  final int occupancy;
  final List<String> services;
  final Map<String, String> stock;
  final String statusText;
  final bool isSafe;

  const ReliefAreaModel({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    required this.location,
    required this.capacity,
    required this.occupancy,
    required this.services,
    required this.stock,
    this.statusText = 'Açık & Güvenli',
    this.isSafe = true,
  });

  double get occupancyRate => capacity > 0 ? (occupancy / capacity).clamp(0.0, 1.0) : 0.0;

  int get availableSpots => (capacity - occupancy).clamp(0, capacity);

  ReliefAreaModel copyWith({
    String? id,
    String? name,
    String? address,
    AreaCategory? category,
    LatLng? location,
    int? capacity,
    int? occupancy,
    List<String>? services,
    Map<String, String>? stock,
    String? statusText,
    bool? isSafe,
  }) {
    return ReliefAreaModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      category: category ?? this.category,
      location: location ?? this.location,
      capacity: capacity ?? this.capacity,
      occupancy: occupancy ?? this.occupancy,
      services: services ?? this.services,
      stock: stock ?? this.stock,
      statusText: statusText ?? this.statusText,
      isSafe: isSafe ?? this.isSafe,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'category': category.id,
      'lat': location.latitude,
      'lng': location.longitude,
      'capacity': capacity,
      'occupancy': occupancy,
      'services': services,
      'stock': stock,
      'statusText': statusText,
      'isSafe': isSafe,
    };
  }

  factory ReliefAreaModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    final rawStock = map['stock'] as Map<String, dynamic>? ?? {};
    return ReliefAreaModel(
      id: docId ?? map['id'] ?? 'area_custom',
      name: map['name'] ?? 'Toplanma Alanı',
      address: map['address'] ?? '',
      category: AreaCategory.fromString(map['category']),
      location: LatLng(
        (map['lat'] as num?)?.toDouble() ?? 37.0680,
        (map['lng'] as num?)?.toDouble() ?? 37.3790,
      ),
      capacity: (map['capacity'] as num?)?.toInt() ?? 1000,
      occupancy: (map['occupancy'] as num?)?.toInt() ?? 0,
      services: (map['services'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const ['Temiz Su', 'Güvenli Alan'],
      stock: rawStock.map((k, v) => MapEntry(k, v.toString())),
      statusText: map['statusText'] ?? 'Açık & Güvenli',
      isSafe: map['isSafe'] != false,
    );
  }

  // Demo Seed Data (Matching Plan L4 requirements)
  static final List<ReliefAreaModel> demoAreas = [
    const ReliefAreaModel(
      id: 'area_1',
      name: 'Atatürk Parkı Güvenli Toplanma Alanı',
      address: 'Şehitkamil, Osmangazi Mah. Park İçi',
      category: AreaCategory.assemblyArea,
      location: LatLng(37.0690, 37.3780),
      capacity: 3000,
      occupancy: 1100,
      services: ['Temiz Su', 'Aydınlatma', 'İlk Yardım Çadırı', 'Mobil Tuvalet', 'Şarj İstasyonu'],
      stock: {'İçme Suyu': '1.200 Şişe', 'Battaniye': '350 Adet', 'Bebek Maması': '90 Kutu'},
    ),
    const ReliefAreaModel(
      id: 'area_2',
      name: 'Kamil Ocak 1 Nolu Çadır Kent',
      address: 'Kamil Ocak Spor Kompleksi Çevresi',
      category: AreaCategory.tentCity,
      location: LatLng(37.0620, 37.3850),
      capacity: 1500,
      occupancy: 1250,
      services: ['Isınma', 'Barınma Çadırları', 'Gıda Dağıtımı', 'Psikososyal Destek'],
      stock: {'Çadır': '15 Boş', 'Isıtıcı': '40 Adet', 'Kuru Gıda': '500 Paket'},
    ),
    const ReliefAreaModel(
      id: 'area_3',
      name: 'Kızılay Aşevi ve Temel İhtiyaç Noktası',
      address: 'Mithatpaşa Meydanı Dağıtım Merkezi',
      category: AreaCategory.aidStation,
      location: LatLng(37.0735, 37.3890),
      capacity: 4000,
      occupancy: 800,
      services: ['Sıcak Çorba', 'Ekmek Dağıtımı', 'Konserve & Su', 'Bebek Bezi & Hijyen'],
      stock: {'Sıcak Yemek': 'Günlük 3.000 Porsiyon', 'İçme Suyu': 'Bol', 'Hijyen Seti': '200 Adet'},
    ),
    const ReliefAreaModel(
      id: 'area_4',
      name: 'Sahra Acil Müdahale ve İlk Yardım Merkezi',
      address: 'İstasyon Caddesi Sağlık Çadırı',
      category: AreaCategory.hospital,
      location: LatLng(37.0610, 37.3720),
      capacity: 500,
      occupancy: 280,
      services: ['Doktor & Hemşire', 'Temel İlaçlar', 'Pansuman', 'Ambulans İrtibat'],
      stock: {'Serum': '150 Adet', 'Ağrı Kesici & Antibiyotik': 'Mevcut', 'İlk Yardım Çantası': '80 Adet'},
    ),
    const ReliefAreaModel(
      id: 'area_5',
      name: 'Masal Parkı 2. Toplanma Bölgesi',
      address: 'Sarıgüllük Mah. Masal Parkı İçi',
      category: AreaCategory.assemblyArea,
      location: LatLng(37.0780, 37.3680),
      capacity: 5000,
      occupancy: 950,
      services: ['Geniş Açık Alan', 'Jeneratör', 'İçme Suyu Deposu', 'Helikopter Pisti'],
      stock: {'İçme Suyu': '2.000 L Depo', 'Battaniye': '600 Adet'},
    ),
  ];
}
