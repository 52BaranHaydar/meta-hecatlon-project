import 'package:afet_destek/models/user_model.dart';
import 'package:afet_destek/screens/home/citizen_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('adding a contact disposes dialog controllers safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CitizenHomeScreen(
            user: UserModel(
              uid: 'citizen-test',
              name: 'Test Vatandaş',
              email: 'test@example.com',
              role: UserRole.citizen,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yakın Ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Ayşe Yılmaz');
    await tester.enterText(find.byType(TextFormField).at(1), '05551234567');
    await tester.tap(find.widgetWithText(FilledButton, 'Ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.text('05551234567'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
