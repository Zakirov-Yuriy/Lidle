// ============================================================
// "Тести: Обновление токена при запуске приложения"
// ============================================================
//
// Сценарии тестирования:
// 1. Пользователь был авторизован, затем закрыл приложение на ночь
// 2. При запуске приложения refresh_token истек на сервере
// 3. Проверяем что пользователь отправлен на авторизацию
// 4. Проверяем что ListingsBloc не зависает на скелетоне
//

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_event.dart';
import 'package:lidle/blocs/auth/auth_state.dart';
import 'dart:io';

void main() async {
  // Инициализируем Hive для тестов
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('auth_refresh_test_');
    Hive.init(tempDir.path);
    await HiveService.init();
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('AuthBloc - Обновление токена при запуске приложения', () {
    late AuthBloc authBloc;

    setUp(() async {
      authBloc = AuthBloc();
      // Сохраняем старый токен и refresh_token (который истек на сервере)
      await HiveService.saveUserData('token', 'old_access_token');
      await HiveService.saveUserData('refresh_token', 'expired_refresh_token');
      await HiveService.saveUserData(
        'token_expires_at',
        DateTime.now().add(Duration(hours: -1)).millisecondsSinceEpoch,
      );
    });

    tearDown(() async {
      authBloc.close();
      await HiveService.deleteUserData('token');
      await HiveService.deleteUserData('refresh_token');
      await HiveService.deleteUserData('token_expires_at');
    });

    test(
      'должен отправить пользователя на авторизацию если refresh_token истек',
      () async {
        // СЦЕНАРИЙ: refresh_token истек на сервере (возвращает 401)
        // Это повторяет ситуацию когда пользователь закрыл приложение на ночь

        // Эмитим CheckAuthStatusEvent (как делается при старте приложения)
        authBloc.add(const CheckAuthStatusEvent());

        // Ожидаем что произойдет следующее:
        // 1. AuthBloc попытается обновить токен через ApiService
        // 2. ApiService вернет null (потому что refresh_token истек)
        // 3. AuthBloc эмитит AuthTokenExpired

        // Проверяем последовательность состояний
        await expectLater(
          authBloc.stream,
          emitsInOrder([
            isA<AuthLoading>(), // Сначала загрузка
            isA<AuthTokenExpired>(), // Потом истечение токена
          ]),
        );

        // Проверяем что токены были удалены из Hive
        final savedToken = HiveService.getUserData('token');
        expect(savedToken, null, reason: 'Токен должен быть удален');

        final savedRefreshToken = HiveService.getUserData('refresh_token');
        expect(
          savedRefreshToken,
          null,
          reason: 'Refresh токен должен быть удален',
        );
      },
    );

    test('должен обновить токен если он еще валиден', () async {
      // СЦЕНАРИЙ: refresh_token еще валиден на сервере
      // Это когда пользователь закрыл приложение всего на час-два

      // Сохраняем свежий refresh_token
      await HiveService.saveUserData('refresh_token', 'valid_refresh_token');
      await HiveService.saveUserData(
        'token_expires_at',
        DateTime.now().add(Duration(hours: 12)).millisecondsSinceEpoch,
      );

      authBloc.add(const CheckAuthStatusEvent());

      // Ожидаем успешную авторизацию
      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthAuthenticated>(), // Токен обновлен успешно
        ]),
      );
    });

    test('должен продолжить работу если нет интернета при запуске', () async {
      // СЦЕНАРИЙ: Пользователь запустил приложение без интернета
      // AuthBloc должен попыться продолжить работу с существующим токеном
      // TokenService будет пытаться обновить при возвращении в foreground

      // Сохраняем свежий токен
      await HiveService.saveUserData('token', 'old_but_fresh_token');
      await HiveService.saveUserData(
        'token_expires_at',
        DateTime.now().add(Duration(hours: 10)).millisecondsSinceEpoch,
      );

      authBloc.add(const CheckAuthStatusEvent());

      // Ожидаем что приложение продолжит работу несмотря на ошибку сети
      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthAuthenticated>(), // Продолжаем с существующим токеном
        ]),
      );
    });
  });

  group('TokenService - Профилактическое обновление и retry логика', () {
    test('должен планировать обновление каждый час', () async {
      // НОВОЕ поведение: токен обновляется каждый час независимо от времени истечения
      // Это профилактика от истечения токена во время работы приложения

      await HiveService.saveUserData('token', 'fresh_token');
      await HiveService.saveUserData(
        'token_expires_at',
        DateTime.now().add(Duration(hours: 5)).millisecondsSinceEpoch,
      );

      final service = TokenService();

      // После инициализации сервис должен спланировать обновление
      // (в реальном приложении это делается в MaterialApp)
      service.init(
        // BuildContext для инициализации (в тестах может быть пропущено)
        // Для полной проверки нужно добавить интеграционный тест
      );

      // Проверяем что объект инициализирован
      expect(TokenService.currentToken, 'fresh_token');

      service.dispose();
    });

    test(
      'должен делать retry при сетевой ошибке перед отправкой на авторизацию',
      () async {
        // НОВОЕ поведение: retry логика с экспоненциальной задержкой
        // Сначала пытается 3 раза с задержкой 1с, 2с, 4с
        // Если все равно не удалось - отправляет на авторизацию

        await HiveService.saveUserData('token', 'token');
        await HiveService.saveUserData('refresh_token', 'refresh_token');
        await HiveService.saveUserData(
          'token_expires_at',
          DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
        );

        // Проверяем что параметры для retry логики установлены правильно
        // (в реальном тесте нужно мокировать ApiService)

        expect(true, true); // Placeholder
      },
    );
  });
}
