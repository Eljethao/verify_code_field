import 'package:flutter/services.dart';

/// Finds a verification code of exactly [length] characters in [message].
///
/// Looks, in order, for:
/// 1. a run of exactly [length] digits: "Your code is 482913";
/// 2. the same digits split by one space or hyphen: "482 913", "482-913";
/// 3. when [digitsOnly] is false, a run of [length] letters and digits that
///    contains at least one digit: "Code: A7K2QP".
///
/// Digits that belong to a longer number (a phone number, an order number)
/// are never matched. Returns `null` when no code is found.
String? extractVerifyCode(
  String message, {
  required int length,
  bool digitsOnly = true,
}) {
  final exact = RegExp('(?<![0-9])[0-9]{$length}(?![0-9])').firstMatch(message);
  if (exact != null) return exact.group(0);

  final grouped = RegExp(r'(?<![0-9])([0-9]+)[ \-]([0-9]+)(?![0-9])');
  for (final match in grouped.allMatches(message)) {
    final code = match.group(1)! + match.group(2)!;
    if (code.length == length) return code;
  }

  if (!digitsOnly) {
    final mixed = RegExp('(?<![A-Za-z0-9])[A-Za-z0-9]{$length}(?![A-Za-z0-9])');
    for (final match in mixed.allMatches(message)) {
      final code = match.group(0)!;
      if (code.contains(RegExp('[0-9]'))) return code;
    }
  }
  return null;
}

/// Keeps only the characters a code can contain: digits, or letters and
/// digits when [digitsOnly] is false.
String sanitizeVerifyCode(String text, {required bool digitsOnly}) =>
    text.replaceAll(RegExp(digitsOnly ? '[^0-9]' : '[^A-Za-z0-9]'), '');

/// Input formatter used by `VerifyCodeField`.
///
/// Typing keeps only valid characters, up to [length]. A paste or a keyboard
/// suggestion that inserts several characters at once is searched for a code
/// first, so pasting a whole SMS ("Your code is 482 913") fills `482913`.
class VerifyCodeInputFormatter extends TextInputFormatter {
  VerifyCodeInputFormatter({required this.length, this.digitsOnly = true});

  final int length;
  final bool digitsOnly;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    String? code;
    if (raw.length - oldValue.text.length > 1) {
      code = extractVerifyCode(raw, length: length, digitsOnly: digitsOnly);
    }
    code ??= sanitizeVerifyCode(raw, digitsOnly: digitsOnly);
    if (code.length > length) code = code.substring(0, length);
    if (code == raw &&
        newValue.selection.isCollapsed &&
        newValue.selection.baseOffset == raw.length) {
      return newValue;
    }
    return TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
  }
}
