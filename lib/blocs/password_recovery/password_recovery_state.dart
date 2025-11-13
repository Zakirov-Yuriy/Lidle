/// Состояния процесса восстановления пароля.
abstract class PasswordRecoveryState {
  const PasswordRecoveryState();
}

/// Начальное состояние восстановления пароля.
class PasswordRecoveryInitial extends PasswordRecoveryState {
  const PasswordRecoveryInitial();
}

/// Состояние загрузки при отправке запроса на восстановление.
class PasswordRecoveryLoading extends PasswordRecoveryState {
  const PasswordRecoveryLoading();
}

/// Состояние успешной отправки кода восстановления.
/// [email] - email, на который был отправлен код.
class RecoveryCodeSent extends PasswordRecoveryState {
  final String email;

  const RecoveryCodeSent(this.email);
}

/// Состояние успешной верификации кода восстановления.
/// [email] - email пользователя.
/// [token] - токен для сброса пароля.
class RecoveryCodeVerified extends PasswordRecoveryState {
  final String email;
  final String token;

  const RecoveryCodeVerified({
    required this.email,
    required this.token,
  });
}

/// Состояние успешного сброса пароля.
class PasswordResetSuccess extends PasswordRecoveryState {
  const PasswordResetSuccess();
}

/// Состояние ошибки в процессе восстановления пароля.
/// [message] - сообщение об ошибке.
class PasswordRecoveryError extends PasswordRecoveryState {
  final String message;

  const PasswordRecoveryError(this.message);
}

/// Состояние, когда профиль не найден.
/// Используется для отображения соответствующего сообщения пользователю.
class ProfileNotFound extends PasswordRecoveryState {
  const ProfileNotFound();
}
