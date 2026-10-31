import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SafetyCircleContact {
  final String id;
  final String name;
  final String phone;

  const SafetyCircleContact({
    required this.id,
    required this.name,
    required this.phone,
  });

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'phone': phone};

  factory SafetyCircleContact.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final name = map['name'];
    final phone = map['phone'];
    if (id is! String || name is! String || phone is! String) {
      throw const FormatException('Güvenlik çemberi kaydı geçersiz.');
    }
    return SafetyCircleContact(id: id, name: name, phone: phone);
  }
}

class SafetyStatusReport {
  final DateTime reportedAt;
  final String? placeName;
  final double? latitude;
  final double? longitude;
  final int? batteryPercent;

  const SafetyStatusReport({
    required this.reportedAt,
    this.placeName,
    this.latitude,
    this.longitude,
    this.batteryPercent,
  });

  String get timeAgo {
    final elapsed = DateTime.now().difference(reportedAt);
    if (elapsed.inMinutes < 1) return 'Az önce';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} dk önce';
    if (elapsed.inDays < 1) return '${elapsed.inHours} sa önce';
    return '${elapsed.inDays} gün önce';
  }

  Map<String, dynamic> toMap() => {
    'reportedAt': reportedAt.toIso8601String(),
    'placeName': placeName,
    'latitude': latitude,
    'longitude': longitude,
    'batteryPercent': batteryPercent,
  };

  factory SafetyStatusReport.fromMap(Map<String, dynamic> map) {
    final rawReportedAt = map['reportedAt'];
    if (rawReportedAt is! String) {
      throw const FormatException('Güvende bildiriminin tarihi geçersiz.');
    }
    final reportedAt = DateTime.tryParse(rawReportedAt);
    if (reportedAt == null) {
      throw const FormatException('Güvende bildiriminin tarihi geçersiz.');
    }

    final latitude = map['latitude'];
    final longitude = map['longitude'];
    final batteryPercent = map['batteryPercent'];
    return SafetyStatusReport(
      reportedAt: reportedAt,
      placeName: map['placeName'] as String?,
      latitude: latitude is num ? latitude.toDouble() : null,
      longitude: longitude is num ? longitude.toDouble() : null,
      batteryPercent: batteryPercent is int ? batteryPercent : null,
    );
  }
}

class SafetyCircleService {
  static const int maxContacts = 5;
  static const List<String> bloodGroups = [
    '0 Rh+',
    '0 Rh-',
    'A Rh+',
    'A Rh-',
    'B Rh+',
    'B Rh-',
    'AB Rh+',
    'AB Rh-',
  ];

  final String _storagePrefix;

  SafetyCircleService(String userId)
    : _storagePrefix = 'safety_circle_${Uri.encodeComponent(userId)}';

  Future<List<SafetyCircleContact>> loadContacts() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString('${_storagePrefix}_contacts');
    if (encoded == null) return [];

    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('Kayıtlı yakınlar listesi geçersiz.');
    }
    return decoded.map((entry) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Kayıtlı yakın bilgisi geçersiz.');
      }
      return SafetyCircleContact.fromMap(entry);
    }).toList();
  }

  Future<void> saveContacts(List<SafetyCircleContact> contacts) async {
    if (contacts.length > maxContacts) {
      throw ArgumentError.value(
        contacts.length,
        'contacts',
        'En fazla $maxContacts yakın eklenebilir.',
      );
    }
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      '${_storagePrefix}_contacts',
      jsonEncode(contacts.map((contact) => contact.toMap()).toList()),
    );
    if (!saved) {
      throw StateError('Yakınlar bu cihaza kaydedilemedi.');
    }
  }

  Future<String?> loadBloodGroup() async {
    final preferences = await SharedPreferences.getInstance();
    final bloodGroup = preferences.getString('${_storagePrefix}_blood_group');
    if (bloodGroup != null && !bloodGroups.contains(bloodGroup)) {
      throw const FormatException('Kayıtlı kan grubu geçersiz.');
    }
    return bloodGroup;
  }

  Future<void> saveBloodGroup(String bloodGroup) async {
    if (!bloodGroups.contains(bloodGroup)) {
      throw ArgumentError.value(bloodGroup, 'bloodGroup', 'Geçersiz kan grubu.');
    }
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      '${_storagePrefix}_blood_group',
      bloodGroup,
    );
    if (!saved) {
      throw StateError('Kan grubu bu cihaza kaydedilemedi.');
    }
  }

  Future<SafetyStatusReport?> loadLatestReport() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString('${_storagePrefix}_latest_report');
    if (encoded == null) return null;

    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Kayıtlı güvenlik bildirimi geçersiz.');
    }
    return SafetyStatusReport.fromMap(decoded);
  }

  Future<void> saveLatestReport(SafetyStatusReport report) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      '${_storagePrefix}_latest_report',
      jsonEncode(report.toMap()),
    );
    if (!saved) {
      throw StateError('Güvende bildirimi bu cihaza kaydedilemedi.');
    }
  }
}
