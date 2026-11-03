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
}
