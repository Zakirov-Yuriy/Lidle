part of '../../library_vkid.dart';

/// Style settings of a [OneTapBottomSheet].
class OneTapBottomSheetStyle {
  /// A type of the sheet.
  final OneTapBottomSheetType type;

  /// A style for corners.
  final OneTapCornersStyle buttonCornersStyle;

  /// A One Tap button size.
  final OneTapSize buttonSize;

  /// Constructs a style instance.
  const OneTapBottomSheetStyle({
    required this.type,
    this.buttonCornersStyle = const OneTapCornersDefault(),
    this.buttonSize = OneTapSize.standard,
  });
}
