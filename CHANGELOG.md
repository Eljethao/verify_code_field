## 0.1.1

* Screenshots and an animated demo in the README and on pub.dev.

## 0.1.0

* Initial release: `VerifyCodeField`, a verification code (OTP) field drawn
  as a row of boxes. 6 boxes by default; any count (4, 5, 8…) with `length`.
* Typing fills left to right, Backspace removes the last character, and
  pasting a whole SMS keeps just the code. Hardware keyboards work too.
* Boxes, gaps and text shrink to fit narrow screens and large text sizes.
* Three shapes (outlined, filled, underline), colours from `ThemeData`, error
  message with a short shake, hidden characters, letters-and-digits codes.
* SMS auto-fill: the keyboard's one-time-code suggestion on iOS, and Google's
  SMS User Consent or SMS Retriever API on Android (no SMS permission).
* `extractVerifyCode` to find a code in any message.
