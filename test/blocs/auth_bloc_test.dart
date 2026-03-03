// ============================================================
// Тесты для AuthBloc
// Проверяют состояния аутентификации, события и переходы.
//
// Архитектурные принципы:
// - Используем bloc_test для детерминированной проверки последовательности состояний
// - Hive инициализируется во временной директории перед каждым тестом
// - Каждый тест — изолирован: отдельный AuthBloc в setUp
// ============================================================

import 'dart:io';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_event.dart';
import 'package:lidle/blocs/auth/auth_state.dart';
import 'package:lidle/hive_service.dart';

void main() {
  group('AuthBloc', () {
    late AuthBloc authBloc;
    late Directory tempDir;

    setUp(() async {
      // Инициализируем Hive во временной директории для изоляции тестов
      tempDir = await Directory.systemTemp.createTemp('auth_bloc_test_');
      Hive.init(tempDir.path);
      await HiveService.init();
      authBloc = AuthBloc();
    });

    tearDown(() async {
      authBloc.close();
      await Hive.close();
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    // ─── Начальное состояние ───────────────────────────────

    test('начальное состояние равно AuthInitial', () {
      expect(authBloc.state, isA<AuthInitial>());
    });

    // ─── TokenRefreshedEvent (pure transition, нет Hive/сети) ─────────

    /// Обработчик _onTokenRefreshed не делает никаких IO операций:
    /// просто emit(AuthAuthenticated(token: event.newToken)).
    /// Поэтому этот тест полностью детерминирован.
    blocTest<AuthBloc, AuthState>(
      'TokenRefreshedEvent → эмитирует [AuthAuthenticated] с новым токеном',
      build: () => AuthBloc(),
      act: (bloc) =>
          bloc.add(const TokenRefreshedEvent(newToken: 'fresh_token_xyz')),
      expect: () => [isA<AuthAuthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'TokenRefreshedEvent → токен в AuthAuthenticated соответствует переданному',
      build: () => AuthBloc(),
      act: (bloc) =>
          bloc.add(const TokenRefreshedEvent(newToken: 'my_secret_token')),
      verify: (bloc) {
        final state = bloc.state as AuthAuthenticated;
        expect(state.token, equals('my_secret_token'));
      },
    );

    // ─── CheckAuthStatusEvent ──────────────────────────────────────────

    /// Должен всегда начинать с AuthLoading, а затем либо
    /// AuthAuthenticated (если токен есть), AuthInitial (нет токена),
    /// или AuthError (если Hive не инициализирован).
    blocTest<AuthBloc, AuthState>(
      'CheckAuthStatusEvent → первое состояние всегда AuthLoading',
      build: () => AuthBloc(),
      act: (bloc) => bloc.add(const CheckAuthStatusEvent()),
      expect: () => [
        isA<AuthLoading>(),
        // Второе состояние зависит от среды (Hive): AuthInitial или AuthError
        isA<AuthState>(),
      ],
    );

    // ─── TokenExpiredEvent ─────────────────────────────────────────────

    blocTest<AuthBloc, AuthState>(
      'TokenExpiredEvent → в конечном итоге эмитирует AuthTokenExpired',
      build: () => AuthBloc(),
      act: (bloc) => bloc.add(const TokenExpiredEvent()),
      // Ждём дольше: обработчик делает try/await AuthService.logout() + Hive
      wait: const Duration(seconds: 2),
      expect: () => [isA<AuthTokenExpired>()],
    );

    // ─── Классы состояний ──────────────────────────────────────────────

    group('AuthAuthenticated', () {
      test('хранит токен корректно', () {
        final state = AuthAuthenticated(token: 'access_abc');
        expect(state.token, equals('access_abc'));
      });
    });

    group('AuthError', () {
      test('хранит сообщение об ошибке корректно', () {
        final state = AuthError(message: 'Неверный пароль');
        expect(state.message, equals('Неверный пароль'));
      });
    });

    group('AuthRegistered', () {
      test('хранит email корректно', () {
        final state = AuthRegistered(email: 'user@example.com');
        expect(state.email, equals('user@example.com'));
      });
    });

    // ─── BLoC не закрыт после добавления событий ──────────────────────

    test('BLoC остаётся активным после добавления LoginEvent', () {
      authBloc.add(
        LoginEvent(
          email: 'test@example.com',
          password: 'wrongpassword',
          remember: true,
        ),
      );
      expect(authBloc.isClosed, isFalse);
    });

    test('BLoC остаётся активным после добавления RegisterEvent', () {
      authBloc.add(
        RegisterEvent(
          name: 'Иван',
          lastName: 'Иванов',
          email: 'ivan@example.com',
          phone: '+79000000000',
          password: 'password123',
          passwordConfirmation: 'password123',
        ),
      );
      expect(authBloc.isClosed, isFalse);
    });
  });
}
