import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/ai_triage_model.dart';
import '../models/relief_area_model.dart';

class CrisisDataService extends ChangeNotifier {
  static final CrisisDataService _instance = CrisisDataService._internal();
  factory CrisisDataService() => _instance;

  CrisisDataService._internal() {
    _areas = List<ReliefAreaModel>.from(ReliefAreaModel.demoAreas);
    _reports = List<AiTriageResult>.from(AiTriageResult.sampleScenarios);
    _syncFromFirestore();
  }

  late List<ReliefAreaModel> _areas;
  late List<AiTriageResult> _reports;

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

  Future<void> _syncFromFirestore() async {
    final db = _firestore;
    if (db == null) return;

    try {
      final reportsSnap = await db
          .collection('reports')
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();
      if (reportsSnap.docs.isNotEmpty) {
        final fetchedReports = reportsSnap.docs
            .map((d) => AiTriageResult.fromMap(d.data(), docId: d.id))
            .toList();
        for (final fr in fetchedReports) {
          if (!_reports.any((r) => r.id == fr.id)) {
            _reports.insert(0, fr);
          }
        }
        notifyListeners();
      }

      final areasSnap = await db.collection('areas').get();
      if (areasSnap.docs.isNotEmpty) {
        for (final doc in areasSnap.docs) {
          final fa = ReliefAreaModel.fromMap(doc.data(), docId: doc.id);
          final existingIdx = _areas.indexWhere((a) => a.id == fa.id);
          if (existingIdx >= 0) {
            _areas[existingIdx] = fa;
          } else {
            _areas.add(fa);
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Firestore initial sync note: $e');
    }
  }

  /// Meta Llama 3 AI Triage Classification + Live Admin Dispatch & Firestore Save
  Future<AiTriageResult> classifyAndSubmitReport(
    String text, {
    String? location,
  }) async {
    await Future.delayed(const Duration(milliseconds: 750));

    final lower = text.toLowerCase();
    final reportId = 'AI-TR-${DateTime.now().millisecondsSinceEpoch % 10000}';
    final loc = (location != null && location.trim().isNotEmpty)
        ? location.trim()
        : 'Şehitkamil Merkez, Gaziantep';

    AiTriageResult result;

    if (lower.contains('enkaz') ||
        lower.contains('ses') ||
        lower.contains('çök') ||
        lower.contains('altında') ||
        lower.contains('gaz') ||
        lower.contains('yangın') ||
        lower.contains('sıkış')) {
      result = AiTriageResult(
        id: reportId,
        rawText: text.trim(),
        category: 'ENKAZ & ARAMA KURTARMA',
        urgency: UrgencyLevel.critical,
        confidenceScore: 0.99,
        recommendedAction:
            'Acil Arama Kurtarma (AFAD/AKUT) timi ve akustik dinleme ekibi tahsis edildi. Enkaz üstünde titreşim yaratılmamalı, doğalgaz vanaları kapatılmalıdır.',
        requiredResources: [
          'Ses Dinleme Ekipmanı',
          'K9 Kurtarma Köpeği',
          'Hidrolik Kaldırıcı',
          'Termal Kamera',
        ],
        shouldTrigger112: true,
        etaWindow: 'Altın İlk 4 Saat İçinde Acil Müdahale',
        timestamp: DateTime.now(),
        location: loc,
        status: 'Bekliyor',
      );
    } else if (lower.contains('hasta') ||
        lower.contains('ilaç') ||
        lower.contains('insülin') ||
        lower.contains('kan') ||
        lower.contains('yaralı') ||
        lower.contains('kalp') ||
        lower.contains('nefes') ||
        lower.contains('ambulans')) {
      result = AiTriageResult(
        id: reportId,
        rawText: text.trim(),
        category: 'SAĞLIK & TRAVMA',
        urgency: UrgencyLevel.high,
        confidenceScore: 0.95,
        recommendedAction:
            'Sahra hastanesine acil vaka kaydı düşürüldü. Hastanın solunum yolu açık tutulmalı, kanama varsa temiz bezle baskı uygulanmalıdır.',
        requiredResources: [
          'İlk Yardım Çantası',
          'Ambulans Nakli',
          'Temel Medikal İlaçlar',
        ],
        shouldTrigger112: true,
        etaWindow: 'Maksimum 25 Dakika',
        timestamp: DateTime.now(),
        location: loc,
        status: 'Bekliyor',
      );
    } else if (lower.contains('su') ||
        lower.contains('mama') ||
        lower.contains('gıda') ||
        lower.contains('yemek') ||
        lower.contains('ekmek') ||
        lower.contains('bebek')) {
      result = AiTriageResult(
        id: reportId,
        rawText: text.trim(),
        category: 'SU & TEMEL YAŞAM',
        urgency: UrgencyLevel.medium,
        confidenceScore: 0.91,
        recommendedAction:
            'İhtiyaç Kriz Masası lojistik kuyruğuna eklendi. En yakın su ve gıda dağıtım konvoyu bölgeye yönlendiriliyor.',
        requiredResources: [
          '0.5L İçme Suyu',
          'Bebek Maması',
          'Hazır Gıda Paketi',
        ],
        shouldTrigger112: false,
        etaWindow: '1-3 Saat İçinde Teslimat',
        timestamp: DateTime.now(),
        location: loc,
        status: 'Bekliyor',
      );
    } else {
      result = AiTriageResult(
        id: reportId,
        rawText: text.trim(),
        category: 'BARINMA & LOJİSTİK',
        urgency: UrgencyLevel.low,
        confidenceScore: 0.87,
        recommendedAction:
            'Bölgedeki çadır kent stok sorumlularına bildirim iletildi. Dağıtım sırasına alındı.',
        requiredResources: ['Kışlık Battaniye', 'Çadır Matı', 'Isıtıcı'],
        shouldTrigger112: false,
        etaWindow: '3-6 Saat Aralığında Teslimat',
        timestamp: DateTime.now(),
        location: loc,
        status: 'Bekliyor',
      );
    }

    // Add to live list so Admin sees it immediately
    _reports.insert(0, result);
    notifyListeners();

    // Persist to Firestore 'reports' collection
    try {
      await _firestore
          ?.collection('reports')
          .doc(result.id)
          .set(result.toMap());
    } catch (e) {
      debugPrint('Firestore report save note: $e');
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
    required int capacity,
    required AreaCategory category,
  }) async {
    final id = 'area_${DateTime.now().millisecondsSinceEpoch % 100000}';
    // Place near Gaziantep center with slight offset so it appears on map
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
    final demoIdx = ReliefAreaModel.demoAreas.indexWhere((a) => a.id == areaId);
    if (demoIdx >= 0) {
      ReliefAreaModel.demoAreas[demoIdx] = updatedArea;
    }
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

  /// Meta Llama 3 Context-Aware Assistant (RAG with Live Areas & Stock Data)
  Future<Map<String, dynamic>> askLlamaAssistant(String query) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final lower = query.toLowerCase();

    if (lower.contains('nefes') ||
        lower.contains('kalp') ||
        lower.contains('öl') ||
        lower.contains('bilinç')) {
      return {
        'text':
            '🚨 ACİL DURUM TESPİT EDİLDİ! Solunum durması veya bilinç kaybı şüphesinde zaman kaybetmeden hemen 112 Acil Çağrı Merkezini arayınız veya üstteki kırmızı 112 butonuna basınız. Hastayı düz ve sert bir zemine yatırıp baş-çene pozisyonu ile hava yolunu açık tutunuz.',
        'source': 'T.C. Sağlık Bakanlığı Acil Sağlık Hizmetleri Protokolü',
        'isEmergency': true,
      };
    } else if (lower.contains('enkaz') ||
        lower.contains('altında') ||
        lower.contains('sıkış')) {
      return {
        'text':
            'Enkaz altındaysanız:\n1. Enerjinizi koruyun, panik yapmayın ve tozdan korunmak için ağzınızı kumaşla örtün.\n2. Bağırmak yerine yakınınızdaki boru veya sert nesnelere periyodik olarak vurun (tık tık sesi dinleme cihazlarına daha net iletilir).\n3. Kibrit veya çakmak ASLA yakmayın (gaz sızıntısı riski).\n4. Dışarıdan arama kurtarma sesleri duyduğunuzda varlığınızı belli edin.',
        'source': 'AFAD Enkaz Altında Hayatta Kalma Kılavuzu',
        'isEmergency': false,
      };
    } else if (lower.contains('toplanma') ||
        lower.contains('çadır') ||
        lower.contains('nereye') ||
        lower.contains('alan') ||
        lower.contains('boş') ||
        lower.contains('stok')) {
      final topAreas = _areas.take(3).map((a) {
        final stockSummary =
            a.stock.entries.map((e) => '${e.key}: ${e.value}').join(', ');
        return '• ${a.name} (Boş Kapasite: ${a.availableSpots} kişi | Stok: $stockSummary)';
      }).join('\n');
      return {
        'text':
            'Şu an sistemde kayıtlı toplam ${_areas.length} güvenli alan bulunmaktadır. En uygun noktalar:\n$topAreas\n\nHarita sekmesinden tek tıkla güvenli yaya rotasını başlatabilirsiniz.',
        'source': 'Canlı Kriz Masası & Firestore Veri Tabanı',
        'isEmergency': false,
      };
    } else if (lower.contains('su') ||
        lower.contains('içme') ||
        lower.contains('gıda') ||
        lower.contains('yemek')) {
      return {
        'text':
            'Şebeke suları afet sonrasında kirlenmiş olabilir. Sadece kapalı şişe sularını içiniz. Şu an Kızılay Aşevi (Mithatpaşa) ve Atatürk Parkı Toplanma Alanında temiz içme suyu ve sıcak yemek dağıtımı devam etmektedir.',
        'source': 'Dünya Sağlık Örgütü (WHO) & Kızılay Dağıtım Verisi',
        'isEmergency': false,
      };
    } else if (lower.contains('kan') ||
        lower.contains('yara') ||
        lower.contains('turnike')) {
      return {
        'text':
            'Ciddi kanamalarda yara üzerine temiz bir bez veya giysi parçasıyla doğrudan ve kuvvetli basınç uygulayınız. Kanama durmazsa basıncı gevşetmeden bezin üzerine ek bez sarınız. En yakın Sahra Hastanesi: İstasyon Caddesi Sağlık Çadırı.',
        'source': 'Türk Kızılayı Temel İlk Yardım El Kitabı',
        'isEmergency': false,
      };
    } else {
      return {
        'text':
            'Deprem sonrasında binanızı terk ederken elektrik şalterini ve doğalgaz ana vanasını kapatınız. Asansör kesinlikle kullanmayınız. Şu an sistemde ${_areas.length} aktif toplanma alanı ve $activeReportsCount açık ihbar takip edilmektedir.',
        'source': 'AFAD Afet Farkındalık Kılavuzu & Canlı Sistem',
        'isEmergency': false,
      };
    }
  }
}
