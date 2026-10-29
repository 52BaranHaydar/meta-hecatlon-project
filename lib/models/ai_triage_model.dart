import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum UrgencyLevel {
  critical('KRİTİK', 0.95, AppColors.emergencyRed, Icons.emergency_rounded),
  high('YÜKSEK', 0.78, AppColors.carrierOrange, Icons.warning_rounded),
  medium('ORTA', 0.52, AppColors.warning, Icons.info_rounded),
  low('DÜŞÜK', 0.25, AppColors.info, Icons.check_circle_rounded);

  final String title;
  final double threshold;
  final Color color;
  final IconData icon;

  const UrgencyLevel(this.title, this.threshold, this.color, this.icon);

  static UrgencyLevel fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'KRİTİK':
      case 'CRITICAL':
        return UrgencyLevel.critical;
      case 'YÜKSEK':
      case 'HIGH':
        return UrgencyLevel.high;
      case 'DÜŞÜK':
      case 'LOW':
        return UrgencyLevel.low;
      case 'ORTA':
      case 'MEDIUM':
      default:
        return UrgencyLevel.medium;
    }
  }
}

class AiTriageResult {
  final String id;
  final String rawText;
  final String category;
  final UrgencyLevel urgency;
  final double confidenceScore;
  final String modelName;
  final String recommendedAction;
  final List<String> requiredResources;
  final bool shouldTrigger112;
  final String etaWindow;
  final DateTime timestamp;
  final String location;
  final String status; // 'Bekliyor', 'Ekip Yönlendirildi', 'Çözüldü'

  const AiTriageResult({
    required this.id,
    required this.rawText,
    required this.category,
    required this.urgency,
    required this.confidenceScore,
    this.modelName = 'Meta-Llama-3-70B-Instruct (Cloud Functions)',
    required this.recommendedAction,
    required this.requiredResources,
    required this.shouldTrigger112,
    required this.etaWindow,
    required this.timestamp,
    this.location = 'Şehitkamil Merkez, Gaziantep',
    this.status = 'Bekliyor',
  });

  AiTriageResult copyWith({
    String? id,
    String? rawText,
    String? category,
    UrgencyLevel? urgency,
    double? confidenceScore,
    String? modelName,
    String? recommendedAction,
    List<String>? requiredResources,
    bool? shouldTrigger112,
    String? etaWindow,
    DateTime? timestamp,
    String? location,
    String? status,
  }) {
    return AiTriageResult(
      id: id ?? this.id,
      rawText: rawText ?? this.rawText,
      category: category ?? this.category,
      urgency: urgency ?? this.urgency,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      modelName: modelName ?? this.modelName,
      recommendedAction: recommendedAction ?? this.recommendedAction,
      requiredResources: requiredResources ?? this.requiredResources,
      shouldTrigger112: shouldTrigger112 ?? this.shouldTrigger112,
      etaWindow: etaWindow ?? this.etaWindow,
      timestamp: timestamp ?? this.timestamp,
      location: location ?? this.location,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rawText': rawText,
      'category': category,
      'urgency': urgency.title,
      'confidenceScore': confidenceScore,
      'modelName': modelName,
      'recommendedAction': recommendedAction,
      'requiredResources': requiredResources,
      'shouldTrigger112': shouldTrigger112,
      'etaWindow': etaWindow,
      'timestamp': timestamp.toIso8601String(),
      'location': location,
      'status': status,
    };
  }

  factory AiTriageResult.fromMap(Map<String, dynamic> map, {String? docId}) {
    return AiTriageResult(
      id: docId ?? map['id'] ?? 'AI-TR-000',
      rawText: map['rawText'] ?? '',
      category: map['category'] ?? 'GENEL İHBAR',
      urgency: UrgencyLevel.fromString(map['urgency']),
      confidenceScore: (map['confidenceScore'] as num?)?.toDouble() ?? 0.90,
      modelName: map['modelName'] ?? 'Meta-Llama-3-70B-Instruct',
      recommendedAction: map['recommendedAction'] ?? '',
      requiredResources: (map['requiredResources'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      shouldTrigger112: map['shouldTrigger112'] == true,
      etaWindow: map['etaWindow'] ?? '1-2 Saat',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      location: map['location'] ?? 'Gaziantep Merkez',
      status: map['status'] ?? 'Bekliyor',
    );
  }

  // Pre-configured realistic AI scenarios for hackathon demonstration
  static final List<AiTriageResult> sampleScenarios = [
    AiTriageResult(
      id: 'AI-TR-101',
      rawText:
          'Binanın 2. katında çökme var, içeride 3 kişilik bir aile ses veriyor. Yan tarafta gaz kokusu alıyoruz!',
      category: 'ENKAZ & ARAMA KURTARMA',
      urgency: UrgencyLevel.critical,
      confidenceScore: 0.98,
      recommendedAction:
          'Acil Arama Kurtarma (AKUT/AFAD) ve Doğalgaz Acil Ekibi ivedilikle yönlendirilmeli. Gaz patlaması riski nedeniyle ateş yakılmamalı.',
      requiredResources: [
        'Ses Dinleme Cihazı',
        'K9 Kurtarma Köpeği',
        'Gaz Dedektörü',
        'Hidrolik Kesici',
      ],
      shouldTrigger112: true,
      etaWindow: 'Altın İlk 4 Saat İçinde Müdahale Şart',
      timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
      location: 'Şehitkamil, Osmangazi Mah. No: 14',
      status: 'Bekliyor',
    ),
    AiTriageResult(
      id: 'AI-TR-102',
      rawText:
          '72 yaşında tansiyon ve kalp hastası dedemiz için acil dil altı ilacı ve oksijen tüpü gerekiyor.',
      category: 'SAĞLIK & MEDİKAL',
      urgency: UrgencyLevel.high,
      confidenceScore: 0.94,
      recommendedAction:
          'En yakın Sahra Hastanesi mobil sağlık timi yönlendirildi. Hastayı sakin ve yarı oturur pozisyonda tutunuz.',
      requiredResources: [
        'Taşınabilir Oksijen',
        'Acil Kardiyo İlaçları',
        'Mobil Sağlık Ekibi',
      ],
      shouldTrigger112: true,
      etaWindow: 'Maksimum 30 Dakika',
      timestamp: DateTime.now().subtract(const Duration(minutes: 18)),
      location: 'İstasyon Cad. Sahra Bölgesi B Blok',
      status: 'Bekliyor',
    ),
    AiTriageResult(
      id: 'AI-TR-103',
      rawText:
          'Çadır kent 2. bölgede temiz içme suyu bitti ve 40 bebek için acil mama ihtiyacı var.',
      category: 'SU & TEMEL YAŞAM',
      urgency: UrgencyLevel.medium,
      confidenceScore: 0.89,
      recommendedAction:
          'En yakın yardım konvoyuna (Adana Lojistik sevkiyatı) rota güncellenerek 200 koli su ve bebek maması sevk emri verildi.',
      requiredResources: [
        '0.5L İçme Suyu',
        'Bebek Maması (0-12 Ay)',
        'Hijyen Kiti',
      ],
      shouldTrigger112: false,
      etaWindow: '2-4 Saat İçinde İkmal',
      timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
      location: 'Atatürk Parkı 2. Çadır Alanı',
      status: 'Ekip Yönlendirildi',
    ),
  ];
}
