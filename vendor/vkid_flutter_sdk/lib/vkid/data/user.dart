part of '../../library_vkid.dart';

/// Data of some user.
class User {
  /// User's first name.
  final String firstName;

  /// User's last name.
  final String lastName;

  /// User's phone.
  ///
  /// Blank if unknown.
  final String phone;

  /// A url for user's avatar.
  ///
  /// Blank if unknown.
  final String avatarUrl;

  /// User's email.
  ///
  /// Blank if unknown.
  final String email;

  User(this.firstName, this.lastName, this.phone, this.avatarUrl, this.email);
}
