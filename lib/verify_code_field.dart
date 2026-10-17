/// A clean, responsive verification code (OTP) field: 4, 6 or any number of
/// boxes, easy typing and deleting, paste support, and SMS auto-fill on
/// Android and iOS.
library;

export 'src/code_extractor.dart'
    show extractVerifyCode, sanitizeVerifyCode, VerifyCodeInputFormatter;
export 'src/sms_code_listener.dart';
export 'src/verify_code_field.dart';
export 'src/verify_code_style.dart' show VerifyCodeShape, VerifyCodeStyle;
