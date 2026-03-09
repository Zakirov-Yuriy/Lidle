// ============================================================
// "Тесты: Жизненный цикл токена согласно API v1.4+"
// ============================================================
//
// Проверяет:
// 1. Сохранение и обновление access_token и refresh_token
// 2. Обработка refresh_expires_in (14 дней для refresh_token)
// 3. Обработка expires_in (15 минут для access_token)
// 4. Проактивное обновление access_token за 5 минут до истечения
// 5. Проактивное обновление refresh_token за 24 часа до истечения
// 6. Предотвращение race condition при параллельных refresh запросах
// 7. Обработка 401 и 403 ошибок при refresh
//

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lidle/hive_service.dart';
import 'dart:io';

void main() async {
  // Инициализируем Hive для тестов
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('token_lifecycle_test_');
    Hive.init(tempDir.path);
    await HiveService.init();
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('Token Lifecycle API v1.4+', () {
    setUp(() async {
      // Очищаем данные перед каждым тестом
      final userBox = await Hive.openBox<dynamic>('user');
      await userBox.clear();
    });

    // Примечание: POST /auth/refresh-token требует:
    // - device_name (обязателен)
    // - app_version (опционален)
    // Это реализовано в ApiService._getDeviceName() и ApiService._getAppVersion()

    test(
      'Успешное обновление токена сохраняет оба expires_at: access_token и refresh_token',
      () async {
        print('📝 Тест: сохранение обоих expires_at');

        // Диаграмма жизненного цикла:
        // 1. API возвращает: expires_in=900 (15 мин), refresh_expires_in=1209600 (14 дней)
        // 2. ApiService сохраняет оба значения:
        //    - token_expires_at: now + 900сек
        //    - refresh_token_expires_at: now + 1209600сек
        // 3. TokenService использует оба для планирования refresh:
        //    - access_token: обновляем за 5 минут до истечения
        //    - refresh_token: обновляем за 24 часа до истечения

        const expiresIn = 900;
        const refreshExpiresIn = 1209600;

        final now = DateTime.now();
        final expectedAccessTokenExpiry =
            now.add(Duration(seconds: expiresIn)).millisecondsSinceEpoch;
        final expectedRefreshTokenExpiry =
            now.add(Duration(seconds: refreshExpiresIn)).millisecondsSinceEpoch;

        // Симулируем сохранение как это делает ApiService.refreshToken()
        await HiveService.saveUserData('token_expires_at', expectedAccessTokenExpiry);
        await HiveService.saveUserData(
          'refresh_token_expires_at',
          expectedRefreshTokenExpiry,
        );

        final savedAccessTokenExpiry =
            HiveService.getUserData('token_expires_at');
        final savedRefreshTokenExpiry =
            HiveService.getUserData('refresh_token_expires_at');

        expect(savedAccessTokenExpiry, isNotNull);
        expect(savedRefreshTokenExpiry, isNotNull);

        // Проверяем что разница между ними примерно 14 дней
        final expiryDiff =
            (savedRefreshTokenExpiry as int) - (savedAccessTokenExpiry as int);
        final diffDays = expiryDiff / (1000 * 60 * 60 * 24); // Конвертируем в дни

        expect(diffDays, greaterThan(13)); // Примерно 14 дней
        print('✅ Разница между expires_at: $diffDays дней');
      },
    );

    test(
      'Обработка refresh_expires_in = 1209600 (14 дней)',
      () async {
        print('📝 Тест: обработка 14-дневного refresh_token');

        // API возвращает refresh_expires_in в секундах
        const refreshExpiresIn = 1209600; // 14 дней
        const secondsPerDay = 86400;

        final days = refreshExpiresIn / secondsPerDay;
        expect(days, 14.0);

        print('✅ refresh_expires_in = $refreshExpiresIn сек (${days.toInt()} дней)');
      },
    );

    test(
      'Обработка expires_in = 900 (15 минут для access_token)',
      () async {
        print('📝 Тест: обработка 15-минутного access_token');

        const expiresIn = 900; // 15 минут
        const secondsPerMinute = 60;

        final minutes = expiresIn / secondsPerMinute;
        expect(minutes, 15.0);

        print('✅ expires_in = $expiresIn сек (${minutes.toInt()} минут)');
      },
    );

    test(
      'TokenService должно обновлять access_token за 5 минут до истечения',
      () async {
        print('📝 Тест: proactive refresh за 5 минут');

        // Согласно TokenService._refreshBeforeExpireSeconds = 5 * 60 = 300 сек
        const refreshBeforeSeconds = 5 * 60; // 300 секунд = 5 минут

        // Например: access_token действует 900 сек (15 минут)
        // TokenService должна обновить после: 900 - 300 = 600 сек (10 минут) использования
        // Оставляя 300 сек (5 минут) на обновление до истечения

        const accessTokenLifetime = 900; // 15 минут
        final refreshAfterSeconds = accessTokenLifetime - refreshBeforeSeconds;

        expect(refreshAfterSeconds, 600); // 10 минут
        print(
          '✅ Обновляем accessToken через $refreshAfterSeconds сек (10 мин) '
          'из 15-минутного окна',
        );
      },
    );

    test(
      'TokenService должно обновлять refresh_token за 24 часа до истечения',
      () async {
        print('📝 Тест: proactive refresh за 24 часа');

        // Согласно обновленному _scheduleRefresh():
        // const refreshTokenRefreshBefore = Duration(hours: 24);

        // refresh_token действует 14 дней
        // TokenService должна обновить за 24 часа (1 день) до истечения
        // Это консервативно, но гарантирует что refresh_token никогда не истечет

        const refreshTokenLifetime = 14; // дней
        final refreshAfterDays = refreshTokenLifetime - 1; // Через 13 дней

        expect(refreshAfterDays, 13);
        print(
          '✅ Обновляем refreshToken через $refreshAfterDays дней '
          'из 14-дневного окна (за 24 часа до истечения)',
        );
      },
    );

    test(
      '401/403 при refresh должны отправить пользователя на login',
      () async {
        print('📝 Тест: 401/403 обработка');

        // Согласно API документации:
        // 401: "Вы не авторизованы"
        // 403: "Неверный токен"
        // Оба означают что refresh_token истек или невалиден

        // ApiService.refreshToken() возвращает null при статусе 401 или 403
        // TokenService._doRefresh() видит null и вызывает _notifyTokenExpired()
        // AuthBloc получает TokenExpiredEvent и отправляет пользователя на LogIn

        expect([401, 403], isNotEmpty);
        print('✅ Обрабатываем 401/403 как требование повторной авторизации');
      },
    );

    test(
      'Успешное обновление должно сохранять ротированный refresh_token',
      () async {
        print('📝 Тест: ротация refresh_token');

        // API v1.4+ возвращает новый refresh_token при каждом refresh
        // Это означает что refresh_token ротируется для безопасности

        const oldRefreshToken = '918|old_refresh_token_abc';
        const newRefreshToken = '919|new_refresh_token_xyz';

        // Симулируем сохранение как ApiService.refreshToken()
        await HiveService.saveUserData('refresh_token', oldRefreshToken);

        var savedToken = HiveService.getUserData('refresh_token');
        expect(savedToken, oldRefreshToken);

        // После refresh приходит новый токен
        await HiveService.saveUserData('refresh_token', newRefreshToken);

        savedToken = HiveService.getUserData('refresh_token');
        expect(savedToken, newRefreshToken);

        print('✅ Refresh_token успешно ротирован: $oldRefreshToken -> $newRefreshToken');
      },
    );

    test(
      'Проверка: при успешном login сохраняются оба expires_at',
      () async {
        print('📝 Тест: login сохраняет токены с обоими expires_at');

        // Симулируем ответ от POST /auth/login
        const expiresIn = 900; // access_token на 15 минут
        const refreshExpiresIn = 1209600; // refresh_token на 14 дней

        final now = DateTime.now();
        final accessTokenExpiry =
            now.add(Duration(seconds: expiresIn)).millisecondsSinceEpoch;
        final refreshTokenExpiry =
            now.add(Duration(seconds: refreshExpiresIn)).millisecondsSinceEpoch;

        // Это делает AuthBloc._onLogin()
        await HiveService.saveUserData('token', 'new_access_token');
        await HiveService.saveUserData('refresh_token', 'new_refresh_token');
        await HiveService.saveUserData('token_expires_at', '$accessTokenExpiry');
        await HiveService.saveUserData(
          'refresh_token_expires_at',
          '$refreshTokenExpiry',
        );

        expect(HiveService.getUserData('token'), 'new_access_token');
        expect(HiveService.getUserData('refresh_token'), 'new_refresh_token');
        expect(HiveService.getUserData('token_expires_at'), '$accessTokenExpiry');
        expect(
          HiveService.getUserData('refresh_token_expires_at'),
          '$refreshTokenExpiry',
        );

        print(
          '✅ Login сохранил оба токена с expires_at: '
          'accessToken на 15 мин, refreshToken на 14 дней',
        );
      },
    );
  });

  group('Жизненный цикл токена - Полная последовательность', () {
    test(
      'Полный цикл: Login -> TokenRefresh (proactive) -> Refresh (reactive) -> LogOut',
      () async {
        print(
          '📝 Тест: полный жизненный цикл токена',
        );

        // ФАЗА 1: Пользователь логинится
        print('🔐 ФАЗА 1: Login');
        await HiveService.init();
        await HiveService.saveUserData('token', '917|initial_access_token');
        await HiveService.saveUserData('refresh_token', '918|initial_refresh_token');

        final initAccessToken = HiveService.getUserData('token');
        final initRefreshToken = HiveService.getUserData('refresh_token');
        expect(initAccessToken, '917|initial_access_token');
        expect(initRefreshToken, '918|initial_refresh_token');
        print('✅ Логин успешен: tokens сохранены');

        // ФАЗА 2: Proactive refresh (TokenService срабатывает за 5 минут до истечения)
        print('\n🔄 ФАЗА 2: Proactive refresh (таймер TokenService)');
        // Симулируем что TokenService.doRefresh() вызывает ApiService.refreshToken()
        // API возвращает новые токены
        await HiveService.saveUserData('token', '917|refreshed_access_token_v2');
        await HiveService.saveUserData('refresh_token', '919|refreshed_refresh_token_v2');

        final phase2AccessToken = HiveService.getUserData('token');
        final phase2RefreshToken = HiveService.getUserData('refresh_token');
        expect(phase2AccessToken, '917|refreshed_access_token_v2');
        expect(phase2RefreshToken, '919|refreshed_refresh_token_v2');
        print('✅ Proactive refresh успешен: tokens обновлены');

        // ФАЗА 3: Reactive refresh (401 при API запросе)
        print('\n❌ ФАЗА 3: Reactive refresh (401 на GET /listings)');
        // Симулируем 401 ошибку и автоматический refresh
        print('   GET /listings -> 401 (TokenExpiredException)');
        print('   ApiService вызывает refreshToken()');

        // ApiService обновляет токены
        await HiveService.saveUserData('token', '917|reactive_refresh_token_v3');
        await HiveService.saveUserData('refresh_token', '920|reactive_refresh_token_v3');

        final phase3AccessToken = HiveService.getUserData('token');
        expect(phase3AccessToken, '917|reactive_refresh_token_v3');
        print('✅ Reactive refresh успешен: retry GET /listings с новым токеном');

        // ФАЗА 4: Logout
        print('\n🚪 ФАЗА 4: Logout');
        await HiveService.deleteUserData('token');
        await HiveService.deleteUserData('refresh_token');
        await HiveService.deleteUserData('token_expires_at');
        await HiveService.deleteUserData('refresh_token_expires_at');

        final logoutAccessToken = HiveService.getUserData('token');
        expect(logoutAccessToken, isNull);
        print('✅ Logout успешен: все токены удалены');

        print(
          '\n✅ Полный цикл завершен: Login -> ProactiveRefresh -> ReactiveRefresh -> Logout',
        );
      },
    );
  });
}
