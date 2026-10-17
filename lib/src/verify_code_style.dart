import 'package:flutter/material.dart';

/// The look of each box.
enum VerifyCodeShape {
  /// Rounded boxes with a thin border.
  outlined,

  /// Rounded boxes with a soft background and no border until focused.
  filled,

  /// A line under each character.
  underline,
}

/// Decoration for `VerifyCodeField`. Every value is optional; anything left
/// `null` comes from the app's `ThemeData` (Material 3 colour scheme).
///
/// Boxes are [boxWidth] wide at most and shrink, together with [gap] and the
/// text, to fit narrow screens, so 4, 6 or 8 boxes always fit on one line.
@immutable
class VerifyCodeStyle {
  const VerifyCodeStyle({
    this.shape = VerifyCodeShape.outlined,
    this.boxWidth = 56,
    this.boxHeight,
    this.gap = 10,
    this.borderRadius = 12,
    this.borderWidth = 1.2,
    this.focusedBorderWidth = 2,
    this.textStyle,
    this.fillColor,
    this.borderColor,
    this.filledBorderColor,
    this.focusedBorderColor,
    this.errorColor,
    this.cursorColor,
    this.showCursor = true,
    this.errorTextStyle,
  });

  final VerifyCodeShape shape;

  /// Largest width of a box. Boxes get narrower when space is short.
  final double boxWidth;

  /// Height of a box at full [boxWidth]; scales with it. Defaults to
  /// `boxWidth * 1.15`.
  final double? boxHeight;

  /// Space between boxes at full [boxWidth]; scales with it.
  final double gap;

  final double borderRadius;
  final double borderWidth;
  final double focusedBorderWidth;

  /// Style of the characters. When it has no `fontSize`, the size follows
  /// the box height.
  final TextStyle? textStyle;

  /// Box background. Defaults to transparent for [VerifyCodeShape.outlined]
  /// and [VerifyCodeShape.underline], and a soft surface colour for
  /// [VerifyCodeShape.filled].
  final Color? fillColor;

  /// Border of an empty box.
  final Color? borderColor;

  /// Border of a box that has a character.
  final Color? filledBorderColor;

  /// Border of the box the next character goes into.
  final Color? focusedBorderColor;

  /// Border and message colour when the field shows an error.
  final Color? errorColor;

  final Color? cursorColor;

  /// Shows a blinking cursor in the box the next character goes into.
  final bool showCursor;

  final TextStyle? errorTextStyle;

  VerifyCodeStyle copyWith({
    VerifyCodeShape? shape,
    double? boxWidth,
    double? boxHeight,
    double? gap,
    double? borderRadius,
    double? borderWidth,
    double? focusedBorderWidth,
    TextStyle? textStyle,
    Color? fillColor,
    Color? borderColor,
    Color? filledBorderColor,
    Color? focusedBorderColor,
    Color? errorColor,
    Color? cursorColor,
    bool? showCursor,
    TextStyle? errorTextStyle,
  }) {
    return VerifyCodeStyle(
      shape: shape ?? this.shape,
      boxWidth: boxWidth ?? this.boxWidth,
      boxHeight: boxHeight ?? this.boxHeight,
      gap: gap ?? this.gap,
      borderRadius: borderRadius ?? this.borderRadius,
      borderWidth: borderWidth ?? this.borderWidth,
      focusedBorderWidth: focusedBorderWidth ?? this.focusedBorderWidth,
      textStyle: textStyle ?? this.textStyle,
      fillColor: fillColor ?? this.fillColor,
      borderColor: borderColor ?? this.borderColor,
      filledBorderColor: filledBorderColor ?? this.filledBorderColor,
      focusedBorderColor: focusedBorderColor ?? this.focusedBorderColor,
      errorColor: errorColor ?? this.errorColor,
      cursorColor: cursorColor ?? this.cursorColor,
      showCursor: showCursor ?? this.showCursor,
      errorTextStyle: errorTextStyle ?? this.errorTextStyle,
    );
  }
}

/// Which state a box is drawn in.
enum BoxState { empty, filled, focused, error, disabled }

/// [VerifyCodeStyle] with every colour filled in from the theme.
class ResolvedVerifyCodeStyle {
  ResolvedVerifyCodeStyle(BuildContext context, this.style) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    fill =
        style.fillColor ??
        (style.shape == VerifyCodeShape.filled
            ? cs.surfaceContainerHighest
            : Colors.transparent);
    border =
        style.borderColor ??
        (style.shape == VerifyCodeShape.filled
            ? Colors.transparent
            : cs.outlineVariant);
    filledBorder =
        style.filledBorderColor ??
        (style.shape == VerifyCodeShape.filled
            ? Colors.transparent
            : cs.outline);
    focused = style.focusedBorderColor ?? cs.primary;
    error = style.errorColor ?? cs.error;
    cursor = style.cursorColor ?? cs.primary;
    disabled = cs.onSurface.withValues(alpha: 0.12);
    text = (theme.textTheme.headlineSmall ?? const TextStyle())
        .copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)
        .merge(style.textStyle);
    disabledText = cs.onSurface.withValues(alpha: 0.38);
    errorText = (theme.textTheme.bodySmall ?? const TextStyle())
        .copyWith(color: error)
        .merge(style.errorTextStyle);
  }

  final VerifyCodeStyle style;
  late final Color fill;
  late final Color border;
  late final Color filledBorder;
  late final Color focused;
  late final Color error;
  late final Color cursor;
  late final Color disabled;
  late final TextStyle text;
  late final Color disabledText;
  late final TextStyle errorText;

  Color borderFor(BoxState state) => switch (state) {
    BoxState.empty => border,
    BoxState.filled => filledBorder,
    BoxState.focused => focused,
    BoxState.error => error,
    BoxState.disabled => disabled,
  };

  Decoration decorationFor(BoxState state, double scale) {
    final width =
        (state == BoxState.focused
            ? style.focusedBorderWidth
            : style.borderWidth) *
        scale.clamp(0.75, 1.0);
    final side = BorderSide(color: borderFor(state), width: width);
    final background = state == BoxState.disabled && fill != Colors.transparent
        ? fill.withValues(alpha: fill.a * 0.5)
        : fill;
    if (style.shape == VerifyCodeShape.underline) {
      return BoxDecoration(
        color: background,
        border: Border(bottom: side),
      );
    }
    return BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(style.borderRadius * scale),
      border: Border.fromBorderSide(side),
    );
  }
}
