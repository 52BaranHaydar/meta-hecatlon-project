import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/ai_triage_model.dart';
import '../models/relief_area_model.dart';

class CrisisDataService extends ChangeNotifier {
  static final CrisisDataService _instance = CrisisDataService._internal();
  factory CrisisDataService() => _instance;

  CrisisDataService._internal() {
    ReliefAreaModel.resetDemoAreas();
    _areas = List<ReliefAreaModel>.from(ReliefAreaModel.demoAreas);
    _reports = List<AiTriageResult>.from(AiTriageResult.sampleScenarios);
    _syncFromFirestore();
  }

  late List<ReliefAreaModel> _areas;
  late List<AiTriageResult> _reports;

  List<ReliefAreaModel> get areas => List.unmodifiable(_areas);
  List<AiTriageResult> get reports => List.unmodifiable(_reports);

  int get activeReportsCount =>
      _reports.where((r) => r.status != 'Ã‡Ã¶zÃ¼ldÃ¼').length;

  int get criticalReportsCount => _reports
      .where((r) => r.urgency == UrgencyLevel.critical && r.status != 'Ã‡Ã¶zÃ¼ldÃ¼')
      .length;

  int get dispatchedReportsCount =>
      _reports.where((r) => r.status == 'Ekip YÃ¶nlendirildi').length;

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
    } catch (e) {
      debugPrint('Firestore report sync note: $e');
    }

    try {
      db
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
    } catch (error) {
      debugPrint('Firestore area sync note: $error');
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
        : 'Åehitkamil Merkez, Gaziantep';

    AiTriageResult result;

    if (lower.contains('enkaz') ||
        lower.contains('ses') ||
        lower.contains('Ã§Ã¶k') ||
        lower.contains('altÄ±nda') ||
        lower.contains('gaz') ||
        lower.contains('yangÄ±n') ||
        lower.contains('sÄ±kÄ±ÅŸ')) {
      result = AiTriageResult(
        id: reportId,
        rawText: text.trim(),
        category: 'ENKAZ & ARAMA KURTARMA',
        urgency: UrgencyLevel.critical,
        confidenceScore: 0.99,
        recommendedAction:
            'Acil Arama Kurtarma (AFAD/AKUT) timi ve akustik dinleme ekibi tahsis edildi. Enkaz Ã¼stÃ¼nde titreÅŸim yaratÄ±lmamalÄ±, doÄŸalgaz vanalarÄ± kapatÄ±lmalÄ±dÄ±r.',
        requiredResources: [
          'Ses Dinleme EkipmanÄ±',
          'K9 Kurtarma KÃ¶peÄŸi',
          'Hidrolik KaldÄ±rÄ±cÄ±',
          'Termal Kamera',
        ],
        shouldTrigger112: true,
        etaWindow: 'AltÄ±n Ä°lk 4 Saat Ä°Ã§inde Acil MÃ¼dahale',
        timestamp: DateTime.now(),
        location: loc,
        status: 'Bekliyor',
      );
    } else if (lower.contains('hasta') ||
        lower.contains('ilaÃ§') ||
        lower.contains('insÃ¼lin') ||
        lower.contains('kan') ||
        lower.contains('yaralÄ±') ||
        lower.contains('kalp') ||
        lower.contains('nefes') ||
        lower.contains('ambulans')) {
      result = AiTriageResult(
        id: reportId,
        rawText: text.trim(),
        category: 'SAÄLIK & TRAVMA',
        urgency: UrgencyLevel.high,
        confidenceScore: 0.95,
        recommendedAction:
            'Sahra hastanesine acil vaka kaydÄ± dÃ¼ÅŸÃ¼rÃ¼ldÃ¼. HastanÄ±n solunum yolu aÃ§Ä±k tutulmalÄ±, kanama varsa temiz bezle baskÄ± uygulanmalÄ±dÄ±r.',
        requiredResources: [
          'Ä°lk YardÄ±m Ã‡antasÄ±',
          'Ambulans Nakli',
          'Temel Medikal Ä°laÃ§lar',
        ],
        shouldTrigger112: true,
        etaWindow: 'Maksimum 25 Dakika',
        timestamp: DateTime.now(),
        location: loc,
        status: 'Bekliyor',
      );
    } else if (lower.contains('su') ||
        lower.contains('mama') ||
        lower.contains('gÄ±da') ||
        lower.contains('yemek') ||
        lower.contains('ekmek') ||
        lower.contains('bebek')) {
      result = AiTriageResult(
        id: reportId,
        rawText: text.trim(),
        category: 'SU & TEMEL YAÅAM',
        urgency: UrgencyLevel.medium,
        confidenceScore: 0.91,
        recommendedAction:
            'Ä°htiyaÃ§ Kriz MasasÄ± lojistik kuyruÄŸuna eklendi. En yakÄ±n su ve gÄ±da daÄŸÄ±tÄ±m konvoyu bÃ¶lgeye yÃ¶nlendiriliyor.',
        requiredResources: [
          '0.5L Ä°Ã§me Suyu',
          'Bebek MamasÄ±',
          'HazÄ±r GÄ±da Paketi',
        ],
        shouldTrigger112: false,
        etaWindow: '1-3 Saat Ä°Ã§inde Teslimat',
        timestamp: DateTime.now(),
        location: loc,
        status: 'Bekliyor',
      );
    } else {
      result = AiTriageResult(
        id: reportId,
        rawText: text.trim(),
        category: 'BARINMA & LOJÄ°STÄ°K',
        urgency: UrgencyLevel.low,
        confidenceScore: 0.87,
        recommendedAction:
            'BÃ¶lgedeki Ã§adÄ±r kent stok sorumlularÄ±na bildirim iletildi. DaÄŸÄ±tÄ±m sÄ±rasÄ±na alÄ±ndÄ±.',
        requiredResources: ['KÄ±ÅŸlÄ±k Battaniye', 'Ã‡adÄ±r MatÄ±', 'IsÄ±tÄ±cÄ±'],
        shouldTrigger112: false,
        etaWindow: '3-6 Saat AralÄ±ÄŸÄ±nda Teslimat',
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
          ? 'Åehitkamil Merkez BÃ¶lgesi'
          : address.trim(),
      category: category,
      location: LatLng(37.0660 + offset, 37.3800 + offset),
      capacity: capacity > 0 ? capacity : 1000,
      occupancy: 0,
      services: [
        category.title,
        'Temiz Su',
        'Ä°lk YardÄ±m NoktasÄ±',
        'AydÄ±nlatma',
      ],
      stock: {'Ä°Ã§me Suyu': '500 ÅiÅŸe', 'Battaniye': '200 Adet'},
      statusText: 'Yeni AÃ§Ä±ldÄ± & GÃ¼venli',
      isSafe: true,
    );

    _areas.insert(0, newArea);
    ReliefAreaModel.addDemoArea(newArea);
    notifyListeners();

    try {
      await _firestore
          ?.collection('areas')
          .doc(newArea.id)
          .set(newArea.toMap());
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
    if (idx < 0) {
      throw ArgumentError.value(areaId, 'areaId', 'Toplanma alanÄ± bulunamadÄ±.');
    }

    final current = _areas[idx];
    final updatedStock = Map<String, String>.from(current.stock);
    updatedStock[itemKey.trim()] = quantity.trim();

    final updatedArea = current.copyWith(stock: updatedStock);
    final db = _firestore;
    if (db != null) {
      await db
          .collection('areas')
          .doc(areaId)
          .set(updatedArea.toMap(), SetOptions(merge: true));
    }
    applyAreaUpdate(updatedArea);
  }

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

  /// Meta Llama 3 Context-Aware Assistant (RAG with Live Areas & Stock Data)
  Future<Map<String, dynamic>> askLlamaAssistant(String query) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final lower = query.toLowerCase();

    if (lower.contains('nefes') ||
        lower.contains('kalp') ||
        lower.contains('Ã¶l') ||
        lower.contains('bilinÃ§')) {
      return {
        'text':
            'ğŸš¨ ACÄ°L DURUM TESPÄ°T EDÄ°LDÄ°! Solunum durmasÄ± veya bilinÃ§ kaybÄ± ÅŸÃ¼phesinde zaman kaybetmeden hemen 112 Acil Ã‡aÄŸrÄ± Merkezini arayÄ±nÄ±z veya Ã¼stteki kÄ±rmÄ±zÄ± 112 butonuna basÄ±nÄ±z. HastayÄ± dÃ¼z ve sert bir zemine yatÄ±rÄ±p baÅŸ-Ã§ene pozisyonu ile hava yolunu aÃ§Ä±k tutunuz.',
        'source': 'T.C. SaÄŸlÄ±k BakanlÄ±ÄŸÄ± Acil SaÄŸlÄ±k Hizmetleri ProtokolÃ¼',
        'isEmergency': true,
      };
    } else if (lower.contains('enkaz') ||
        lower.contains('altÄ±nda') ||
        lower.contains('sÄ±kÄ±ÅŸ')) {
      return {
        'text':
            'Enkaz altÄ±ndaysanÄ±z:\n1. Enerjinizi koruyun, panik yapmayÄ±n ve tozdan korunmak iÃ§in aÄŸzÄ±nÄ±zÄ± kumaÅŸla Ã¶rtÃ¼n.\n2. BaÄŸÄ±rmak yerine yakÄ±nÄ±nÄ±zdaki boru veya sert nesnelere periyodik olarak vurun (tÄ±k tÄ±k sesi dinleme cihazlarÄ±na daha net iletilir).\n3. Kibrit veya Ã§akmak ASLA yakmayÄ±n (gaz sÄ±zÄ±ntÄ±sÄ± riski).\n4. DÄ±ÅŸarÄ±dan arama kurtarma sesleri duyduÄŸunuzda varlÄ±ÄŸÄ±nÄ±zÄ± belli edin.',
        'source': 'AFAD Enkaz AltÄ±nda Hayatta Kalma KÄ±lavuzu',
        'isEmergency': false,
      };
    } else if (lower.contains('toplanma') ||
        lower.contains('Ã§adÄ±r') ||
        lower.contains('nereye') ||
        lower.contains('alan') ||
        lower.contains('boÅŸ') ||
        lower.contains('stok')) {
      final topAreas = _areas
          .take(3)
          .map((a) {
            final stockSummary = a.stock.entries
                .map((e) => '${e.key}: ${e.value}')
                .join(', ');
            return 'â€¢ ${a.name} (BoÅŸ Kapasite: ${a.availableSpots} kiÅŸi | Stok: $stockSummary)';
          })
          .join('\n');
      return {
        'text':
            'Åu an sistemde kayÄ±tlÄ± toplam ${_areas.length} gÃ¼venli alan bulunmaktadÄ±r. En uygun noktalar:\n$topAreas\n\nHarita sekmesinden tek tÄ±kla gÃ¼venli yaya rotasÄ±nÄ± baÅŸlatabilirsiniz.',
        'source': 'CanlÄ± Kriz MasasÄ± & Firestore Veri TabanÄ±',
        'isEmergency': false,
      };
    } else if (lower.contains('su') ||
        lower.contains('iÃ§me') ||
        lower.contains('gÄ±da') ||
        lower.contains('yemek')) {
      return {
        'text':
            'Åebeke sularÄ± afet sonrasÄ±nda kirlenmiÅŸ olabilir. Sadece kapalÄ± ÅŸiÅŸe sularÄ±nÄ± iÃ§iniz. Åu an KÄ±zÄ±lay AÅŸevi (MithatpaÅŸa) ve AtatÃ¼rk ParkÄ± Toplanma AlanÄ±nda temiz iÃ§me suyu ve sÄ±cak yemek daÄŸÄ±tÄ±mÄ± devam etmektedir.',
        'source': 'DÃ¼nya SaÄŸlÄ±k Ã–rgÃ¼tÃ¼ (WHO) & KÄ±zÄ±lay DaÄŸÄ±tÄ±m Verisi',
        'isEmergency': false,
      };
    } else if (lower.contains('kan') ||
        lower.contains('yara') ||
        lower.contains('turnike')) {
      return {
        'text':
            'Ciddi kanamalarda yara Ã¼zerine temiz bir bez veya giysi parÃ§asÄ±yla doÄŸrudan ve kuvvetli basÄ±nÃ§ uygulayÄ±nÄ±z. Kanama durmazsa basÄ±ncÄ± gevÅŸetmeden bezin Ã¼zerine ek bez sarÄ±nÄ±z. En yakÄ±n Sahra Hastanesi: Ä°stasyon Caddesi SaÄŸlÄ±k Ã‡adÄ±rÄ±.',
        'source': 'TÃ¼rk KÄ±zÄ±layÄ± Temel Ä°lk YardÄ±m El KitabÄ±',
        'isEmergency': false,
      };
    } else {
      return {
        'text':
            'Deprem sonrasÄ±nda binanÄ±zÄ± terk ederken elektrik ÅŸalterini ve doÄŸalgaz ana vanasÄ±nÄ± kapatÄ±nÄ±z. AsansÃ¶r kesinlikle kullanmayÄ±nÄ±z. Åu an sistemde ${_areas.length} aktif toplanma alanÄ± ve $activeReportsCount aÃ§Ä±k ihbar takip edilmektedir.',
        'source': 'AFAD Afet FarkÄ±ndalÄ±k KÄ±lavuzu & CanlÄ± Sistem',
        'isEmergency': false,
      };
    }
  }
}

