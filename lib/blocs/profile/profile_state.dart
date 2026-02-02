/// Состояния профиля пользователя.
abstract class ProfileState {
  const ProfileState();
}

/// Начальное состояние профиля.
/// Пользователь еще не загрузил данные.
class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

/// Состояние загрузки данных профиля.
class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

/// Состояние успешной загрузки профиля.
/// [name] - имя пользователя.
/// [lastName] - фамилия пользователя.
/// [email] - email пользователя.
/// [userId] - ID пользователя.
/// [phone] - номер телефона пользователя.
/// [profileImage] - путь к изображению профиля пользователя.
/// [username] - имя пользователя (ник).
/// [about] - информация о себе.
/// [qrCode] - QR код пользователя в формате base64.
class ProfileLoaded extends ProfileState {
  final String name;
  final String lastName;
  final String email;
  final String userId;
  final String phone;
  final String? profileImage;
  final String username;
  final String? about;
  final String? qrCode;

  const ProfileLoaded({
    required this.name,
    required this.lastName,
    required this.email,
    required this.userId,
    required this.phone,
    this.profileImage,
    this.username = '@Name',
    this.about,
    this.qrCode,
  });
}

/// Состояние ошибки загрузки профиля.
/// [message] - сообщение об ошибке.
class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);
}

/// Состояние успешного обновления профиля.
class ProfileUpdated extends ProfileState {
  const ProfileUpdated();
}

/// Состояние успешного выхода из профиля.
class ProfileLoggedOut extends ProfileState {
  const ProfileLoggedOut();
}
