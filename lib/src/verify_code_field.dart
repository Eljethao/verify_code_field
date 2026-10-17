import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'code_extractor.dart';
import 'sms_code_listener.dart';
import 'verify_code_style.dart';

/// A verification code (OTP) field drawn as a row of boxes.
///
/// ```dart
/// VerifyCodeField(
///   length: 6, // default; use 4, 5, 8...
///   onCompleted: (code) => verify(code),
/// )
/// ```
///
/// Behind the boxes is one real text field, so typing, Backspace, pasting
/// and hardware keyboards all work as expected: characters fill the boxes
/// left to right and Backspace removes the last one. Pasting a whole SMS
/// fills just the code.
///
/// The code from an incoming SMS fills in automatically:
/// * **iOS**: the keyboard suggests the code from Messages; one tap fills it.
/// * **Android**: see [smsAutofill]. By default Android asks the user to
///   allow reading the message, then fills the code.
class VerifyCodeField extends StatefulWidget {
  /// Creates a verification code field with [length] boxes (6 by default).
  const VerifyCodeField({
    super.key,
    this.length = 6,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.obscuringCharacter = '●',
    this.digitsOnly = true,
    this.onChanged,
    this.onCompleted,
    this.errorText,
    this.style = const VerifyCodeStyle(),
    this.smsAutofill = SmsAutofill.userConsent,
    this.senderPhoneNumber,
    this.codeExtractor,
    this.unfocusOnCompleted = true,
    this.semanticLabel,
  }) : assert(length > 0, 'length must be at least 1');

  /// Number of boxes. Defaults to 6.
  final int length;

  /// Holds the entered code. Call `controller.clear()` to empty the boxes,
  /// for example after a wrong code or when sending a new one.
  final TextEditingController? controller;

  /// Controls focus; the field creates its own when `null`.
  final FocusNode? focusNode;

  /// Opens the keyboard as soon as the field appears.
  final bool autofocus;

  /// When `false`, the boxes are greyed out and can't be focused.
  final bool enabled;

  /// When `true`, the code is shown but can't be changed (e.g. while checking it).
  final bool readOnly;

  /// Shows [obscuringCharacter] instead of each character.
  final bool obscureText;

  /// Shown in place of each character when [obscureText] is on.
  final String obscuringCharacter;

  /// Accepts digits only, with a number keyboard. Set to `false` for codes
  /// with letters, such as `A7K2QP`.
  final bool digitsOnly;

  /// Called on every change with the code so far.
  final ValueChanged<String>? onChanged;

  /// Called once all boxes are filled.
  final ValueChanged<String>? onCompleted;

  /// Shows the field in its error colour, with this message under the boxes.
  /// Use an empty string for the error colour without a message.
  final String? errorText;

  final VerifyCodeStyle style;

  /// How the code is read from an incoming SMS on Android. Defaults to
  /// [SmsAutofill.userConsent]. Has no effect on other platforms.
  final SmsAutofill smsAutofill;

  /// Only react to SMS from this number (with [SmsAutofill.userConsent]).
  final String? senderPhoneNumber;

  /// Pulls the code out of an SMS. Defaults to [extractVerifyCode], which
  /// finds a run of [length] digits.
  final String? Function(String message)? codeExtractor;

  /// Closes the keyboard once all boxes are filled.
  final bool unfocusOnCompleted;

  /// Read by screen readers. Defaults to "Verification code, N characters".
  final String? semanticLabel;

  @override
  State<VerifyCodeField> createState() => _VerifyCodeFieldState();
}

class _VerifyCodeFieldState extends State<VerifyCodeField>
    with SingleTickerProviderStateMixin {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  final ValueNotifier<bool> _cursorVisible = ValueNotifier(true);
  Timer? _cursorTimer;

  String _text = '';
  String? _completed;
  bool _listeningForSms = false;
  bool _animate = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    _text = _controller.text;
    if (_clean(_text) != _text) _scheduleClean();
    _listenForSms();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate = !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
  }

  @override
  void didUpdateWidget(VerifyCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final old = oldWidget.controller ?? _ownController!;
      old.removeListener(_onTextChanged);
      if (widget.controller != null && _ownController != null) {
        _ownController!.dispose();
        _ownController = null;
      } else if (widget.controller == null) {
        _ownController = TextEditingController(text: old.text);
      }
      _controller.addListener(_onTextChanged);
      _text = _controller.text;
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode!).removeListener(_onFocusChanged);
      if (widget.focusNode != null && _ownFocusNode != null) {
        _ownFocusNode!.dispose();
        _ownFocusNode = null;
      }
      _focusNode.addListener(_onFocusChanged);
    }
    if (oldWidget.length != widget.length ||
        oldWidget.digitsOnly != widget.digitsOnly) {
      _completed = null;
      _scheduleClean();
    }
    if (widget.errorText != null && oldWidget.errorText == null) _shakeOnce();
  }

  @override
  void dispose() {
    if (_listeningForSms) SmsCodeListener.stop();
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    _cursorTimer?.cancel();
    _cursorVisible.dispose();
    _shake.dispose();
    super.dispose();
  }

  String _clean(String text) {
    final code = sanitizeVerifyCode(text, digitsOnly: widget.digitsOnly);
    return code.length > widget.length
        ? code.substring(0, widget.length)
        : code;
  }

  /// Fixes a code set from outside (too long, invalid characters) after the
  /// current frame, so listeners never run during a build.
  void _scheduleClean() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final clean = _clean(_controller.text);
      if (clean != _controller.text) _setCode(clean);
    });
  }

  void _setCode(String code) {
    _controller.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
  }

  void _onTextChanged() {
    final value = _controller.value;
    // A code set in code (not typed) may be too long or have invalid characters.
    final clean = _clean(value.text);
    if (clean != value.text) {
      _setCode(clean);
      return;
    }
    // Characters always fill left to right: keep the caret at the end.
    if (!value.composing.isValid &&
        (!value.selection.isCollapsed ||
            value.selection.baseOffset != value.text.length)) {
      _controller.selection = TextSelection.collapsed(
        offset: value.text.length,
      );
      return;
    }
    final text = value.text;
    if (text == _text) return;
    _text = text;
    setState(() {});
    _resetCursorBlink();
    widget.onChanged?.call(text);

    if (text.length == widget.length) {
      if (_completed != text) {
        _completed = text;
        widget.onCompleted?.call(text);
        if (widget.unfocusOnCompleted) _focusNode.unfocus();
      }
    } else {
      _completed = null;
      // Cleared after a wrong code or a resend: wait for the next SMS.
      if (text.isEmpty) _listenForSms();
    }
  }

  void _onFocusChanged() {
    setState(() {});
    if (_focusNode.hasFocus) {
      _resetCursorBlink();
      if (_text.length < widget.length) _listenForSms();
    } else {
      _cursorTimer?.cancel();
    }
  }

  void _resetCursorBlink() {
    _cursorTimer?.cancel();
    _cursorVisible.value = true;
    if (!_focusNode.hasFocus || !widget.style.showCursor || !_animate) return;
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 530), (_) {
      _cursorVisible.value = !_cursorVisible.value;
    });
  }

  void _shakeOnce() {
    if (_animate) _shake.forward(from: 0);
  }

  Future<void> _listenForSms() async {
    if (_listeningForSms ||
        widget.smsAutofill == SmsAutofill.off ||
        !widget.enabled ||
        widget.readOnly ||
        !SmsCodeListener.isSupported) {
      return;
    }
    _listeningForSms = true;
    final message = await SmsCodeListener.listen(
      mode: widget.smsAutofill,
      senderPhoneNumber: widget.senderPhoneNumber,
    );
    _listeningForSms = false;
    if (!mounted || message == null) return;
    final extractor = widget.codeExtractor;
    final code = extractor != null
        ? extractor(message)
        : extractVerifyCode(
            message,
            length: widget.length,
            digitsOnly: widget.digitsOnly,
          );
    if (code != null) _setCode(_clean(code));
  }

  BoxState _stateOf(int index, bool focused) {
    if (!widget.enabled) return BoxState.disabled;
    if (widget.errorText != null) return BoxState.error;
    final active = math.min(_text.length, widget.length - 1);
    if (focused && index == active) return BoxState.focused;
    return index < _text.length ? BoxState.filled : BoxState.empty;
  }

  @override
  Widget build(BuildContext context) {
    final style = ResolvedVerifyCodeStyle(context, widget.style);
    final animate = _animate;
    final focused = _focusNode.hasFocus;
    final showCursor =
        focused &&
        widget.style.showCursor &&
        widget.enabled &&
        !widget.readOnly;
    final error = widget.errorText;

    return LayoutBuilder(
      builder: (context, constraints) {
        final m = _Metrics.fit(
          constraints.maxWidth,
          widget.length,
          widget.style,
        );
        final boxes = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.length; i++) ...[
              if (i > 0) SizedBox(width: m.gap),
              _Box(
                char: i < _text.length ? _text[i] : null,
                state: _stateOf(i, focused),
                showCursor: showCursor && i == _text.length,
                cursorVisible: _cursorVisible,
                obscure: widget.obscureText,
                obscuringCharacter: widget.obscuringCharacter,
                style: style,
                metrics: m,
                animate: animate,
              ),
            ],
          ],
        );

        final field = Stack(
          children: [
            Positioned.fill(child: _buildInput(style, m)),
            IgnorePointer(child: ExcludeSemantics(child: boxes)),
          ],
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _shake,
              builder: (context, child) {
                final t = _shake.value;
                final dx =
                    math.sin(t * math.pi * 6) * (1 - t) * m.boxWidth * 0.12;
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: field,
            ),
            AnimatedSize(
              duration: animate
                  ? const Duration(milliseconds: 160)
                  : Duration.zero,
              alignment: Alignment.topCenter,
              child: error == null || error.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: SizedBox(
                        width: m.rowWidth,
                        child: Text(
                          error,
                          style: style.errorText,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  /// The real text field: invisible, covering the boxes, so it receives
  /// taps, the keyboard, paste and the platform's one-time-code autofill.
  Widget _buildInput(ResolvedVerifyCodeStyle style, _Metrics m) {
    const none = InputBorder.none;
    return TextSelectionTheme(
      data: const TextSelectionThemeData(
        cursorColor: Colors.transparent,
        selectionColor: Colors.transparent,
        selectionHandleColor: Colors.transparent,
      ),
      child: Semantics(
        label:
            widget.semanticLabel ??
            'Verification code, ${widget.length} '
                '${widget.digitsOnly ? 'digits' : 'characters'}',
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          obscureText: widget.obscureText,
          keyboardType: widget.digitsOnly
              ? TextInputType.number
              : TextInputType.visiblePassword,
          textCapitalization: widget.digitsOnly
              ? TextCapitalization.none
              : TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            VerifyCodeInputFormatter(
              length: widget.length,
              digitsOnly: widget.digitsOnly,
            ),
          ],
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          showCursor: false,
          cursorColor: Colors.transparent,
          magnifierConfiguration: TextMagnifierConfiguration.disabled,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          style: TextStyle(
            color: Colors.transparent,
            fontSize: m.boxHeight * 0.42,
          ),
          decoration: const InputDecoration(
            isCollapsed: true,
            filled: false,
            counterText: '',
            contentPadding: EdgeInsets.zero,
            border: none,
            enabledBorder: none,
            focusedBorder: none,
            disabledBorder: none,
            errorBorder: none,
            focusedErrorBorder: none,
          ),
        ),
      ),
    );
  }
}

/// Box size, gap and scale for the available width.
class _Metrics {
  const _Metrics(
    this.scale,
    this.boxWidth,
    this.boxHeight,
    this.gap,
    this.rowWidth,
  );

  factory _Metrics.fit(double maxWidth, int length, VerifyCodeStyle style) {
    final natural = length * style.boxWidth + (length - 1) * style.gap;
    // Leave a pixel spare so rounding never overflows the row.
    final available = maxWidth.isFinite ? math.max(0.0, maxWidth - 1) : natural;
    final scale = natural > available ? available / natural : 1.0;
    return _Metrics(
      scale,
      style.boxWidth * scale,
      (style.boxHeight ?? style.boxWidth * 1.15) * scale,
      style.gap * scale,
      natural * scale,
    );
  }

  final double scale;
  final double boxWidth;
  final double boxHeight;
  final double gap;
  final double rowWidth;
}

class _Box extends StatelessWidget {
  const _Box({
    required this.char,
    required this.state,
    required this.showCursor,
    required this.cursorVisible,
    required this.obscure,
    required this.obscuringCharacter,
    required this.style,
    required this.metrics,
    required this.animate,
  });

  final String? char;
  final BoxState state;
  final bool showCursor;
  final ValueListenable<bool> cursorVisible;
  final bool obscure;
  final String obscuringCharacter;
  final ResolvedVerifyCodeStyle style;
  final _Metrics metrics;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final fontSize = style.style.textStyle?.fontSize != null
        ? style.text.fontSize! * metrics.scale
        : metrics.boxHeight * 0.42;
    final textStyle = style.text.copyWith(
      fontSize: fontSize,
      height: 1.2,
      color: state == BoxState.disabled ? style.disabledText : null,
    );

    final Widget content;
    if (char != null) {
      content = Text(
        obscure ? obscuringCharacter : char!,
        key: ValueKey('c$char$obscure'),
        style: obscure
            ? textStyle.copyWith(fontSize: fontSize * 0.7)
            : textStyle,
      );
    } else if (showCursor) {
      content = ValueListenableBuilder<bool>(
        key: const ValueKey('cursor'),
        valueListenable: cursorVisible,
        builder: (context, visible, _) => AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: Duration(milliseconds: animate ? 120 : 0),
          child: Container(
            width: math.max(1.5, 2 * metrics.scale),
            height: fontSize * 1.1,
            decoration: BoxDecoration(
              color: style.cursor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      );
    } else {
      content = const SizedBox.shrink(key: ValueKey('empty'));
    }

    return AnimatedContainer(
      duration: Duration(milliseconds: animate ? 140 : 0),
      curve: Curves.easeOut,
      width: metrics.boxWidth,
      height: metrics.boxHeight,
      alignment: Alignment.center,
      decoration: style.decorationFor(state, metrics.scale),
      child: Padding(
        padding: EdgeInsets.all(2 * metrics.scale),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: animate ? 140 : 0),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
