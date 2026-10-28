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
    expect(find.text('Meta AI Önerilen Teslimat Noktası'), findsOneWidget);

    authService.switchDemoRole(UserRole.admin);
    await tester.pump();
    expect(find.text('Kriz Yönetimi'), findsOneWidget);
    expect(find.text('Gelen Yardım İhbarları (Meta AI)'), findsOneWidget);
  });
}
