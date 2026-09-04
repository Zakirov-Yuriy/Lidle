import 'package:flutter_bloc/flutter_bloc.dart';
import 'password_recovery_event.dart';
import 'password_recovery_state.dart';
import '../../services/auth_service.dart';

/// Bloc восстановления пароля: код на почту, проверка кода, новый пароль.
///
/// Что здесь было не так до 04.09.2026, три вещи сразу:
///
/// 1. Проверка кода была заглушкой. Она ждала полсекунды и выдавала дальше
///    выдуманный токен `demo_recovery_token_123`. Сервер такой токен, конечно,
///    не принимал, поэтому сброс пароля НЕ РАБОТАЛ ВООБЩЕ: любой код доводил
///    человека до последнего экрана и там отказывал.
/// 2. Ответы сервера не проверялись. Наш API на неудачу отвечает 422 с телом
///    `success: false`, и это не исключение: `await` спокойно завершался, и
///    Bloc сообщал об успехе там, где успеха не было.
/// 3. Текст ошибки терялся. Сервер пишет конкретное («код неверный», «срок
///    действия истёк»), а экраны показывали «Ой, что-то пошло не так».
class PasswordRecoveryBloc
    extends Bloc<PasswordRecoveryEvent, PasswordRecoveryState> {
  PasswordRecoveryBloc() : super(const PasswordRecoveryInitial()) {
    on<SendRecoveryCodeEvent>(_onSendRecoveryCode);
    on<VerifyRecoveryCodeEvent>(_onVerifyRecoveryCode);
    on<ResetPasswordEvent>(_onResetPassword);
    on<ResetRecoveryStateEvent>(_onResetRecoveryState);
  }

  /// Шаг 1. Попросить код на почту.
  Future<void> _onSendRecoveryCode(
    SendRecoveryCodeEvent event,
    Emitter<PasswordRecoveryState> emit,
  ) async {
    emit(const PasswordRecoveryLoading());

    try {
      final response = await AuthService.forgotPassword(email: event.email);

      if (response['success'] != true) {
        // Профиля с такой почтой нет: у экрана для этого свой вид, с
        // подсветкой поля, а не всплывающая плашка.
        if (_looksLikeUnknownEmail(response)) {
          emit(const ProfileNotFound());
          return;
        }

        emit(PasswordRecoveryError(_message(response)));
        return;
      }

      emit(RecoveryCodeSent(event.email));
    } catch (e) {
      emit(PasswordRecoveryError(_cleanUp(e)));
    }
  }

  /// Шаг 2. Проверить код.
  Future<void> _onVerifyRecoveryCode(
    VerifyRecoveryCodeEvent event,
    Emitter<PasswordRecoveryState> emit,
  ) async {
    emit(const PasswordRecoveryLoading());

    try {
      final response = await AuthService.checkRecoveryCode(
        email: event.email,
        code: event.code,
      );

      if (response['success'] != true) {
        emit(PasswordRecoveryError(_message(response)));
        return;
      }

      // Дальше идёт сам код: сервер ждёт его же в поле `token` на последнем
      // шаге. Отдельного токена в обмене нет и не нужно — код одноразовый и
      // живёт час.
      emit(RecoveryCodeVerified(email: event.email, token: event.code));
    } catch (e) {
      emit(PasswordRecoveryError(_cleanUp(e)));
    }
  }

  /// Шаг 3. Задать новый пароль.
  Future<void> _onResetPassword(
    ResetPasswordEvent event,
    Emitter<PasswordRecoveryState> emit,
  ) async {
    emit(const PasswordRecoveryLoading());

    try {
      final response = await AuthService.resetPassword(
        email: event.email,
        password: event.password,
        passwordConfirmation: event.passwordConfirmation,
        token: event.token,
      );

      if (response['success'] != true) {
        emit(PasswordRecoveryError(_message(response)));
        return;
      }

      emit(const PasswordResetSuccess());
    } catch (e) {
      emit(PasswordRecoveryError(_cleanUp(e)));
    }
  }

  void _onResetRecoveryState(
    ResetRecoveryStateEvent event,
    Emitter<PasswordRecoveryState> emit,
  ) {
    emit(const PasswordRecoveryInitial());
  }

  /// Текст ошибки берём с сервера: он написан для показа человеку и всегда
  /// конкретнее, чем всё, что мы придумаем на клиенте.
  String _message(Map<String, dynamic> response) {
    final message = response['message'];

    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    return 'Не получилось. Попробуйте ещё раз.';
  }

  bool _looksLikeUnknownEmail(Map<String, dynamic> response) {
    final errors = response['errors'];

    // Правило `exists:users,email` ругается именно на поле почты.
    if (errors is Map && errors.containsKey('email')) {
      return true;
    }

    return _message(response).toLowerCase().contains('не найден');
  }

  /// Из исключения Dart вытаскиваем читаемую часть: `Exception: текст`.
  String _cleanUp(Object error) {
    final text = error.toString();

    return text.startsWith('Exception: ')
        ? text.substring('Exception: '.length)
        : text;
  }
}
