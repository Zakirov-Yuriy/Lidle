part of '../../library_vkid.dart';

/// A style for One Tap.
class OneTapStyle {
  /// A type of One Tap.
  final OneTapType type;

  /// A style of corners for One Tap.
  final OneTapCornersStyle cornersStyle;

  /// A size of One Tap.
  final OneTapSize size;

  /// Constructs a style instance.
  const OneTapStyle({
    this.type = OneTapType.light,
    this.cornersStyle = const OneTapCornersDefault(),
    this.size = OneTapSize.standard,
  });
}
