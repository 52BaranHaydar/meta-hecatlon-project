import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'safety_circle_service.dart';

class SafetySmsDraft {
  final String id;
  final String message;
  final DateTime createdAt;
  final String? recipientName;
  final String? recipientPhone;

  const SafetySmsDraft({
    required this.id,
    required this.message,
    required this.createdAt,
    this.recipientName,
    this.recipientPhone,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'message': message,
    'createdAt': createdAt.toIso8601String(),
    'recipientName': recipientName,
    'recipientPhone': recipientPhone,
  };

  factory SafetySmsDraft.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final message = map['message'];
    final createdAt = map['createdAt'];
    final recipientName = map['recipientName'];
    final recipientPhone = map['recipientPhone'];
    if (id is! String ||
        message is! String ||
        createdAt is! String ||
        DateTime.tryParse(createdAt) == null ||
        (recipientName != null && recipientName is! String) ||
        (recipientPhone != null && recipientPhone is! String)) {
      throw const FormatException('SMS kuyruğu kaydı geçersiz.');
    }
    return SafetySmsDraft(
      id: id,
      message: message,
      createdAt: DateTime.parse(createdAt),
      recipientName: recipientName as String?,
      recipientPhone: recipientPhone as String?,
    );
  }
}

class SafetySmsService {
  static const emergencySmsTarget = String.fromEnvironment(
    'AFAD_SMS_TARGET',
    defaultValue: '',
  );

  static String _queueKey(String userId) =>
      'safety_sms_queue_${Uri.encodeComponent(userId)}';

  static String composeMessage({
    required String citizenName,
    required String? bloodGroup,
    required SafetyStatusReport report,
  }) {
    final lines = <String>[
      'GÜVENDEYİM',
      'Adı: $citizenName',
      'Kan grubu: ${bloodGroup ?? 'Belirtilmedi'}',
    ];

    final latitude = report.latitude;
    final longitude = report.longitude;
    if (latitude != null && longitude != null) {
      final coordinates =
          '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
      final mapsUrl = Uri.https(
        'maps.google.com',
        '/',
        {'q': coordinates},
      );
      lines
        ..add('Konum: $mapsUrl')
        ..add('Koordinatlar: $coordinates');
    } else {
      lines.add('Konum: GPS konumu alınamadı.');
    }

    lines.add('Saat: ${report.reportedAt.toLocal().toString()}');
    return lines.join('\n');
  }

  static String composeEmergencyMessage({
    required String citizenName,
    required String reportText,
    required String location,
    SafetyStatusReport? report,
  }) {
    final lines = <String>[
      'ACİL YARDIM İSTİYORUM',
      'Adı: $citizenName',
      'İhbar: ${reportText.trim()}',
      'Adres: ${location.trim().isEmpty ? 'Belirtilmedi' : location.trim()}',
    ];
    if (report?.latitude != null && report?.longitude != null) {
      final coordinates =
          '${report!.latitude!.toStringAsFixed(6)},${report.longitude!.toStringAsFixed(6)}';
      lines.add('Koordinatlar: $coordinates');
    }
    lines.add('Saat: ${DateTime.now().toLocal()}');
    return lines.join('\n');
  }

  static String composeInviteMessage({
    required String inviterName,
    required String inviteCode,
  }) {
    return '$inviterName sizi Afet Destek güvenlik ağına davet ediyor. '
        'Uygulamada "Davet Kodunu Kabul Et" bölümüne şu tek kullanımlık kodu girin: '
        '$inviteCode. Kod 7 gün geçerlidir.';
  }

  static Future<List<SafetySmsDraft>> loadQueue(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_queueKey(userId));
    if (encoded == null) return [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('SMS kuyruğu geçersiz.');
    }
    return decoded.map((entry) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('SMS kuyruğu kaydı geçersiz.');
      }
      return SafetySmsDraft.fromMap(entry);
    }).toList();
  }

  static Future<SafetySmsDraft> queueEmergencyMessage({
    required String userId,
    required String message,
  }) async {
    final queue = await loadQueue(userId);
    final draft = SafetySmsDraft(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      message: message,
      createdAt: DateTime.now(),
    );
    queue.insert(0, draft);
    await _saveQueue(userId, queue);
    return draft;
  }

  static Future<void> removeFromQueue({
    required String userId,
    required String draftId,
  }) async {
    final queue = await loadQueue(userId);
    queue.removeWhere((draft) => draft.id == draftId);
    await _saveQueue(userId, queue);
  }

  static Future<void> _saveQueue(
    String userId,
    List<SafetySmsDraft> queue,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _queueKey(userId),
      jsonEncode(queue.map((draft) => draft.toMap()).toList()),
    );
    if (!saved) throw StateError('SMS kuyruğu bu cihaza kaydedilemedi.');
  }

  static Future<bool> openDraft({
    required SafetyCircleContact contact,
    required String message,
  }) {
    return openDraftToNumber(phone: contact.phone, message: message);
  }

  static Future<bool> openDraftToNumber({
    required String phone,
    required String message,
  }) {
    final smsUri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );
    return launchUrl(smsUri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> openQueuedDraft(SafetySmsDraft draft) {
    return openDraftToNumber(
      phone: draft.recipientPhone ?? emergencySmsTarget,
      message: draft.message,
    );
  }
}
