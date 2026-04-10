// ============================================================
// "Bloc: Управление состоянием аутентификации"
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/token_service.dart';
import '../../services/user_service.dart';
import '../../pages/profile_menu/profile_menu_screen.dart'; // 🧹 Для очистки кеша профиля при logout
import '../../pages/profile_menu/settings/settings_screen.dart'; // 🧹 Для очистки кеша настроек при logout
import '../../pages/profile_menu/settings/contact_data/contact_data_screen.dart'; // 🧹 Для очистки кеша контактных данных при logout
import 'package:lidle/core/logger.dart';

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
      );

      // API v1.3.3+: ответ содержит access_token и refresh_token
      final token =
          response['data']?['access_token'] ??
          response['data']?['token'] ??
          response['access_token'] ??
          response['token'];
      if (token != null) {
        // Очищаем данные предыдущего пользователя перед сохранением новых.
        // Это гарантирует, что profile_dashboard никогда не покажет данные
        // старой сессии при входе под другим аккаунтом.
        await UserService.clearLocalProfileData();

        await UserService.saveLocal('token', token);

        // Сохраняем refresh_token для дальнейшего обновления access_token
        final refreshToken =
            response['data']?['refresh_token'] ?? response['refresh_token'];
        if (refreshToken != null) {
          await UserService.saveLocal('refresh_token', refreshToken);
        }

        // ОБНОВЛЕНО: Сохраняем время истечения access_token И refresh_token для TokenService.
        // Sanctum opaque токены (формат "153|abc...") — не JWT, нельзя декодировать exp.
        // Поэтому сохраняем expires_at из ответа API, чтобы TokenService мог
        // запустить таймер refresh за 5 минут до истечения access_token.
        // И за 24 часа до истечения refresh_token (критично для пользователя).
        // ИСПРАВЛЕНИЕ: Сохраняем как INT (миллисекунды), как и в apiService.refreshToken()
        // Это обеспечивает консистентность типов и избегает ошибок приведения типов
        
        // Access token expiry (обычно 900 сек = 15 минут)
        final expiresIn =
            ((response['data']?['expires_in'] ?? response['expires_in'])
                    as num?)
                ?.toInt() ??
            900;
        final expiresAtMs = DateTime.now()
            .add(Duration(seconds: expiresIn))
            .millisecondsSinceEpoch;
        await UserService.saveLocal('token_expires_at', expiresAtMs);

        // ОБНОВЛЕНО: Refresh token expiry (обычно 1209600 сек = 14 дней)
        // Это критично! Если refresh_token истечет, пользователь потеряет доступ
        final refreshExpiresIn =
            ((response['data']?['refresh_expires_in'] ??
                    response['refresh_expires_in']) as num?)
                ?.toInt() ??
            1209600; // По документации API: 1209600 сек (14 дней)
        final refreshExpiresAtMs = DateTime.now()
            .add(Duration(seconds: refreshExpiresIn))
            .millisecondsSinceEpoch;
        await UserService.saveLocal('refresh_token_expires_at', refreshExpiresAtMs);

        // log.d(
        //   '✅ auth_bloc: сохранены токены - access_token действует ${expiresIn ~/ 60}мин, '
        //   'refresh_token действует ${refreshExpiresIn ~/ 86400} дней',
        // );

        // Сохраняем возможные данные пользователя из ответа сразу локально
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
            await UserService.saveLocal('name', userData['name'] ?? '');
          }
          if (userData.containsKey('email')) {
            await UserService.saveLocal('email', userData['email'] ?? '');
          }
          if (userData.containsKey('phone')) {
            await UserService.saveLocal('phone', userData['phone'] ?? '');
          }
          if (userData.containsKey('id')) {
            await UserService.saveLocal('userId', '${userData['id']}');
          }
          if (userData.containsKey('username')) {
            await UserService.saveLocal('username', userData['username'] ?? '');
          }
          if (userData.containsKey('avatar')) {
            await UserService.saveLocal(
              'profileImage',
              userData['avatar'] ?? '',
            );
          }
        }

        emit(AuthAuthenticated(token: token));
      } else {
        // 📧 Проверяем если это ошибка неверифицированного email (423)
        if (response['error'] == 'email_not_verified' ||
            response['error_code'] == 'email_not_verified') {
          // email не верифицирован — перенаправляем на экран верификации
          emit(AuthEmailNotVerified(email: event.email));
        } else {
          // success: false — используем сообщение сервера
          final serverMessage =
              response['message'] as String? ?? 'Неверные учетные данные';
          emit(AuthError(message: serverMessage));
        }
      }
    } catch (e) {
      // Специальная обработка TokenExpiredException для неправильных учетных данных
      if (e is TokenExpiredException) {
        emit(AuthError(message: e.message));
      } else {
        // Для других ошибок извлекаем понятное сообщение
        String errorMessage = 'Ошибка при входе в систему';

        if (e is Exception) {
          final errorStr = e.toString();
          // Парсим сообщение из Exception
          if (errorStr.contains('Exception: ')) {
            errorMessage = errorStr.replaceAll('Exception: ', '');
          } else {
            errorMessage = errorStr;
          }
        }

        emit(AuthError(message: errorMessage));
      }
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

      // API v1.3.3+: регистрация больше не возвращает токен —
      // ответ: { "success": true, "message": "...Подтвердите е-майл" }
      final success = response['success'] == true;
      if (success) {
        // Сохраняем флаг: email ещё не подтверждён
        await UserService.saveLocal('isEmailVerified', 'false');
        emit(AuthRegistered(email: event.email));
      } else {
        final message =
            response['message'] as String? ?? 'Ошибка при регистрации';
        emit(AuthError(message: message));
      }
    } catch (e) {
      // Специальная обработка TokenExpiredException
      if (e is TokenExpiredException) {
        emit(AuthError(message: e.message));
      } else {
        // Для других ошибок извлекаем понятное сообщение
        String errorMessage = 'Ошибка при регистрации';

        if (e is Exception) {
          final errorStr = e.toString();
          if (errorStr.contains('Exception: ')) {
            errorMessage = errorStr.replaceAll('Exception: ', '');
          } else {
            errorMessage = errorStr;
          }
        }

        emit(AuthError(message: errorMessage));
      }
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
      // Специальная обработка TokenExpiredException
      if (e is TokenExpiredException) {
        emit(AuthError(message: e.message));
      } else {
        String errorMessage = 'Ошибка при верификации email';

        if (e is Exception) {
          final errorStr = e.toString();
          if (errorStr.contains('Exception: ')) {
            errorMessage = errorStr.replaceAll('Exception: ', '');
          } else {
            errorMessage = errorStr;
          }
        }

        emit(AuthError(message: errorMessage));
      }
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
      // 🧹 ОПТИМИЗАЦИЯ: Очищаем кеши экранов при logout
      ProfileMenuScreen.clearCache();
      SettingsScreen.clearCache();
      ContactDataScreen.clearCache();
      
      // AuthService.logout() сам удаляет токены из Hive
      await AuthService.logout();
      // Очищаем весь профиль и кеши — следующий пользователь увидит свои данные
      await UserService.clearLocalProfileData();
      emit(AuthLoggedOut());
    } catch (e) {
      // 🧹 ОПТИМИЗАЦИЯ: Очищаем кеши экранов даже при ошибке
      ProfileMenuScreen.clearCache();
      SettingsScreen.clearCache();
      ContactDataScreen.clearCache();
      
      // Даже если logout на сервере не удался, очищаем данные локально
      await UserService.deleteLocal('token');
      await UserService.deleteLocal('refresh_token');
      await UserService.clearLocalProfileData();
      emit(AuthLoggedOut());
    }
  }

  /// Обработчик события проверки статуса аутентификации.
  /// Обработчик события проверки статуса авторизации при запуске приложения.
  ///
  /// При запуске приложения проверяет наличие токена в локальном хранилище.
  /// 🚀 ОПТИМИЗАЦИЯ: Проверяет TTL токена перед профилактическим refresh.
  /// Если токен еще действителен более чем на 5 минут, refresh пропускается.
  /// Если токен истекает в ближайшие 5 минут - выполняется условный refresh.
  /// Если токен полностью истек - отправляем на авторизацию.
  ///
  /// Это критично для пользователей, закрывших приложение на ночь:
  /// токен мог истечь за ночь, и мы должны это узнать ДО того как начнут
  /// загружаться данные (ListingsBloc, ProfileBloc, etc.).
  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final token = TokenService.currentToken;
      if (token != null && token.isNotEmpty) {
        // 🚀 ОПТИМИЗАЦИЯ: Проверяем TTL перед обновлением
        // Если токен еще валиден более чем на 5 минут - не обновляем
        final tokenExpiresAtData = await UserService.getLocal('token_expires_at');
        final refreshThresholdMs = 5 * 60 * 1000; // 5 минут в миллисекундах
        
        bool shouldRefresh = true; // По умолчанию обновляем
        
        if (tokenExpiresAtData != null) {
          try {
            // Обрабатываем оба типа: int (новый формат) и String (старый формат)
            final tokenExpiresAtMs = tokenExpiresAtData is int
                ? tokenExpiresAtData
                : int.parse(tokenExpiresAtData.toString());
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            final timeUntilExpiryMs = tokenExpiresAtMs - nowMs;
            
            if (timeUntilExpiryMs > refreshThresholdMs) {
              // Токен еще действителен более чем на 5 минут - не обновляем
              shouldRefresh = false;
              final minutesRemaining = timeUntilExpiryMs ~/ (60 * 1000);
              // log.d('✅ AuthBloc: токен еще действителен, обновление пропущено ($minutesRemaining мин осталось)');
            } else if (timeUntilExpiryMs > 0) {
              // Токен истекает в ближайшие 5 минут - обновляем профилактически
              // log.d('⚠️  AuthBloc: токен истекает скоро, выполняем профилактический refresh');
              shouldRefresh = true;
            } else {
              // Токен полностью истек - обновляем обязательно
              // log.d('❌ AuthBloc: токен полностью истек');
              shouldRefresh = true;
            }
          } catch (_) {
            // Ошибка парсинга - по умолчанию обновляем
            shouldRefresh = true;
          }
        }

        // Если обновление требуется
        if (shouldRefresh) {
          // ИСПРАВЛЕНИЕ: Передаем refresh_token вместо access_token для обновления.
          // ApiService.refreshToken() использует refresh_token из Hive, но мы проверяем его первым.
          final refreshToken = await UserService.getLocal('refresh_token') as String?;
          if (refreshToken == null || refreshToken.isEmpty) {
            // log.d(
            //   '⚠️  AuthBloc: refresh_token не найден, отправляем на авторизацию (первый запуск?)',
            // );
            await AuthService.logout();
            await UserService.deleteLocal('token');
            await UserService.deleteLocal('refresh_token');
            await UserService.clearLocalProfileData();
            emit(AuthInitial());
            return;
          }

          final newToken = await ApiService.refreshToken(token);
          if (newToken != null && newToken.isNotEmpty) {
            // Успешно обновили токен — эмитируем AuthAuthenticated
            // Это запустит TokenService.init() в BlocListener, который будет
            // периодически обновлять токен согласно его таймеру.
            // log.d('✅ AuthBloc: токен успешно обновлен при запуске приложения');
            emit(AuthAuthenticated(token: newToken));
          } else {
            // Refresh не сработал (401/403 на сервере) — refresh_token истёк
            // или невалиден. Отправляем пользователя на авторизацию.
            // log.d(
            //   '❌ AuthBloc: refresh токена не сработал, отправляем на авторизацию',
            // );
            await AuthService.logout();
            await UserService.deleteLocal('token');
            await UserService.deleteLocal('refresh_token');
            await UserService.clearLocalProfileData();
            emit(AuthTokenExpired());
          }
        } else {
          // Токен еще валиден - продолжаем работу
          emit(AuthAuthenticated(token: token));
        }
      } else {
        // Нет сохраненного токена — первый запуск или logout
        emit(AuthInitial());
      }
    } catch (e) {
      // Сетевая ошибка при попытке refresh — это может быть временная проблема
      // или пользователь без интернета. В этом случае эмитируем AuthAuthenticated
      // чтобы приложение попыталось продолжить работу с наличным токеном.
      // TokenService.init() будет пытаться обновить токен при возвращении в foreground.
      // log.d(
      //   '⚠️  AuthBloc: сетевая ошибка при обновлении токена при запуске: $e',
      // );
      final token = TokenService.currentToken;
      if (token != null && token.isNotEmpty) {
        // log.d('⚠️  AuthBloc: продолжаем работу с существующим токеном...');
        emit(AuthAuthenticated(token: token));
      } else {
        emit(AuthError(message: e.toString()));
      }
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
    // log.d('🔐 AuthBloc: токен истёк, выполняем принудительный logout...');
    try {
      await AuthService.logout();
    } catch (_) {}
    // Очищаем токены и весь профиль из локального хранилища
    await UserService.deleteLocal('token');
    await UserService.deleteLocal('refresh_token');
    await UserService.clearLocalProfileData();
    // log.d('🔐 AuthBloc: токены удалены, переходим на экран входа');
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
    // log.d('✅ AuthBloc: токен обновлён в фоне: ${event.newToken.substring(0, 20)}...');
    // Токен уже сохранён в Hive через ApiService.refreshToken()
    // Просто обновляем состояние с новым токеном
    emit(AuthAuthenticated(token: event.newToken));
  }
}
