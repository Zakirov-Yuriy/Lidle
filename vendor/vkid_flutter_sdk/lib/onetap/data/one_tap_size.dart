part of '../../library_vkid.dart';

/// A size of One Tap.
enum OneTapSize {
  /// Default One Tap size.
  standard,

  /// A small One Tap size with 32px height.
  small32,

  /// A small One Tap size with 34px height.
  small34,

  /// A small One Tap size with 36px height.
  small36,

  /// A small One Tap size with 38px height.
  small38,

  /// A medium One Tap size with 40px height.
  medium40,

  /// A medium One Tap size with 42px height.
  medium42,

  /// A medium One Tap size with 44px height.
  medium44,

  /// A medium One Tap size with 46px height.
  medium46,

  /// A large One Tap size with 48px height.
  large48,

  /// A large One Tap size with 50px height.
  large50,

  /// A large One Tap size with 52px height.
  large52,

  /// A large One Tap size with 54px height.
  large54,

  /// A large One Tap size with 56px height.
  large56,
}

extension OneTapSizeExtension on OneTapSize {
  int get value {
    // ignore: sdk_version_since
    if (name == "standard") {
      return 44;
    } else {
      // ignore: sdk_version_since
      var numberStr = name.replaceAll(RegExp(r'[^0-9]'), '');
      return int.parse(numberStr);
    }
  }
}
