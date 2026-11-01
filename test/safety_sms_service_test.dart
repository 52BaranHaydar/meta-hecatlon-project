import 'package:afet_destek/services/safety_circle_service.dart';
import 'package:afet_destek/services/safety_sms_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SMS includes name, blood group, coordinates, map link and time', () {
    final message = SafetySmsService.composeMessage(
      citizenName: 'Ahmet Yılmaz',
      bloodGroup: 'A Rh+',
      report: SafetyStatusReport(
        reportedAt: DateTime(2026, 10, 31, 12, 30),
        latitude: 37.069,
        longitude: 37.378,
      ),
    );

    expect(message, contains('GÜVENDEYİM'));
    expect(message, contains('Adı: Ahmet Yılmaz'));
    expect(message, contains('Kan grubu: A Rh+'));
    expect(message, contains('37.069000,37.378000'));
    expect(message, contains('https://maps.google.com/?q=37.069000%2C37.378000'));
    expect(message, contains('Saat:'));
  });

  test('SMS says when GPS location was unavailable', () {
    final message = SafetySmsService.composeMessage(
      citizenName: 'Ahmet Yılmaz',
      bloodGroup: null,
      report: SafetyStatusReport(reportedAt: DateTime(2026, 10, 31, 12)),
    );

    expect(message, contains('Kan grubu: Belirtilmedi'));
    expect(message, contains('Konum: GPS konumu alınamadı.'));
  });
}
