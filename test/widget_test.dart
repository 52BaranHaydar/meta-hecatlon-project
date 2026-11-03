import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:afet_destek/main.dart';
import 'package:afet_destek/models/user_model.dart';
import 'package:afet_destek/services/auth_service.dart';

void main() {
  testWidgets('Afet Destek smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AfetDestekApp());
    expect(find.text('AFET DESTEK'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsWidgets);
  });

  testWidgets('role changes open the matching role home tab', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    addTearDown(authService.logout);
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

  testWidgets('carrier can add a shipment and complete its delivery', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    addTearDown(authService.logout);
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
