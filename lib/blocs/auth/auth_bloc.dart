// ============================================================
// "Bloc: Управление состоянием аутентификации"
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../services/auth_service.dart';
import '../../hive_service.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  /// Конструктор AuthBloc.
  /// Инициализирует Bloc с начальным состоянием AuthInitial.
  AuthBloc() : super(AuthInitial()) {
    on<LoginEvent>(_onLogin);
    on<RegisterEvent>(_onRegister);
    on<VerifyEmailEvent>(_onVerifyEmail);
    on<SendCodeEvent>(_onSendCode);
    on<ResetPasswordEvent>(_onResetPassword);
    on<LogoutEvent>(_onLogout);
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<TokenExpiredEvent>(_onTokenExpired);
    on<TokenRefreshedEvent>(_onTokenRefreshed);
  }

  /// Обработчик события входа в систему.
  /// Выполняет аутентификацию пользователя и сохраняет токен.
  Future<void> _onLogin(LoginEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await AuthService.login(
        email: event.email,
        password: event.password,
        remember: event.remember,
      );

      final token =
          response['data']?['access_token'] ??
          response['data']?['token'] ??
          response['access_token'] ??
          response['token'];
      if (token != null) {
        await HiveService.saveUserData('token', token);

        // Сохраняем возможные данные пользователя из ответа сразу в Hive
        final data = response['data'] ?? response;
        Map<String, dynamic>? userData;
        if (data is Map<String, dynamic>) {
          if (data.containsKey('user') &&
              data['user'] is Map<String, dynamic>) {
            userData = Map<String, dynamic>.from(data['user']);
          } else {
            userData = Map<String, dynamic>.from(data);
          }
        }

        if (userData != null) {
          if (userData.containsKey('name')) {
            await HiveService.saveUserData('name', userData['name'] ?? '');
          }
          if (userData.containsKey('email')) {
            await HiveService.saveUserData('email', userData['email'] ?? '');
          }
          if (userData.containsKey('phone')) {
            await HiveService.saveUserData('phone', userData['phone'] ?? '');
          }
          if (userData.containsKey('id')) {
            await HiveService.saveUserData('userId', '${userData['id']}');
          }
          if (userData.containsKey('username')) {
            await HiveService.saveUserData(
              'username',
              userData['username'] ?? '',
            );
          }
          if (userData.containsKey('avatar')) {
            await HiveService.saveUserData(
              'profileImage',
              userData['avatar'] ?? '',
            );
          }
        }

        emit(AuthAuthenticated(token: token));
      } else {
        emit(AuthError(message: 'Неверные учетные данные'));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  /// Обработчик события регистрации.
  /// Регистрирует нового пользователя.
  Future<void> _onRegister(RegisterEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await AuthService.register(
        name: event.name,
        lastName: event.lastName,
        email: event.email,
        phone: event.phone,
        password: event.password,
        passwordConfirmation: event.passwordConfirmation,
      );

      final token =
          response['data']?['access_token'] ??
          response['data']?['token'] ??
          response['access_token'] ??
          response['token'];
      if (token != null) {
        await HiveService.saveUserData('token', token);
        // ⚠️ ВАЖНО: Сохраняем флаг что email еще не верифицирован при регистрации
        await HiveService.saveUserData('isEmailVerified', 'false');

        // Сохраняем возможные данные пользователя из ответа сразу в Hive
        final data = response['data'] ?? response;
        Map<String, dynamic>? userData;
        if (data is Map<String, dynamic>) {
          if (data.containsKey('user') &&
              data['user'] is Map<String, dynamic>) {
            userData = Map<String, dynamic>.from(data['user']);
          } else {
            userData = Map<String, dynamic>.from(data);
          }
        }

        if (userData != null) {
          if (userData.containsKey('name')) {
            await HiveService.saveUserData('name', userData['name'] ?? '');
          }
          if (userData.containsKey('email')) {
            await HiveService.saveUserData('email', userData['email'] ?? '');
          }
          if (userData.containsKey('phone')) {
            await HiveService.saveUserData('phone', userData['phone'] ?? '');
          }
          if (userData.containsKey('id')) {
            await HiveService.saveUserData('userId', '${userData['id']}');
          }
          if (userData.containsKey('username')) {
            await HiveService.saveUserData(
              'username',
              userData['username'] ?? '',
            );
          }
          if (userData.containsKey('avatar')) {
            await HiveService.saveUserData(
              'profileImage',
              userData['avatar'] ?? '',
            );
          }
        }

        emit(AuthRegistered(email: event.email));
        print('✅ AuthBloc emitted AuthRegistered with email: ${event.email}');
      } else {
        print('❌ AuthBloc: token is null after registration');
        emit(AuthError(message: 'Регистрация прошла, но токен не получен'));
      }
    } catch (e) {
      print('❌ AuthBloc error in _onRegister: $e');
      emit(AuthError(message: e.toString()));
    }
  }

  /// Обработчик события верификации email.
  /// Верифицирует email пользователя с помощью кода.
  Future<void> _onVerifyEmail(
    VerifyEmailEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await AuthService.verify(email: event.email, code: event.code);
      emit(AuthEmailVerified());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  /// Обработчик события отправки кода подтверждения.
  /// Отправляет код подтверждения на email.
  Future<void> _onSendCode(SendCodeEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await AuthService.sendCode(email: event.email);
      emit(AuthCodeSent());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  /// Обработчик события сброса пароля.
  /// Сбрасывает пароль пользователя.
  Future<void> _onResetPassword(
    ResetPasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await AuthService.resetPassword(
        email: event.email,
        password: event.password,
        passwordConfirmation: event.passwordConfirmation,
        token: event.token,
      );
      emit(AuthPasswordReset());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  /// Обработчик события выхода из системы.
  /// Выполняет выход пользователя и очищает токен.
  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await AuthService.logout();
      await HiveService.deleteUserData('token');
      emit(AuthLoggedOut());
    } catch (e) {
      // Даже если logout на сервере не удался, очищаем локальный токен
      await HiveService.deleteUserData('token');
      emit(AuthLoggedOut());
    }
  }

  /// Обработчик события проверки статуса аутентификации.
  /// Проверяет, сохранен ли токен пользователя.
  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final token = await HiveService.getUserData('token');
      if (token != null && token.isNotEmpty) {
        emit(AuthAuthenticated(token: token));
      } else {
        emit(AuthInitial());
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  /// Обработчик события истечения токена.
  ///
  /// Вызывается когда TokenService не смог обновить токен.
  /// Очищает локальные данные и переводит пользователя на экран входа.
  Future<void> _onTokenExpired(
    TokenExpiredEvent event,
    Emitter<AuthState> emit,
  ) async {
    print('🔐 AuthBloc: токен истёк, выполняем принудительный logout...');
    try {
      // Пробуем корректно выйти на сервере
      await AuthService.logout();
    } catch (_) {
      // Игнорируем ошибки сервера — всё равно очищаем локально
    }
    // Очищаем токен из локального хранилища
    await HiveService.deleteUserData('token');
    print('🔐 AuthBloc: токен удалён, переходим на экран входа');
    emit(AuthTokenExpired());
  }

  /// Обработчик события успешного обновления токена.
  ///
  /// Вызывается когда TokenService успешно обновил токен в фоне.
  /// Обновляет состояние с новым токеном без прерывания работы пользователя.
  Future<void> _onTokenRefreshed(
    TokenRefreshedEvent event,
    Emitter<AuthState> emit,
  ) async {
    print(
      '✅ AuthBloc: токен обновлён в фоне: ${event.newToken.substring(0, 20)}...',
    );
    // Токен уже сохранён в Hive через ApiService.refreshToken()
    // Просто обновляем состояние с новым токеном
    emit(AuthAuthenticated(token: event.newToken));
  }
}
