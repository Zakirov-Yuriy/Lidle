/// События для управления состоянием профиля пользователя.
abstract class ProfileEvent {}

/// Событие загрузки данных профиля.
/// Загружает информацию о пользователе из хранилища или API.
/// [forceRefresh] - если true, показывает загрузку и не использует кэш
class LoadProfileEvent extends ProfileEvent {
  final bool forceRefresh;

  LoadProfileEvent({this.forceRefresh = false});
}

/// Событие обновления данных профиля.
/// [name] - новое имя пользователя.
/// [lastName] - новая фамилия пользователя.
/// [email] - новый email пользователя.
/// [phone] - новый номер телефона.
/// [profileImage] - путь к новому изображению профиля.
/// [username] - новое имя пользователя (ник).
/// [about] - новая информация о себе.
class UpdateProfileEvent extends ProfileEvent {
  final String name;
  final String lastName;
  final String email;
  final String phone;
  final String? profileImage;
  final String? username;
  final String? about;

  UpdateProfileEvent({
    required this.name,
    required this.lastName,
    required this.email,
    required this.phone,
    this.profileImage,
    this.username,
    this.about,
  });
}

/// Событие выхода из профиля.
/// Очищает данные пользователя и выполняет выход.
class LogoutProfileEvent extends ProfileEvent {}
