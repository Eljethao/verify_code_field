import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verify_code_field/verify_code_field.dart';

void main() {
  group('extractVerifyCode', () {
    test('finds a code of the right length', () {
      expect(extractVerifyCode('Your code is 482913.', length: 6), '482913');
      expect(extractVerifyCode('4821 is your login code', length: 4), '4821');
    });

    test('ignores digits that are part of a longer number', () {
      const sms = 'Call 02055551234 if this was not you. Code: 482913';
      expect(extractVerifyCode(sms, length: 6), '482913');
      expect(extractVerifyCode('Order 12345678 shipped', length: 6), isNull);
    });

    test('skips numbers of another length', () {
      expect(
        extractVerifyCode('Code 482913, valid for 10 minutes', length: 6),
        '482913',
      );
      expect(extractVerifyCode('Code 482913', length: 4), isNull);
    });

    test('joins a code split by a space or hyphen', () {
      expect(extractVerifyCode('Your code: 482 913', length: 6), '482913');
      expect(extractVerifyCode('Your code: 482-913', length: 6), '482913');
    });

    test('finds letters and digits when digitsOnly is false', () {
      expect(
        extractVerifyCode(
          'Use A7K2QP to sign in',
          length: 6,
          digitsOnly: false,
        ),
        'A7K2QP',
      );
      // A plain word of the same length is not a code.
      expect(
        extractVerifyCode('Please verify', length: 6, digitsOnly: false),
        isNull,
      );
    });

    test('reads Lao and other non-Latin messages', () {
      expect(extractVerifyCode('ລະຫັດຂອງທ່ານແມ່ນ 482913', length: 6), '482913');
    });
  });

  group('VerifyCodeInputFormatter', () {
    final formatter = VerifyCodeInputFormatter(length: 6);

    TextEditingValue type(String old, String next) =>
        formatter.formatEditUpdate(
          TextEditingValue(text: old),
          TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(offset: next.length),
          ),
        );

    test('keeps digits and drops anything else', () {
      expect(type('12', '12a').text, '12');
      expect(type('12', '123').text, '123');
    });

    test('stops at the length', () {
      expect(type('123456', '1234567').text, '123456');
    });

    test('pulls the code out of a pasted message', () {
      expect(type('', 'Ref 99: your code is 482 913').text, '482913');
      expect(type('12', '12Your code is 654321').text, '654321');
    });

    test('keeps the caret at the end', () {
      final value = type('', 'Code 482913');
      expect(value.selection, const TextSelection.collapsed(offset: 6));
    });
  });
}
