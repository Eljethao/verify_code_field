import 'package:flutter_test/flutter_test.dart';
import 'package:verify_code_field/verify_code_field.dart';
import 'package:verify_code_field_example/main.dart';

void main() {
  testWidgets('the correct code is verified', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.byType(VerifyCodeField), findsOneWidget);

    await tester.enterText(find.byType(VerifyCodeField), '123456');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Verified'), findsOneWidget);
  });

  testWidgets('a wrong code shows an error', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.enterText(find.byType(VerifyCodeField), '999999');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      find.text('That code is not correct. Please try again.'),
      findsOneWidget,
    );
  });
}
