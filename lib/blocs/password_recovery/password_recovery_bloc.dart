import 'package:flutter_bloc/flutter_bloc.dart';
import 'password_recovery_event.dart';
import 'password_recovery_state.dart';
import '../../services/auth_service.dart';

/// Bloc для управления процессом восстановления пароля.
/// Обрабатывает события отправки кода, верификации и сброса пароля.
class PasswordRecoveryBloc extends Bloc<PasswordRecoveryEvent, PasswordRecoveryState> {
  /// Конструктор PasswordRecoveryBloc.
  /// Инициализирует Bloc с начальным состоянием PasswordRecoveryInitial.
  PasswordRecoveryBloc() : super(const PasswordRecoveryInitial()) {
    on<SendRecoveryCodeEvent>(_onSendRecoveryCode);
    on<VerifyRecoveryCodeEvent>(_onVerifyRecoveryCode);
    on<ResetPasswordEvent>(_onResetPassword);
    on<ResetRecoveryStateEvent>(_onResetRecoveryState);
  }

  /// Обработчик события отправки кода восстановления.
  /// Отправляет запрос на восстановление пароля.
  Future<void> _onSendRecoveryCode(
    SendRecoveryCodeEvent event,
    Emitter<PasswordRecoveryState> emit,
  ) async {
    emit(const PasswordRecoveryLoading());
    try {
      await AuthService.forgotPassword(email: event.email);
      emit(RecoveryCodeSent(event.email));
    } catch (e) {
      // Для демонстрации - если email не найден, показываем ошибку
      if (e.toString().contains('not found') || e.toString().contains('404')) {
        emit(const ProfileNotFound());
      } else {
        emit(PasswordRecoveryError(e.toString()));
      }
    }
  }

  /// Обработчик события верификации кода восстановления.
  /// Верифицирует код и возвращает токен для сброса пароля.
  Future<void> _onVerifyRecoveryCode(
    VerifyRecoveryCodeEvent event,
    Emitter<PasswordRecoveryState> emit,
  ) async {
    emit(const PasswordRecoveryLoading());
    try {
      // В будущем здесь будет вызов API для верификации кода
      // final response = await AuthService.verifyRecoveryCode(
      //   email: event.email,
      //   code: event.code,
      // );

      // Имитация успешной верификации
      await Future.delayed(const Duration(milliseconds: 500));

      // Для демонстрации используем фиктивный токен
      const token = 'demo_recovery_token_123';
      emit(RecoveryCodeVerified(
        email: event.email,
        token: token,
      ));
    } catch (e) {
      emit(PasswordRecoveryError(e.toString()));
    }
  }

  /// Обработчик события сброса пароля.
  /// Выполняет сброс пароля с новым значением.
  Future<void> _onResetPassword(
    ResetPasswordEvent event,
    Emitter<PasswordRecoveryState> emit,
  ) async {
    emit(const PasswordRecoveryLoading());
    try {
      await AuthService.resetPassword(
        email: event.email,
        password: event.password,
        passwordConfirmation: event.passwordConfirmation,
        token: event.token,
      );
      emit(const PasswordResetSuccess());
    } catch (e) {
      emit(PasswordRecoveryError(e.toString()));
    }
  }

  /// Обработчик события сброса состояния восстановления пароля.
  /// Возвращает Bloc в начальное состояние.
  void _onResetRecoveryState(
    ResetRecoveryStateEvent event,
    Emitter<PasswordRecoveryState> emit,
  ) {
    emit(const PasswordRecoveryInitial());
  }
}
