import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SafetyCircleContact {
  final String id;
  final String name;
  final String phone;
  final String? inviteCode;

  const SafetyCircleContact({
    required this.id,
    required this.name,
    required this.phone,
    this.inviteCode,
  });

  SafetyCircleContact copyWith({String? inviteCode}) => SafetyCircleContact(
    id: id,
    name: name,
    phone: phone,
    inviteCode: inviteCode ?? this.inviteCode,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'inviteCode': inviteCode,
  };

  factory SafetyCircleContact.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final name = map['name'];
    final phone = map['phone'];
    if (id is! String || name is! String || phone is! String) {
      throw const FormatException('Güvenlik çemberi kaydı geçersiz.');
    }
    final inviteCode = map['inviteCode'];
    if (inviteCode != null && inviteCode is! String) {
      throw const FormatException('Davet kodu geçersiz.');
    }
    return SafetyCircleContact(
      id: id,
      name: name,
      phone: phone,
      inviteCode: inviteCode as String?,
    );
  }
}

enum SafetyStatus { safe, helpRequested }

class SafetyStatusSnapshot {
  final SafetyStatus status;
  final DateTime reportedAt;
  final String? placeName;
  final double? latitude;
  final double? longitude;

  const SafetyStatusSnapshot({
    required this.status,
    required this.reportedAt,
    this.placeName,
    this.latitude,
    this.longitude,
  });

  bool get isReachable =>
      DateTime.now().difference(reportedAt) <= const Duration(minutes: 30);

  factory SafetyStatusSnapshot.fromMap(Map<String, dynamic> map) {
    final rawStatus = map['status'];
    final rawReportedAt = map['reportedAt'];
    if (rawStatus is! String || rawReportedAt is! Timestamp) {
      throw const FormatException('Canlı güvenlik durumu geçersiz.');
    }
    final status = switch (rawStatus) {
      'safe' => SafetyStatus.safe,
      'help_requested' => SafetyStatus.helpRequested,
      _ => throw const FormatException('Canlı güvenlik durumu geçersiz.'),
    };
    final latitude = map['latitude'];
    final longitude = map['longitude'];
    return SafetyStatusSnapshot(
      status: status,
      reportedAt: rawReportedAt.toDate(),
      placeName: map['placeName'] as String?,
      latitude: latitude is num ? latitude.toDouble() : null,
      longitude: longitude is num ? longitude.toDouble() : null,
    );
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

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  bool canUseLiveSharing(String userId) {
    try {
      return FirebaseAuth.instance.currentUser?.uid == userId;
    } catch (_) {
      return false;
    }
  }

  void _requireAuthenticatedUser(String userId) {
    final authenticatedUid = FirebaseAuth.instance.currentUser?.uid;
    if (authenticatedUid == null || authenticatedUid != userId) {
    throw StateError(
      'Canlı güvenlik paylaşımı için gerçek Firebase hesabıyla oturum açın.',
    );
    }
  }

  static String _newInviteCode() {
    final random = Random.secure();
    return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<String> createInvite({
    required String userId,
    required String displayName,
  }) async {
    _requireAuthenticatedUser(userId);
    final code = _newInviteCode();
    await _firestore.collection('safety_circle_invites').doc(code).set({
    'ownerUid': userId,
    'ownerName': displayName,
    'status': 'pending',
    'createdAt': FieldValue.serverTimestamp(),
    'expiresAt': Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 7)),
    ),
    });
    return code;
  }

  Future<String> acceptInvite({
    required String userId,
    required String displayName,
    required String inviteCode,
  }) async {
    _requireAuthenticatedUser(userId);
    final code = inviteCode.trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(code)) {
    throw const FormatException('Davet kodu geçersiz.');
    }

    final inviteRef = _firestore.collection('safety_circle_invites').doc(code);
    final connectionRef = _firestore
      .collection('safety_circle_connections')
      .doc(code);
    return _firestore.runTransaction((transaction) async {
    final inviteSnapshot = await transaction.get(inviteRef);
    if (!inviteSnapshot.exists) {
      throw StateError('Davet bulunamadı veya süresi dolmuş.');
    }

    final invite = inviteSnapshot.data()!;
    final ownerUid = invite['ownerUid'];
    final ownerName = invite['ownerName'];
    final expiresAt = invite['expiresAt'];
    if (invite['status'] != 'pending' ||
        ownerUid is! String ||
        ownerName is! String ||
        expiresAt is! Timestamp ||
        expiresAt.toDate().isBefore(DateTime.now()) ||
        ownerUid == userId) {
      throw StateError('Davet geçersiz, süresi dolmuş veya size ait.');
    }

    transaction.update(inviteRef, {
      'status': 'accepted',
      'acceptedBy': userId,
      'acceptedName': displayName,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
    transaction.set(connectionRef, {
      'participantUids': [ownerUid, userId],
      'participantNames': {ownerUid: ownerName, userId: displayName},
      'inviteCode': code,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ownerName;
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchConnection(
    String inviteCode,
  ) {
    return _firestore
      .collection('safety_circle_connections')
      .doc(inviteCode)
      .snapshots();
  }

  Stream<SafetyStatusSnapshot?> watchContactStatus({
    required String userId,
    required String inviteCode,
  }) {
    return watchConnection(inviteCode).asyncExpand((connection) {
    final data = connection.data();
    final participants = data?['participantUids'];
    if (!connection.exists ||
        participants is! List ||
        !participants.contains(userId)) {
      return Stream<SafetyStatusSnapshot?>.value(null);
    }
    final otherUid = participants.whereType<String>().firstWhere(
      (uid) => uid != userId,
      orElse: () => '',
    );
    if (otherUid.isEmpty) return Stream<SafetyStatusSnapshot?>.value(null);
    return _firestore
        .collection('safety_circle_connections')
        .doc(inviteCode)
        .collection('statuses')
        .doc(otherUid)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          final status = snapshot.data();
          if (status == null) return null;
          return SafetyStatusSnapshot.fromMap(status);
        });
    });
  }

  Future<int> publishStatus({
    required String userId,
    required SafetyStatus status,
    SafetyStatusReport? report,
  }) async {
    _requireAuthenticatedUser(userId);
    final connections = await _firestore
      .collection('safety_circle_connections')
      .where('participantUids', arrayContains: userId)
      .get();
    final batch = _firestore.batch();
    for (final connection in connections.docs) {
    final statusRef = connection.reference
        .collection('statuses')
        .doc(userId);
    batch.set(statusRef, {
      'status': status == SafetyStatus.safe ? 'safe' : 'help_requested',
      'reportedAt': FieldValue.serverTimestamp(),
      if (report?.placeName != null) 'placeName': report!.placeName,
      if (report?.latitude != null) 'latitude': report!.latitude,
      if (report?.longitude != null) 'longitude': report!.longitude,
    });
    }
    if (connections.docs.isNotEmpty) await batch.commit();
    return connections.docs.length;
  }

  Future<void> removeConnection({
    required String userId,
    required String inviteCode,
  }) async {
    _requireAuthenticatedUser(userId);
    final code = inviteCode.trim().toLowerCase();
    final connectionRef = _firestore
        .collection('safety_circle_connections')
        .doc(code);
    final connection = await connectionRef.get();
    if (!connection.exists) {
      final inviteRef = _firestore.collection('safety_circle_invites').doc(code);
      final invite = await inviteRef.get();
      if (invite.data()?['ownerUid'] == userId &&
          invite.data()?['status'] == 'pending') {
        await inviteRef.update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      }
      return;
    }

    final participants = connection.data()?['participantUids'];
    if (participants is! List || !participants.contains(userId)) {
      throw StateError('Güvenlik ağı bağlantısı size ait değil.');
    }
    final batch = _firestore.batch();
    for (final participant in participants.whereType<String>()) {
      batch.delete(connectionRef.collection('statuses').doc(participant));
    }
    batch.delete(connectionRef);
    await batch.commit();
  }

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
