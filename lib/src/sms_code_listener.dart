import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// How `VerifyCodeField` picks up a code from an incoming SMS on Android.
///
/// On iOS no setup is needed: the keyboard offers the code from Messages
/// above the keys ("From Messages 482913") and one tap fills the boxes.
enum SmsAutofill {
  /// Google's SMS User Consent API. When the SMS arrives, Android asks
  /// "Allow app to read this message?" and one tap fills the code. Works with
  /// any SMS that contains the code; no permission or message format needed.
  userConsent,

  /// Google's SMS Retriever API. Fills the code with no tap at all, but the
  /// SMS must end with your app's 11-character hash. Get it with
  /// [SmsCodeListener.appSignature] and add it to the message on your server.
  retriever,

  /// Don't listen for SMS. Pasting and keyboard suggestions still work.
  off,
}

/// Listens for an incoming SMS on Android. `VerifyCodeField` uses this for
/// you; call it directly only to build your own field.
abstract final class SmsCodeListener {
  static const MethodChannel _channel = MethodChannel('verify_code_field');

  /// Whether SMS listening is available: Android only.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Waits for the next SMS (up to 5 minutes) and returns its full text.
  ///
  /// Returns `null` on timeout, when the user denies access, when [stop] is
  /// called or another listen starts, and on platforms other than Android.
  /// [senderPhoneNumber] limits [SmsAutofill.userConsent] to one sender.
  static Future<String?> listen({
    SmsAutofill mode = SmsAutofill.userConsent,
    String? senderPhoneNumber,
  }) async {
    if (!isSupported || mode == SmsAutofill.off) return null;
    try {
      return await _channel.invokeMethod<String>(
        mode == SmsAutofill.retriever ? 'startRetriever' : 'startUserConsent',
        {'sender': senderPhoneNumber},
      );
    } on PlatformException catch (e) {
      debugPrint('verify_code_field: SMS listening failed: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Stops listening; a pending [listen] returns `null`.
  static Future<void> stop() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // Nothing to stop.
    } on MissingPluginException {
      // Plugin not registered (e.g. in tests).
    }
  }

  /// The 11-character hash that an SMS must end with for
  /// [SmsAutofill.retriever], e.g. `FA+9qCX9VSu`. It depends on your app's
  /// package name and signing key, so debug and release builds differ.
  /// Android only; `null` elsewhere.
  static Future<String?> appSignature() async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('getAppSignature');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
