import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../services/auth_service.dart';
import '../../hive_service.dart';

/// Bloc для управления состоянием аутентификации.
/// Обрабатывает события аутентификации и управляет переходами между состояниями.
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

      if (response['access_token'] != null) {
        await HiveService.saveUserData('token', response['access_token']);
        emit(AuthAuthenticated(token: response['access_token']));
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
      await AuthService.register(
        name: event.name,
        lastName: event.lastName,
        email: event.email,
        phone: event.phone,
        password: event.password,
        passwordConfirmation: event.passwordConfirmation,
      );
      emit(AuthRegistered());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  /// Обработчик события верификации email.
  /// Верифицирует email пользователя с помощью кода.
  Future<void> _onVerifyEmail(VerifyEmailEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await AuthService.verify(
        email: event.email,
        code: event.code,
      );
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
  Future<void> _onResetPassword(ResetPasswordEvent event, Emitter<AuthState> emit) async {
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
  Future<void> _onCheckAuthStatus(CheckAuthStatusEvent event, Emitter<AuthState> emit) async {
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
}
