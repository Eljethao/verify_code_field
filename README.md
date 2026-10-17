# verify_code_field

A clean, responsive verification code (OTP) field for Flutter. Pick how many
boxes you need — **6 by default**, or 4, 5, 8… — and the code from the SMS
fills in by itself on Android and iOS.

- Any number of boxes with `length`; **6** by default
- Boxes, gaps and text **shrink to fit** small phones and stay a comfortable
  size on tablets and desktop; large accessibility text never overflows
- Type to fill left to right, **Backspace** to delete, **paste** a whole SMS
  and only the code is kept; hardware keyboards work too
- **SMS auto-fill**: one tap on iOS ("From Messages" above the keyboard);
  one tap ("Allow") or none at all on Android — no SMS permission needed
- Outlined, filled or underline boxes; colours from your `ThemeData`, light
  and dark
- Error message with a short shake, hidden characters, letter-and-digit codes
- Only Flutter as a dependency (plus Google Play services' SMS library on
  Android)

## Install

```yaml
dependencies:
  verify_code_field: ^0.1.0
```

## Usage

```dart
import 'package:verify_code_field/verify_code_field.dart';

VerifyCodeField(
  onCompleted: (code) => verify(code), // called when all 6 boxes are filled
)

// 4 boxes:
VerifyCodeField(length: 4, onCompleted: verify)
```

A full sign-in screen, with checking, a wrong-code message and resend:

```dart
final controller = TextEditingController();
String? error;

VerifyCodeField(
  controller: controller,
  autofocus: true,
  errorText: error, // red boxes + message; null to clear
  onChanged: (_) => setState(() => error = null),
  onCompleted: (code) async {
    final ok = await api.verify(code);
    if (!ok) setState(() => error = 'That code is not correct.');
  },
);

// Resend: clear the boxes. The field then waits for the next SMS.
controller.clear();
```

### Options

| Parameter | Default | |
|---|---|---|
| `length` | `6` | Number of boxes |
| `controller` | internal | `TextEditingController`; `clear()` empties the boxes |
| `focusNode` | internal | |
| `autofocus` | `false` | Open the keyboard straight away |
| `onChanged` | | Every change, with the code so far |
| `onCompleted` | | Once all boxes are filled |
| `errorText` | `null` | Error colour + message under the boxes (`''` for colour only) |
| `obscureText` | `false` | Show `obscuringCharacter` (`●`) instead of the code |
| `digitsOnly` | `true` | `false` for codes with letters, e.g. `A7K2QP` |
| `enabled` / `readOnly` | `true` / `false` | |
| `unfocusOnCompleted` | `true` | Close the keyboard when the code is complete |
| `style` | `VerifyCodeStyle()` | Shape, sizes, colours — see below |
| `smsAutofill` | `SmsAutofill.userConsent` | Android: `userConsent`, `retriever` or `off` |
| `senderPhoneNumber` | `null` | Android user consent: only this sender |
| `codeExtractor` | `extractVerifyCode` | Your own `(message) => code` |
| `semanticLabel` | "Verification code, 6 digits" | Read by screen readers |

### Style

```dart
VerifyCodeField(
  style: VerifyCodeStyle(
    shape: VerifyCodeShape.filled, // outlined (default), filled, underline
    boxWidth: 52,                  // largest box width; shrinks to fit
    gap: 8,
    borderRadius: 14,
    focusedBorderColor: Colors.indigo,
    textStyle: TextStyle(fontWeight: FontWeight.w700),
  ),
)
```

Anything you leave out comes from the app's `ColorScheme`: `primary` for the
active box and cursor, `outline` / `outlineVariant` for borders, `error` for
errors.

## SMS auto-fill

### iOS

Nothing to set up. When the SMS arrives, iOS shows the code above the
keyboard ("From Messages 482913"); one tap fills the boxes. iOS decides which
messages hold a code — wording like *"Your verification code is 482913"*
works reliably. Apps can't read SMS on iOS, so this is the only way there.

### Android — user consent (default)

When the SMS arrives, Android asks *"Allow your app to read the message
below and enter the code?"*. One tap on **Allow** fills the boxes. No permission
and no special message format; Google's requirements for the message are:

- it contains a 4–10 character code with at least one digit,
- it comes from a number that isn't in the user's contacts (and from
  `senderPhoneNumber`, if you set it).

The device needs Google Play services. The field listens for 5 minutes after
it appears, again whenever it is focused while incomplete, and again after
`controller.clear()` (for a resent code).

### Android — no tap at all (SMS Retriever)

```dart
VerifyCodeField(smsAutofill: SmsAutofill.retriever)
```

The SMS must end with your app's 11-character hash, which your server adds
to the message:

```
Your verification code is 482913

FA+9qCX9VSu
```

Get the hash once with `await SmsCodeListener.appSignature()` (it is also
shown in the example app). It depends on the signing key, so the debug
build, your release build and an app signed by Google Play each have their
own hash — take it from the build your users install.

### Find the code yourself

```dart
extractVerifyCode('Your code is 482 913. Valid 10 min.', length: 6); // '482913'
```

It looks for exactly `length` digits that aren't part of a longer number,
then for the code split by a space or hyphen. Pass `codeExtractor` to the
field to use your own rule.

## Platforms

| | Typing, paste | SMS auto-fill |
|---|---|---|
| Android | ✓ | User Consent or Retriever API |
| iOS | ✓ | Keyboard suggestion |
| Web, macOS, Windows, Linux | ✓ | — |

## Example

`example/` is a complete verification screen: switch between 4, 5, 6 and 8
boxes and the three shapes, hide the code, and try right and wrong codes.

```bash
cd example
flutter run
```
