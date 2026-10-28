import 'package:flutter_test/flutter_test.dart';
import 'package:afet_destek/main.dart';

void main() {
  testWidgets('Afet Destek smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AfetDestekApp());
    expect(find.text('AFET DESTEK'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsWidgets);
  });
}
