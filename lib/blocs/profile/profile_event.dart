/// События для управления состоянием профиля пользователя.
abstract class ProfileEvent {}

/// Событие загрузки данных профиля.
/// Загружает информацию о пользователе из хранилища или API.
class LoadProfileEvent extends ProfileEvent {}

/// Событие обновления данных профиля.
/// [name] - новое имя пользователя.
/// [email] - новый email пользователя.
/// [phone] - новый номер телефона.
class UpdateProfileEvent extends ProfileEvent {
  final String name;
  final String email;
  final String phone;

  UpdateProfileEvent({
    required this.name,
    required this.email,
    required this.phone,
  });
}

/// Событие выхода из профиля.
/// Очищает данные пользователя и выполняет выход.
class LogoutProfileEvent extends ProfileEvent {}
