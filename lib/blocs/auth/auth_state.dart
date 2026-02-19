/// Состояния аутентификации.
/// Определяют различные состояния, в которых может находиться процесс аутентификации.
abstract class AuthState {}

/// Начальное состояние аутентификации.
/// Используется при инициализации Bloc.
class AuthInitial extends AuthState {}

/// Состояние загрузки.
/// Показывает, что выполняется асинхронная операция аутентификации.
class AuthLoading extends AuthState {}

/// Состояние успешной аутентификации.
/// Содержит токен доступа пользователя.
class AuthAuthenticated extends AuthState {
  final String token;

  AuthAuthenticated({required this.token});
}

/// Состояние ошибки аутентификации.
/// Содержит сообщение об ошибке.
class AuthError extends AuthState {
  final String message;

  AuthError({required this.message});
}

/// Состояние успешной регистрации.
/// Показывает, что регистрация прошла успешно, но требуется верификация.
class AuthRegistered extends AuthState {
  final String email;

  AuthRegistered({required this.email});
}

/// Состояние успешной верификации email.
/// Показывает, что email был успешно верифицирован.
class AuthEmailVerified extends AuthState {}

/// Состояние успешной отправки кода.
/// Показывает, что код подтверждения был отправлен на email.
class AuthCodeSent extends AuthState {}

/// Состояние успешного сброса пароля.
/// Показывает, что пароль был успешно изменен.
class AuthPasswordReset extends AuthState {}

/// Состояние выхода из системы.
/// Показывает, что пользователь вышел из аккаунта.
class AuthLoggedOut extends AuthState {}

/// Состояние истечения токена.
/// Показывает, что токен истёк и refresh не удался — нужна повторная авторизация.
class AuthTokenExpired extends AuthState {}
