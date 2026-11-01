import 'package:afet_destek/services/safety_circle_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores contacts and safety status separately per user', () async {
    final service = SafetyCircleService('citizen-1');
    await service.saveContacts([
      const SafetyCircleContact(
        id: 'contact-1',
        name: 'Ayşe Yılmaz',
        phone: '0555 000 00 00',
      ),
    ]);
    final reportedAt = DateTime(2026, 10, 31, 10);
    await service.saveLatestReport(
      SafetyStatusReport(
        reportedAt: reportedAt,
        placeName: 'Atatürk Parkı',
        latitude: 37.069,
        longitude: 37.378,
        batteryPercent: 72,
      ),
    );
    await service.saveBloodGroup('A Rh+');

    final loadedContacts = await service.loadContacts();
    final loadedReport = await service.loadLatestReport();
    expect(loadedContacts.single.name, 'Ayşe Yılmaz');
    expect(loadedContacts.single.phone, '0555 000 00 00');
    expect(loadedReport?.reportedAt, reportedAt);
    expect(loadedReport?.placeName, 'Atatürk Parkı');
    expect(loadedReport?.batteryPercent, 72);
    expect(await service.loadBloodGroup(), 'A Rh+');

    final otherUser = SafetyCircleService('citizen-2');
    expect(await otherUser.loadContacts(), isEmpty);
    expect(await otherUser.loadLatestReport(), isNull);
    expect(await otherUser.loadBloodGroup(), isNull);
  });

  test('does not allow more than five contacts', () async {
    final service = SafetyCircleService('citizen-1');
    final contacts = List.generate(
      6,
      (index) => SafetyCircleContact(
        id: 'contact-$index',
        name: 'Yakın $index',
        phone: '0555000000$index',
      ),
    );

    await expectLater(service.saveContacts(contacts), throwsArgumentError);
  });
}
