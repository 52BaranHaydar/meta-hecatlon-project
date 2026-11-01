import 'package:url_launcher/url_launcher.dart';

import 'safety_circle_service.dart';

class SafetySmsService {
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

  static Future<bool> openDraft({
    required SafetyCircleContact contact,
    required String message,
  }) {
    final smsUri = Uri(
      scheme: 'sms',
      path: contact.phone,
      queryParameters: {'body': message},
    );
    return launchUrl(smsUri, mode: LaunchMode.externalApplication);
  }
}
