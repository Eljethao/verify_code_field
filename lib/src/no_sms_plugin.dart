/// Registers the plugin on iOS, web and desktop, which need no native code:
/// the field works there with typing and paste, and on iOS the keyboard
/// offers the code from Messages. Only Android reads SMS natively.
class VerifyCodeFieldNoSms {
  /// Called by Flutter's plugin registrant; the web passes a registrar.
  static void registerWith([Object? registrar]) {}
}
