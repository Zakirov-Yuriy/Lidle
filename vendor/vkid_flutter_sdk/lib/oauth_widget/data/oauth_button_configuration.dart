part of '../../library_vkid.dart';

/// Configuration for OAuth button.
class OAuthButtonConfiguration {
  /// A style of corners for One Tap.
  final OneTapCornersStyle cornersStyle;

  /// A size of One Tap.
  final OneTapSize size;

  /// Constructs a configuration instance.
  const OAuthButtonConfiguration({
    this.cornersStyle = const OneTapCornersDefault(),
    this.size = OneTapSize.standard,
  });
}
