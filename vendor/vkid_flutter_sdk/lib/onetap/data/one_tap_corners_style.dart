part of '../../library_vkid.dart';

/// A style of corners for One Tap
sealed class OneTapCornersStyle {
  final String _type;

  /// Constructs corner style instance.
  const OneTapCornersStyle(String classType) : _type = classType;
}

/// Default style of corners.
class OneTapCornersDefault extends OneTapCornersStyle {
  /// Constructs corner style instance.
  const OneTapCornersDefault() : super("OneTapCornersDefault");
}

/// A style of corners without rounding.
class OneTapCornersNone extends OneTapCornersStyle {
  /// Constructs corner style instance.
  const OneTapCornersNone() : super("OneTapCornersNone");
}

/// A rounded style of corners.
class OneTapCornersRounded extends OneTapCornersStyle {
  /// Constructs corner style instance.
  const OneTapCornersRounded() : super("OneTapCornersRounded");
}

/// A fully round style of corners.
class OneTapCornersRound extends OneTapCornersStyle {
  /// Constructs corner style instance.
  const OneTapCornersRound() : super("OneTapCornersRound");
}

/// A custom style of corners.
class OneTapCornersCustom extends OneTapCornersStyle {
  /// Corner rounding radius in pixels.
  final double radius;

  /// Constructs corner style instance with provided [radiusPx].
  const OneTapCornersCustom({required this.radius})
      : super("OneTapCornersCustom");
}
