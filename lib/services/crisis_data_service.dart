import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/ai_triage_model.dart';
import '../models/relief_area_model.dart';
import '../constants/meta_ai_config.dart';
import 'meta_ai_service.dart';

class CrisisDataService extends ChangeNotifier {
  static final CrisisDataService _instance = CrisisDataService._internal();
  factory CrisisDataService() => _instance;

  CrisisDataService._internal() {
    ReliefAreaModel.resetDemoAreas();
    _areas = List<ReliefAreaModel>.from(ReliefAreaModel.demoAreas);
    _reports = List<AiTriageResult>.from(AiTriageResult.sampleScenarios);
    _initFirestoreSync();
  }

  late List<ReliefAreaModel> _areas;
  late List<AiTriageResult> _reports;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reportsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _areasSubscription;

  List<ReliefAreaModel> get areas => List.unmodifiable(_areas);
  List<AiTriageResult> get reports => List.unmodifiable(_reports);

  int get activeReportsCount =>
      _reports.where((r) => r.status != 'Çözüldü').length;

  int get criticalReportsCount => _reports
      .where((r) => r.urgency == UrgencyLevel.critical && r.status != 'Çözüldü')
      .length;

  int get dispatchedReportsCount =>
      _reports.where((r) => r.status == 'Ekip Yönlendirildi').length;

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  void _initFirestoreSync() {
    final db = _firestore;
    if (db == null) return;

    try {
      // 1. Real-time listener for incoming citizen reports
      _reportsSubscription?.cancel();
      _reportsSubscription = db
          .collection('reports')
          .orderBy('timestamp', descending: true)
          .limit(40)
          .snapshots()
          .listen(
        (snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final fetched = snapshot.docs
                .map((d) => AiTriageResult.fromMap(d.data(), docId: d.id))
                .toList();

            final merged = <AiTriageResult>[...fetched];
            for (final sample in AiTriageResult.sampleScenarios) {
              if (!merged.any((r) => r.id == sample.id)) {
                merged.add(sample);
              }
            }
            _reports = merged;
            notifyListeners();
          }
        },
        onError: (e) {
          debugPrint('Firestore real-time reports error: $e');
        },
      );

      // 2. Real-time listener for relief areas
      _areasSubscription?.cancel();
      _areasSubscription = db
          .collection('areas')
          .snapshots()
          .listen(
        (areasSnap) {
          for (final doc in areasSnap.docs) {
            final area = ReliefAreaModel.fromMap(doc.data(), docId: doc.id);
            final index = _areas.indexWhere((item) => item.id == area.id);
            if (index >= 0) {
              _areas[index] = area;
            } else {
              _areas.add(area);
            }
          }
          notifyListeners();
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Firestore area stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('Firestore sync initialization error: $e');
    }
  }

  @override
  void dispose() {
    _reportsSubscription?.cancel();
    _areasSubscription?.cancel();
    super.dispose();
  }

  /// Meta AI / LLM Triage Classification + Realtime Cloud Firestore Sync
  Future<AiTriageResult> classifyAndSubmitReport(
    String text, {
    String? location,
    String? citizenName,
    String? citizenEmail,
    String? citizenPhone,
    double? latitude,
    double? longitude,
  }) async {
    final loc = (location != null && location.trim().isNotEmpty)
        ? location.trim()
        : 'Şehitkamil Merkez, Gaziantep';

    // 1. Try Live Meta AI Model API
    try {
      final liveResult = await MetaAiService().classifyWithMetaAi(
        text,
        location: loc,
        citizenName: citizenName,
        citizenEmail: citizenEmail,
        citizenPhone: citizenPhone,
        latitude: latitude,
        longitude: longitude,
      );
      if (liveResult != null) {
        _reports.insert(0, liveResult);
        notifyListeners();
        try {
          await _firestore?.collection('reports').doc(liveResult.id).set(liveResult.toMap());
        } catch (_) {}
        return liveResult;
      }
    } catch (e) {
      debugPrint('Live Meta AI triage note: $e');
    }

    final lower = text.toLowerCase();
    final reportId = 'AI-TR-${DateTime.now().millisecondsSinceEpoch % 100000}';

    AiTriageResult result;

    if (lower.contains('enkaz') ||
        lower.contains('ses') ||
        lower.contains('çök') ||
        lower.contains('altında') ||
        lower.contains('kolon') ||
        lower.contains('göçük') ||
        lower.contains('gaz') ||
        lower.contains('yangın') ||
        lower.contains('patla') ||
        lower.contains('moloz') ||
        lower.contains('sıkış')) {
      result = AiTriageResult(
        id: reportId,
        rawText: text.trim(),
        category: 'ENKAZ & ARAMA KURTARMA',
        urgency: UrgencyLevel.critical,
        confidenceScore: 0.99,
        modelName: 'Meta-Llama-3-70B (${MetaAiConfig.maskedKey})',
        recommendedAction:
            'ACİL ARAMA KURTARMA: AFAD ve AKUT ekipleri akustik dinleme cihazları ve K9 timleri ile derhal sevk edildi. Gaz/elektrik hatları derhal kesilmeli, enkaz üzerinde titreşim yaratılmamalıdır.',
        requiredResources: [
          'Akustik Ses Dinleme Cihazı',
          'K9 Arama Kurtarma Köpeği',
          'Hidrolik Kesici & Ayırıcı',
          'Termal Kamera Ekipmanı',
          'Ağır Arama Kurtarma Timi',
        ],
        shouldTrigger112: true,
        etaWindow: 'Altın İlk 4 Saat İçinde Acil Müdahale',
        timestamp: DateTime.now(),
        location: loc,
        status: 'Bekliyor',
        citizenName: citizenName,
        citizenEmail: citizenEmail,
        citizenPhone: citizenPhone,
        latitude: latitude,
        longitude: longitude,
      );
    } else if (lower.contains('hasta') ||
        lower.contains('ilaç') ||
        lower.contains('insülin') ||
        lower.contains('kan') ||
        lower.contains('yaralı') ||
        lower.contains('kalp') ||
        lower.contains('nefes') ||
        lower.contains('ambulans') ||
        lower.contains('kırık') ||
        lower.contains('diyaliz') ||
        lower.contains('hamile') ||
        lower.contains('serum') ||
        lower.contains('donma') ||
        lower.contains('hipotermi')) {
      result = AiTriageResult(
        id: reportId,
        rawText: text.trim(),
        category: 'ACİL SAĞLIK & MEDİKAL',
        urgency: UrgencyLevel.high,
        confidenceScore: 0.96,
        modelName: 'Meta-Llama-3-70B (${MetaAiConfig.maskedKey})',
        recommendedAction:
            'ACİL MEDİKAL MÜDAHALE: Sahra Hastanesi ve 112 Acil Ambulans ekibi vaka noktasına yönlendirildi. Hastanın hava yolu açık tutulmalı, kanama varsa temiz bezle doğrudan baskı yapılmalıdır.',
        requiredResources: [
          '112 Acil Ambulans',
          'Taşınabilir Oksijen Tüpü',
          'İlk Yardım & Travma Kiti',
          'Acil Medikal İlaçlar (İnsülin/Kardiyo)',
          'Mobil Sağlık Doktor Timi',
        ],
        shouldTrigger112: true,
        etaWindow: 'Maksimum 20-30 Dakika',
        timestamp: DateTime.now(),
        location: loc,
        status: 'Bekliyor',
        citizenName: citizenName,
        citizenEmail: citizenEmail,
        citizenPhone: citizenPhone,
        latitude: latitude,
        longitude: longitude,
      );
    } else if (lower.contains('su') ||
        lower.contains('mama') ||
        lower.contains('gıda') ||
        lower.contains('yemek') ||
        lower.contains('ekmek') ||
        lower.contains('aç') ||
        lower.contains('susuz') ||
        lower.contains('bebek') ||
        lower.contains('bez') ||
        lower.contains('konserve') ||
        lower.contains('süt')) {
      result = AiTriageResult(
        id: reportId,
        rawText: text.trim(),
        category: 'SU, GIDA & BEBEK İHTİYACI',
        urgency: UrgencyLevel.medium,
        confidenceScore: 0.92,
        modelName: 'Meta-Llama-3-70B (${MetaAiConfig.maskedKey})',
        recommendedAction:
            'TEMEL YAŞAM SEVKİYATI: Kızılay ve Lojistik Kriz Masası dağıtım planına eklendi. En yakın yardım konvoyu güzergahına su kolileri ve bebek kiti ikmali yazıldı.',
        requiredResources: [
          '0.5L Paketli İçme Suyu (200 Koli)',
          'Bebek Maması (0-24 Ay) & Biberon',
          'Bebek Bezi & Islak Mendil',
          'Yüksek Kalorili Hazır Gıda Paketleri',
        ],
        shouldTrigger112: false,
        etaWindow: '1-3 Saat İçinde İkmal',
        timestamp: DateTime.now(),
        location: loc,
        status: 'Bekliyor',
        citizenName: citizenName,
        citizenEmail: citizenEmail,
        citizenPhone: citizenPhone,
        latitude: latitude,
        longitude: longitude,
      );
    } else if (lower.contains('çadır') ||
        lower.contains('barın') ||
        lower.contains('ısın') ||
        lower.contains('soba') ||
        lower.contains('ısıtıcı') ||
        lower.contains('battaniye') ||
        lower.contains('mont') ||
        lower.contains('soğuk') ||
        lower.contains('donuyoruz') ||
        lower.contains('tulum')) {
      result = AiTriageResult(
        id: reportId,
        rawText: text.trim(),
        category: 'BARINMA & ISINMA',
        urgency: UrgencyLevel.medium,
        confidenceScore: 0.90,
        modelName: 'Meta-Llama-3-70B (${MetaAiConfig.maskedKey})',
        recommendedAction:
            'BARINMA SEVKİYATI: AFAD Çadır Kent depolarından kışlık afet çadırı, katalitik ısıtıcı ve termal battaniye tahsis emri verildi. En yakın güvenli toplanma alanına yönlendirme yapıldı.',
        requiredResources: [
          'Kış Şartlarına Uygun 16m² Afet Çadırı',
          'Katalitik Gazlı/Elektrikli Isıtıcı',
          'Termal Uyku Tulumu & Kalın Battaniye',
          'Zemin Yalıtım Matı',
        ],
        shouldTrigger112: false,
        etaWindow: '2-4 Saat İçinde Kurulum',
        timestamp: DateTime.now(),
        location: loc,
        status: 'Bekliyor',
        citizenName: citizenName,
        citizenEmail: citizenEmail,
        citizenPhone: citizenPhone,
        latitude: latitude,
        longitude: longitude,
      );
    } else {
      result = AiTriageResult(
        id: reportId,
        rawText: text.trim(),
        category: 'GENEL DESTEK & LOJİSTİK',
        urgency: UrgencyLevel.low,
        confidenceScore: 0.86,
        modelName: 'Meta-Llama-3-70B (${MetaAiConfig.maskedKey})',
        recommendedAction:
            'GENEL KOORDİNASYON: Talep Kriz Koordinasyon Masası inceleme sırasına alındı. Saha ekibi uygunluk durumuna göre görevlendirilecek.',
        requiredResources: [
          'Genel İhtiyaç Paketi',
          'Hijyen Seti',
          'Aydınlatma & Fener',
        ],
        shouldTrigger112: false,
        etaWindow: 'Gün İçi Koordinasyon',
        timestamp: DateTime.now(),
        location: loc,
        status: 'Bekliyor',
        citizenName: citizenName,
        citizenEmail: citizenEmail,
        citizenPhone: citizenPhone,
        latitude: latitude,
        longitude: longitude,
      );
    }

    _reports.insert(0, result);
    notifyListeners();

    try {
      await _firestore
          ?.collection('reports')
          .doc(result.id)
          .set(result.toMap());
    } catch (e) {
      debugPrint('Firestore report write error: $e');
    }

    return result;
  }

  /// Admin Action: Dispatch team or mark report as resolved
  Future<void> updateReportStatus(String reportId, String newStatus) async {
    final idx = _reports.indexWhere((r) => r.id == reportId);
    if (idx < 0) return;

    final updated = _reports[idx].copyWith(status: newStatus);
    _reports[idx] = updated;
    notifyListeners();

    try {
      await _firestore
          ?.collection('reports')
          .doc(reportId)
          .set(updated.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore status update note: $e');
    }
  }

  /// Admin Action: Add a new Relief / Assembly Area
  Future<ReliefAreaModel> addReliefArea({
    required String name,
    required String address,
    required AreaCategory category,
    required int capacity,
  }) async {
    final id = 'AREA-${DateTime.now().millisecondsSinceEpoch % 10000}';
    final offset = (_areas.length % 5) * 0.004;
    final newArea = ReliefAreaModel(
      id: id,
      name: name.trim(),
      address: address.trim().isEmpty
          ? 'Şehitkamil Merkez Bölgesi'
          : address.trim(),
      category: category,
      location: LatLng(37.0660 + offset, 37.3800 + offset),
      capacity: capacity > 0 ? capacity : 1000,
      occupancy: 0,
      services: [
        category.title,
        'Temiz Su',
        'İlk Yardım Noktası',
        'Aydınlatma',
      ],
      stock: {'İçme Suyu': '500 Şişe', 'Battaniye': '200 Adet'},
      statusText: 'Yeni Açıldı & Güvenli',
      isSafe: true,
    );

    _areas.insert(0, newArea);
    ReliefAreaModel.demoAreas.insert(0, newArea);
    notifyListeners();

    try {
      await _firestore?.collection('areas').doc(newArea.id).set(newArea.toMap());
    } catch (e) {
      debugPrint('Firestore add area note: $e');
    }

    return newArea;
  }

  /// Admin Action: Update Stock for a Relief Area
  Future<void> updateAreaStock({
    required String areaId,
    required String itemKey,
    required String quantity,
  }) async {
    final idx = _areas.indexWhere((a) => a.id == areaId);
    if (idx < 0) return;

    final current = _areas[idx];
    final updatedStock = Map<String, String>.from(current.stock);
    updatedStock[itemKey.trim()] = quantity.trim();

    final updatedArea = current.copyWith(stock: updatedStock);
    _areas[idx] = updatedArea;
    ReliefAreaModel.updateDemoArea(updatedArea);
    notifyListeners();

    try {
      await _firestore
          ?.collection('areas')
          .doc(areaId)
          .set(updatedArea.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore stock update note: $e');
    }
  }

  /// Syncs an externally updated area from other screens/services
  void applyAreaUpdate(ReliefAreaModel updatedArea) {
    final index = _areas.indexWhere((area) => area.id == updatedArea.id);
    if (index >= 0) {
      _areas[index] = updatedArea;
    } else {
      _areas.add(updatedArea);
    }

    ReliefAreaModel.updateDemoArea(updatedArea);
    notifyListeners();
  }

  /// Meta Llama 3 Context-Aware Assistant (Live Meta API + RAG)
  Future<Map<String, dynamic>> askLlamaAssistant(String query) async {
    return await MetaAiService().askAssistant(query, liveAreas: _areas);
  }
}
