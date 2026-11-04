import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:afet_destek/main.dart';
import 'package:afet_destek/models/user_model.dart';
import 'package:afet_destek/screens/ai/ai_assistant_screen.dart';
import 'package:afet_destek/screens/ai/ai_triage_screen.dart';
import 'package:afet_destek/services/auth_service.dart';
import 'package:afet_destek/services/language_service.dart';
import 'package:afet_destek/widgets/emergency_112_button.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LanguageService.instance.setLanguage(AppLanguage.en);
  });

  testWidgets('Afet Destek smoke test (English default)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AfetDestekApp());
    expect(find.text('DISASTER RELIEF'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
  });

  testWidgets(
    'language toggle switches interface between English and Turkish',
    (WidgetTester tester) async {
      await tester.pumpWidget(const AfetDestekApp());
      expect(find.text('DISASTER RELIEF'), findsOneWidget);

      await LanguageService.instance.setLanguage(AppLanguage.tr);
      await tester.pumpAndSettle();
      expect(find.text('AFET DESTEK'), findsOneWidget);
      expect(find.text('Giriş Yap'), findsWidgets);
    },
  );

  test('email role resolution enforces Firebase role rules', () {
    expect(
      AuthService.resolveRoleForEmail('vatandas@ornek.com', UserRole.citizen),
      UserRole.citizen,
    );
    expect(
      AuthService.resolveRoleForEmail('lojistik@ornek.com', UserRole.carrier),
      UserRole.carrier,
    );
    expect(
      AuthService.resolveRoleForEmail('vatandas@ornek.com', UserRole.admin),
      UserRole.citizen,
    );
    expect(
      AuthService.resolveRoleForEmail(
        'baranhaydar80@gmail.com',
        UserRole.citizen,
      ),
      UserRole.admin,
    );
  });

  testWidgets('role changes open the matching role home tab', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    addTearDown(authService.logout);
    LanguageService.instance.setLanguage(AppLanguage.tr);
    authService.switchDemoRole(UserRole.citizen);

    await tester.pumpWidget(const AfetDestekApp());
    await tester.pump();
    expect(find.text('Vatandaş Ana Sayfa'), findsOneWidget);
    expect(find.text('Yakın Toplanma Alanları'), findsOneWidget);

    authService.switchDemoRole(UserRole.carrier);
    await tester.pump();
    expect(find.text('Lojistik Paneli'), findsOneWidget);
    expect(find.text('Meta AI Önerilen Rota'), findsOneWidget);

    authService.switchDemoRole(UserRole.admin);
    await tester.pump();
    expect(find.text('Kriz Yönetimi'), findsOneWidget);
    expect(find.text('Gelen Yardım İhbarları (Meta AI)'), findsOneWidget);
  });

  testWidgets('citizen and carrier home screens localize in English', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    addTearDown(authService.logout);
    LanguageService.instance.setLanguage(AppLanguage.en);
    authService.switchDemoRole(UserRole.citizen);

    await tester.pumpWidget(const AfetDestekApp());
    await tester.pump();

    expect(find.text('Citizen Portal'), findsOneWidget);
    expect(find.text('REQUEST HELP'), findsOneWidget);
    expect(find.text('Nearby Relief Areas'), findsOneWidget);
    expect(find.text('Is My Family Safe?'), findsOneWidget);
    expect(find.text('Vatandaş Portalı'), findsNothing);

    authService.switchDemoRole(UserRole.carrier);
    await tester.pump();

    expect(find.text('ADD NEW CARGO & SHIPMENT'), findsOneWidget);
    expect(find.text('Meta AI Recommended Route'), findsOneWidget);
    expect(find.text('Selected Cargo Type: Water'), findsOneWidget);
    expect(find.text('Your Active Shipments'), findsOneWidget);
  });

  testWidgets('112 emergency sheet is translated to English', (
    WidgetTester tester,
  ) async {
    await LanguageService.instance.setLanguage(AppLanguage.en);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Emergency112Button())),
    );

    await tester.tap(find.text('CALL 112'));
    await tester.pumpAndSettle();

    expect(find.text('Emergency Help Lines'), findsOneWidget);
    expect(find.text('Calls open in your phone app.'), findsOneWidget);
    expect(find.text('112 Emergency Call Center'), findsOneWidget);
    expect(find.text('Acil Yardım Hatları'), findsNothing);
  });

  testWidgets('Llama assistant starts with English UI and greeting', (
    WidgetTester tester,
  ) async {
    await LanguageService.instance.setLanguage(AppLanguage.en);
    await tester.pumpWidget(const MaterialApp(home: AiAssistantScreen()));
    await tester.pump();

    expect(find.text('Meta Llama 3 Assistant'), findsOneWidget);
    expect(
      find.textContaining('Disaster Status & Crisis Report'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Hello! I am the Meta Llama 3 Disaster and First Aid Assistant',
      ),
      findsOneWidget,
    );
    expect(find.text('Meta Llama 3 Asistanı'), findsNothing);
  });

  testWidgets('report analysis panel localizes its sample report in English', (
    WidgetTester tester,
  ) async {
    await LanguageService.instance.setLanguage(AppLanguage.en);
    await tester.pumpWidget(const MaterialApp(home: AiTriageScreen()));
    await tester.pump();

    expect(find.text('Meta AI Triage Station'), findsOneWidget);
    expect(find.text('Enter a Report or Request for Help'), findsOneWidget);
    expect(find.text('RUBBLE & SEARCH AND RESCUE'), findsOneWidget);
    expect(find.text('CRITICAL URGENCY (%98)'), findsOneWidget);
    expect(find.text('Acoustic Listening Device'), findsOneWidget);
    expect(find.text('Meta AI Triage İstasyonu'), findsNothing);
  });

  testWidgets('disaster map labels localize area data in English', (
    WidgetTester tester,
  ) async {
    await LanguageService.instance.setLanguage(AppLanguage.en);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Column(
            children: [
              Text(context.areaCategoryTitle('Toplanma Alanı')),
              Text(context.areaName('Atatürk Parkı Güvenli Toplanma Alanı')),
              Text(context.areaAddress('Kamil Ocak Spor Kompleksi Çevresi')),
              Text(context.areaService('Temiz Su')),
              Text(context.stockItemName('İçme Suyu')),
              Text(context.stockQuantity('1.200 Şişe')),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Assembly Area'), findsOneWidget);
    expect(find.text('Atatürk Park Safe Assembly Area'), findsOneWidget);
    expect(find.text('Around Kamil Ocak Sports Complex'), findsOneWidget);
    expect(find.text('Clean Water'), findsOneWidget);
    expect(find.text('Drinking Water'), findsOneWidget);
    expect(find.text('1.200 bottles'), findsOneWidget);
  });

  testWidgets('carrier can add a shipment and complete its delivery', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    addTearDown(authService.logout);
    LanguageService.instance.setLanguage(AppLanguage.tr);
    authService.switchDemoRole(UserRole.carrier);

    await tester.pumpWidget(const AfetDestekApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('LOJİSTİK KOKPİTİ'), findsOneWidget);
    expect(find.text('Acil İhtiyaç Noktaları'), findsOneWidget);

    await tester.tap(find.text('YENİ YÜK & SEVKİYAT EKLE'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).at(0), '34 ABC 123');
    await tester.enterText(find.byType(TextField).at(1), '12');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('SEVKİYATI EKLE'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('1 sevkiyat · 12 birim yük'), findsOneWidget);
    await tester.ensureVisible(find.text('1. Yola Çıktım'));
    await tester.pump();
    await tester.tap(find.text('1. Yola Çıktım'));
    await tester.pump();
    await tester.ensureVisible(find.text('2. Afet Bölgesi Girişinde'));
    await tester.pump();
    await tester.tap(find.text('2. Afet Bölgesi Girişinde'));
    await tester.pump();
    await tester.ensureVisible(find.text('3. Dağıtım Noktasına Ulaştım'));
    await tester.pump();
    await tester.tap(find.text('3. Dağıtım Noktasına Ulaştım'));
    await tester.pump();
    await tester.ensureVisible(find.text('4. Teslim Ettim'));
    await tester.pump();
    await tester.tap(find.text('4. Teslim Ettim'));
    await tester.pump();

    expect(find.text('Teslim Edildi (+Stok Artırıldı)'), findsOneWidget);
    expect(find.text('Hedef stok: 12 Şişe'), findsOneWidget);
  });
}
