import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants/meta_ai_config.dart';
import '../models/ai_triage_model.dart';
import '../models/relief_area_model.dart';

class MetaAiService {
  static final MetaAiService _instance = MetaAiService._internal();
  factory MetaAiService() => _instance;
  MetaAiService._internal();

  static const String _endpoint = 'https://api.meta.ai/v1/chat/completions';
  static const String _model = 'muse-spark-1.3';

  /// Sends a live chat query to Meta's Model API
  Future<String?> generateReply({
    required String prompt,
    String? systemInstruction,
    int maxTokens = 1200,
  }) async {
    final key = MetaAiConfig.apiKey.trim();
    if (key.isEmpty) return null;

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      final uri = Uri.parse(_endpoint);
      final request = await client.postUrl(uri);

      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
      request.headers.set(HttpHeaders.userAgentHeader, 'AfetDestek-App/1.0');

      final messages = <Map<String, String>>[];
      if (systemInstruction != null && systemInstruction.isNotEmpty) {
        messages.add({'role': 'system', 'content': systemInstruction});
      }
      messages.add({'role': 'user', 'content': prompt});

      final payload = jsonEncode({
        'model': _model,
        'messages': messages,
        'max_tokens': maxTokens,
      });

      request.write(payload);
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final msg = choices[0]['message'] as Map<String, dynamic>?;
          final content = msg?['content'] as String?;
          if (content != null && content.trim().isNotEmpty) {
            return content.trim();
          }
        }
      } else {
        debugPrint('Meta AI error: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Meta AI live request exception: $e');
    } finally {
      client?.close();
    }
    return null;
  }

  /// Live Meta AI Assistant query with disaster RAG context
  Future<Map<String, dynamic>> askAssistant(
    String query, {
    required List<ReliefAreaModel> liveAreas,
  }) async {
    final areaSummary = liveAreas.take(3).map((a) {
      final stockStr = a.stock.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      return '- ${a.name} (Boş Kapasite: ${a.availableSpots} kişi | Stok: $stockStr)';
    }).join('\n');

    final systemInstruction = '''Sen AFAD ve Kızılay kılavuzlarına bağlı resmi "Meta AI Afet ve İlk Yardım Asistanı"sın.
Kullanıcının sorusuna doğrudan, nazik ve hayat kurtarıcı bir dille Türkçe yanıt ver.
Eğer soru toplanma alanı veya stokla ilgiliyse şu anki canlı sistem verilerini kullan:
$areaSummary
Eğer durum hayati tehlike veya acil tıbbi müdahale içeriyorsa 112 Acil Çağrı Merkezi'ne başvurulması gerektiğini vurgula.
Gereksiz uzun açıklamalar yapma, net ve anlaşılır ol.''';

    final liveResponse = await generateReply(
      prompt: query,
      systemInstruction: systemInstruction,
      maxTokens: 1200,
    );

    if (liveResponse != null && liveResponse.isNotEmpty) {
      final isEmergency = query.toLowerCase().contains('nefes') ||
          query.toLowerCase().contains('kalp') ||
          query.toLowerCase().contains('kanama') ||
          query.toLowerCase().contains('öl');
      return {
        'text': liveResponse,
        'source': 'Meta AI Canlı Motoru (${MetaAiConfig.maskedKey})',
        'isEmergency': isEmergency,
      };
    }

    // Fallback to local intelligent rules if offline or API limit reached
    return _localAssistantFallback(query, liveAreas);
  }

  /// Live Meta AI Triage Classification
  Future<AiTriageResult?> classifyWithMetaAi(
    String text, {
    String? location,
    String? citizenName,
    String? citizenEmail,
    String? citizenPhone,
    double? latitude,
    double? longitude,
  }) async {
    final prompt = '''Aşağıdaki afetzede ihbar metnini acil yardım triyajı için analiz et ve SADECE aşağıdaki JSON formatında yanıt ver, başka hiçbir metin ekleme:
Metin: "$text"

JSON Şeması:
{
  "category": "ENKAZ & ARAMA KURTARMA" | "ACİL SAĞLIK & MEDİKAL" | "SU, GIDA & BEBEK İHTİYACI" | "BARINMA & ISINMA" | "GENEL DESTEK & LOJİSTİK",
  "urgency": "KRİTİK" | "YÜKSEK" | "ORTA" | "DÜŞÜK",
  "confidenceScore": 0.98,
  "recommendedAction": "AFAD ve kurtarma ekipleri için 1 cümlelik eylem protokolü",
  "requiredResources": ["Ekipman 1", "Ekipman 2", "Ekipman 3"],
  "shouldTrigger112": true veya false,
  "etaWindow": "Örn: İlk 4 Saat veya 30 Dakika"
}''';

    final liveResponse = await generateReply(
      prompt: prompt,
      systemInstruction: 'Sen AFAD Kriz Masası için çalışan uzman afet triyaj yapay zekasısın. Sadece saf JSON üret.',
      maxTokens: 1200,
    );

    if (liveResponse != null && liveResponse.isNotEmpty) {
      try {
        final cleanJson = liveResponse
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final startIdx = cleanJson.indexOf('{');
        final endIdx = cleanJson.lastIndexOf('}');
        if (startIdx >= 0 && endIdx > startIdx) {
          final jsonStr = cleanJson.substring(startIdx, endIdx + 1);
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;

          final reportId = 'AI-TR-${DateTime.now().millisecondsSinceEpoch % 100000}';
          final loc = (location != null && location.trim().isNotEmpty)
              ? location.trim()
              : 'Şehitkamil Merkez, Gaziantep';

          return AiTriageResult(
            id: reportId,
            rawText: text.trim(),
            category: map['category'] ?? 'GENEL DESTEK',
            urgency: UrgencyLevel.fromString(map['urgency']?.toString()),
            confidenceScore: (map['confidenceScore'] as num?)?.toDouble() ?? 0.95,
            modelName: 'Meta-Llama (${MetaAiConfig.maskedKey})',
            recommendedAction: map['recommendedAction'] ?? 'Kriz Masası incelemesine alındı.',
            requiredResources: (map['requiredResources'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                ['İlk Yardım Kiti', 'Temel İhtiyaç'],
            shouldTrigger112: map['shouldTrigger112'] == true,
            etaWindow: map['etaWindow'] ?? '1-2 Saat',
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
      } catch (e) {
        debugPrint('Meta AI JSON parse error: $e');
      }
    }
    return null;
  }

  Map<String, dynamic> _localAssistantFallback(
    String query,
    List<ReliefAreaModel> areas,
  ) {
    final lower = query.toLowerCase().trim();

    if (lower == 'selam' || lower == 'merhaba' || lower.startsWith('selam') || lower.startsWith('merhaba')) {
      return {
        'text':
            'Merhaba! Ben Meta AI Afet ve İlk Yardım Asistanıyım. AFAD kılavuzları ve Kriz Masası veritabanına bağlıyım. Deprem anı, ilk yardım, güvenli toplanma alanları ve canlı ihtiyaç stokları hakkında bana dilediğinizi sorabilirsiniz.',
        'source': 'Meta AI (${MetaAiConfig.maskedKey}) • Canlı Bilgi Tabanı',
        'isEmergency': false,
      };
    } else if (lower.contains('nefes') ||
        lower.contains('kalp') ||
        lower.contains('öl') ||
        lower.contains('bilinç')) {
      return {
        'text':
            '🚨 ACİL DURUM TESPİT EDİLDİ! Solunum durması veya bilinç kaybı şüphesinde zaman kaybetmeden hemen 112 Acil Çağrı Merkezini arayınız veya üstteki kırmızı 112 butonuna basınız. Hastayı düz ve sert bir zemine yatırıp baş-çene pozisyonu ile hava yolunu açık tutunuz.',
        'source': 'T.C. Sağlık Bakanlığı Acil Sağlık Protokolü',
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
      final topAreas = areas.take(3).map((a) {
        final stockSummary =
            a.stock.entries.map((e) => '${e.key}: ${e.value}').join(', ');
        return '• ${a.name} (Boş Kapasite: ${a.availableSpots} kişi | Stok: $stockSummary)';
      }).join('\n');

      return {
        'text':
            'Bölgenizdeki güncel toplanma alanları ve AFAD stok durumu:\n$topAreas\n\nHarita sekmesinden bu noktalara güvenli rota çizebilirsiniz.',
        'source': 'AFAD & Kriz Masası Canlı Veritabanı',
        'isEmergency': false,
      };
    } else {
      return {
        'text':
            'Deprem ve afet sonrasında binanızı terk ederken elektrik şalterini ve doğalgaz ana vanasını kapatınız. Asansör kesinlikle kullanmayınız. Şu an sistemde ${areas.length} aktif toplanma alanı ve açık ihbarlar takip edilmektedir.',
        'source': 'AFAD Afet Farkındalık Kılavuzu & Canlı Sistem',
        'isEmergency': false,
      };
    }
  }
}

