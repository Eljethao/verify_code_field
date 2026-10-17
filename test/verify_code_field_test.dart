import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verify_code_field/verify_code_field.dart';

Widget _app(Widget field, {double width = 400}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        child: Center(child: field),
      ),
    ),
  ),
);

final _boxes = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_Box',
);

void main() {
  testWidgets('shows 6 boxes by default and any other count', (tester) async {
    await tester.pumpWidget(_app(const VerifyCodeField()));
    expect(_boxes, findsNWidgets(6));

    await tester.pumpWidget(_app(const VerifyCodeField(length: 4)));
    expect(_boxes, findsNWidgets(4));
  });

  testWidgets('typing fills the boxes and completes once', (tester) async {
    final changes = <String>[];
    final completed = <String>[];
    await tester.pumpWidget(
      _app(VerifyCodeField(onChanged: changes.add, onCompleted: completed.add)),
    );

    await tester.tap(find.byType(VerifyCodeField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '12');
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(completed, isEmpty);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();
    expect(changes, ['12', '123456']);
    expect(completed, ['123456']);
    // The keyboard closes once the code is complete.
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('Backspace removes the last character', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(VerifyCodeField(controller: controller)));
    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '123');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(controller.text, '12');
    expect(find.text('3'), findsNothing);
  });

  testWidgets('pasting a whole SMS keeps only the code', (tester) async {
    String? completed;
    await tester.pumpWidget(
      _app(VerifyCodeField(onCompleted: (c) => completed = c)),
    );
    await tester.enterText(
      find.byType(TextField),
      'Your code is 482 913. It expires in 10 minutes.',
    );
    await tester.pumpAndSettle();
    expect(completed, '482913');
  });

  testWidgets('a code set from outside is cleaned up', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(VerifyCodeField(length: 4, controller: controller)),
    );
    controller.text = '12a3456';
    await tester.pump();
    expect(controller.text, '1234');

    controller.clear();
    await tester.pump();
    expect(find.text('1'), findsNothing);
  });

  testWidgets('shows the error message', (tester) async {
    await tester.pumpWidget(_app(const VerifyCodeField()));
    await tester.pumpWidget(
      _app(const VerifyCodeField(errorText: 'Wrong code')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Wrong code'), findsOneWidget);
  });

  testWidgets('obscureText hides the characters', (tester) async {
    await tester.pumpWidget(_app(const VerifyCodeField(obscureText: true)));
    await tester.enterText(find.byType(TextField), '12');
    await tester.pumpAndSettle();
    expect(find.text('1'), findsNothing);
    expect(find.text('●'), findsNWidgets(2));
  });

  testWidgets('letters are accepted when digitsOnly is false', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(VerifyCodeField(digitsOnly: false, controller: controller)),
    );
    await tester.enterText(find.byType(TextField), 'a7k-2q');
    await tester.pump();
    expect(controller.text, 'a7k2q');
  });

  group('fits the screen', () {
    for (final (width, length) in [
      (280.0, 8),
      (320.0, 6),
      (360.0, 6),
      (1024.0, 6),
    ]) {
      testWidgets('$length boxes in $width px', (tester) async {
        await tester.pumpWidget(
          _app(VerifyCodeField(length: length), width: width),
        );
        expect(tester.takeException(), isNull);
        final box = tester.getSize(_boxes.first);
        final row = tester.getSize(find.byType(VerifyCodeField));
        expect(row.width, lessThanOrEqualTo(width));
        expect(box.width, lessThanOrEqualTo(56));
        expect(box.height, greaterThan(box.width)); // slightly taller than wide
      });
    }

    testWidgets('large accessibility text does not overflow', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3)),
          child: _app(const VerifyCodeField(length: 8), width: 300),
        ),
      );
      await tester.enterText(find.byType(TextField), '12345678');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('has a screen reader label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const VerifyCodeField(length: 4)));
    expect(
      find.bySemanticsLabel(RegExp('Verification code, 4 digits')),
      findsOneWidget,
    );
    handle.dispose();
  });

  group('SMS auto-fill on Android', () {
    const channel = MethodChannel('verify_code_field');
    final calls = <MethodCall>[];

    final android = TargetPlatformVariant.only(TargetPlatform.android);

    setUp(calls.clear);

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    void mockSms(String? message) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method.startsWith('start') ? message : null;
          });
    }

    testWidgets('fills the code from the SMS', (tester) async {
      mockSms('Your verification code is 482913. Do not share it.');
      String? completed;
      await tester.pumpWidget(
        _app(VerifyCodeField(onCompleted: (c) => completed = c)),
      );
      await tester.pumpAndSettle();
      expect(calls.first.method, 'startUserConsent');
      expect(completed, '482913');
      expect(find.text('4'), findsOneWidget);
    }, variant: android);

    testWidgets('uses the Retriever API when asked', (tester) async {
      mockSms('<#> Code: 4821 FA+9qCX9VSu');
      String? completed;
      await tester.pumpWidget(
        _app(
          VerifyCodeField(
            length: 4,
            smsAutofill: SmsAutofill.retriever,
            onCompleted: (c) => completed = c,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls.first.method, 'startRetriever');
      expect(completed, '4821');
    }, variant: android);

    testWidgets('does nothing when turned off', (tester) async {
      mockSms('Code 482913');
      await tester.pumpWidget(
        _app(const VerifyCodeField(smsAutofill: SmsAutofill.off)),
      );
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    }, variant: android);

    testWidgets('listens again after the field is cleared', (tester) async {
      mockSms(null); // First listen times out.
      final controller = TextEditingController(text: '12');
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(VerifyCodeField(controller: controller)));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));

      mockSms('New code: 654321');
      controller.clear();
      await tester.pumpAndSettle();
      expect(calls, hasLength(2));
      expect(controller.text, '654321');
    }, variant: android);
  });
}
