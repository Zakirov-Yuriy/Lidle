part of '../../library_vkid.dart';

/// A style for One Tap with [OAuth]s.
class OneTapWithOAuthsStyle {
  /// A type of One Tap.
  final OneTapWithOAuthsType type;

  /// A style of corners for One Tap.
  final OneTapCornersStyle cornersStyle;

  /// A size of One Tap.
  final OneTapSize size;

  /// Constructs a style instance.
  const OneTapWithOAuthsStyle({
    this.type = OneTapWithOAuthsType.light,
    this.cornersStyle = const OneTapCornersDefault(),
    this.size = OneTapSize.standard,
  });

  /// Converts this style to the corresponding [OneTapStyle].
  OneTapStyle toOneTapStyle() {
    switch (type) {
      case OneTapWithOAuthsType.light:
        return OneTapStyle(
            type: OneTapType.light, cornersStyle: cornersStyle, size: size);
      case OneTapWithOAuthsType.dark:
        return OneTapStyle(
            type: OneTapType.dark, cornersStyle: cornersStyle, size: size);
      case OneTapWithOAuthsType.system:
        return OneTapStyle(
            type: OneTapType.system, cornersStyle: cornersStyle, size: size);
    }
  }
}
