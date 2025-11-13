/// События для управления процессом восстановления пароля.
abstract class PasswordRecoveryEvent {}

/// Событие отправки запроса на восстановление пароля.
/// [email] - email пользователя для отправки кода восстановления.
class SendRecoveryCodeEvent extends PasswordRecoveryEvent {
  final String email;

  SendRecoveryCodeEvent(this.email);
}

/// Событие верификации кода восстановления.
/// [email] - email пользователя.
/// [code] - код восстановления.
class VerifyRecoveryCodeEvent extends PasswordRecoveryEvent {
  final String email;
  final String code;

  VerifyRecoveryCodeEvent({
    required this.email,
    required this.code,
  });
}

/// Событие сброса пароля.
/// [email] - email пользователя.
/// [password] - новый пароль.
/// [passwordConfirmation] - подтверждение нового пароля.
/// [token] - токен восстановления.
class ResetPasswordEvent extends PasswordRecoveryEvent {
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

/// Событие сброса состояния восстановления пароля.
class ResetRecoveryStateEvent extends PasswordRecoveryEvent {}
