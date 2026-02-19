/// События для аутентификации.
/// Определяют различные действия, которые может выполнить пользователь
/// в контексте аутентификации.
abstract class AuthEvent {
  const AuthEvent();
}

/// Событие входа в систему.
/// Содержит email и пароль пользователя.
class LoginEvent extends AuthEvent {
  final String email;
  final String password;
  final bool remember;

  LoginEvent({
    required this.email,
    required this.password,
    this.remember = true,
  });
}

/// Событие регистрации нового пользователя.
/// Содержит все необходимые данные для создания аккаунта.
class RegisterEvent extends AuthEvent {
  final String name;
  final String lastName;
  final String email;
  final String phone;
  final String password;
  final String passwordConfirmation;

  RegisterEvent({
    required this.name,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
    required this.passwordConfirmation,
  });
}

/// Событие верификации email.
/// Содержит email и код подтверждения.
class VerifyEmailEvent extends AuthEvent {
  final String email;
  final String code;

  VerifyEmailEvent({required this.email, required this.code});
}

/// Событие отправки кода подтверждения.
/// Содержит email для отправки кода.
class SendCodeEvent extends AuthEvent {
  final String email;

  SendCodeEvent({required this.email});
}

/// Событие сброса пароля.
/// Содержит данные для восстановления пароля.
class ResetPasswordEvent extends AuthEvent {
  final String email;
  final String password;
  final String passwordConfirmation;
  final String token;

  ResetPasswordEvent({
    required this.email,
    required this.password,
    required this.passwordConfirmation,
    required this.token,
  });
}

/// Событие выхода из системы.
class LogoutEvent extends AuthEvent {
  const LogoutEvent();
}

/// Событие проверки статуса аутентификации.
/// Используется для проверки, авторизован ли пользователь при запуске приложения.
class CheckAuthStatusEvent extends AuthEvent {
  const CheckAuthStatusEvent();
}

/// Событие истечения токена.
/// Вызывается когда refresh токена не удался — пользователь должен войти заново.
class TokenExpiredEvent extends AuthEvent {
  const TokenExpiredEvent();
}

/// Событие успешного обновления токена.
/// Вызывается когда токен был успешно обновлён в фоне.
class TokenRefreshedEvent extends AuthEvent {
  final String newToken;
  const TokenRefreshedEvent({required this.newToken});
}
