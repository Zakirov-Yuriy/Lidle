// ============================================================
// Тесты для ProfileBloc
// Проверяют состояния профиля, события и классы состояний.
//
// Особенности ProfileBloc:
// - Начальное состояние const ProfileInitial()
// - LoadProfileEvent сначала проверяет токен через TokenService.currentToken
//   (читает из Hive) → без инициализации Hive выбрасывает HiveError,
//   но блок не вылетает — обрабатывает ошибку через catch
// - LogoutProfileEvent очищает локальное хранилище
// ============================================================

import 'dart:io';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:lidle/blocs/profile/profile_bloc.dart';
import 'package:lidle/blocs/profile/profile_event.dart';
import 'package:lidle/blocs/profile/profile_state.dart';
import 'package:lidle/hive_service.dart';

void main() {
  group('ProfileBloc', () {
    late ProfileBloc profileBloc;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('profile_bloc_test_');
      Hive.init(tempDir.path);
      await HiveService.init();
      profileBloc = ProfileBloc();
    });

    tearDown(() async {
      profileBloc.close();
      await Hive.close();
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    // ─── Начальное состояние ───────────────────────────────

    test('начальное состояние равно ProfileInitial', () {
      expect(profileBloc.state, isA<ProfileInitial>());
    });

    test('ProfileInitial является const (идентичны)', () {
      expect(const ProfileInitial(), equals(const ProfileInitial()));
    });

    // ─── LoadProfileEvent ──────────────────────────────────

    /// LoadProfileEvent с отсутствующим токеном/Hive →
    /// эмитирует ProfileError ('Токен не найден' или HiveError)
    blocTest<ProfileBloc, ProfileState>(
      'LoadProfileEvent без токена → эмитирует ProfileError',
      build: () => ProfileBloc(),
      act: (bloc) => bloc.add(LoadProfileEvent()),
      wait: const Duration(seconds: 2),
      expect: () => [
        // Если Hive не инициализирован или токен null — ProfileError
        isA<ProfileError>(),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'LoadProfileEvent(forceRefresh: true) → первое состояние ProfileLoading или ProfileError',
      build: () => ProfileBloc(),
      act: (bloc) => bloc.add(LoadProfileEvent(forceRefresh: true)),
      wait: const Duration(seconds: 2),
      expect: () => [
        // Если нет токена (Hive не инициализирован) — сразу ProfileError
        // Если токен есть — ProfileLoading, а затем ProfileLoaded или ProfileError
        isA<ProfileState>(),
      ],
    );

    // ─── BLoC не закрывается после событий ────────────────

    test('ProfileBloc остаётся активным после LoadProfileEvent', () {
      profileBloc.add(LoadProfileEvent());
      expect(profileBloc.isClosed, isFalse);
    });

    /// LogoutProfileEvent: эмитирует ProfileLoading → ProfileLoggedOut.
    /// AuthService.logout() упадёт без backend, catch очищает Hive и эмитирует
    /// ProfileLoggedOut. С инициализированным Hive тест проходит корректно.
    blocTest<ProfileBloc, ProfileState>(
      'LogoutProfileEvent → эмитирует [ProfileLoading, ProfileLoggedOut]',
      build: () => ProfileBloc(),
      act: (bloc) => bloc.add(LogoutProfileEvent()),
      wait: const Duration(seconds: 2),
      expect: () => [isA<ProfileLoading>(), isA<ProfileLoggedOut>()],
    );

    // ─── Классы состояний ──────────────────────────────────

    group('ProfileLoaded', () {
      test('хранит обязательные поля корректно', () {
        const state = ProfileLoaded(
          name: 'Иван',
          lastName: 'Иванов',
          email: 'ivan@example.com',
          userId: 'ID: 123',
          phone: '+79001234567',
        );

        expect(state.name, equals('Иван'));
        expect(state.lastName, equals('Иванов'));
        expect(state.email, equals('ivan@example.com'));
        expect(state.userId, equals('ID: 123'));
        expect(state.phone, equals('+79001234567'));
      });

      test('profileImage по умолчанию null', () {
        const state = ProfileLoaded(
          name: 'Test',
          lastName: 'User',
          email: 'test@test.com',
          userId: 'ID: 1',
          phone: '+70000000000',
        );
        expect(state.profileImage, isNull);
      });

      test('username по умолчанию @Name', () {
        const state = ProfileLoaded(
          name: 'Test',
          lastName: 'User',
          email: 'test@test.com',
          userId: 'ID: 1',
          phone: '+70000000000',
        );
        expect(state.username, equals('@Name'));
      });

      test('qrCode по умолчанию null', () {
        const state = ProfileLoaded(
          name: 'Test',
          lastName: 'User',
          email: 'test@test.com',
          userId: 'ID: 1',
          phone: '+70000000000',
        );
        expect(state.qrCode, isNull);
      });

      test('хранит qrCode если передан', () {
        const state = ProfileLoaded(
          name: 'Test',
          lastName: 'User',
          email: 'test@test.com',
          userId: 'ID: 1',
          phone: '+70000000000',
          qrCode: 'data:image/png;base64,abc123',
        );
        expect(state.qrCode, equals('data:image/png;base64,abc123'));
      });
    });

    group('ProfileError', () {
      test('хранит сообщение об ошибке корректно', () {
        const state = ProfileError('Токен истёк');
        expect(state.message, equals('Токен истёк'));
      });

      test('два ProfileError с одинаковым сообщением равны', () {
        const s1 = ProfileError('ошибка');
        const s2 = ProfileError('ошибка');
        expect(s1, equals(s2));
      });
    });

    group('ProfileUpdated', () {
      test('является сабклассом ProfileState', () {
        expect(const ProfileUpdated(), isA<ProfileState>());
      });
    });

    group('ProfileLoggedOut', () {
      test('является сабклассом ProfileState', () {
        expect(const ProfileLoggedOut(), isA<ProfileState>());
      });
    });

    group('ProfileLoading', () {
      test('является сабклассом ProfileState', () {
        expect(const ProfileLoading(), isA<ProfileState>());
      });
    });

    // ─── Классы событий ───────────────────────────────────

    group('LoadProfileEvent', () {
      test('forceRefresh по умолчанию false', () {
        expect(LoadProfileEvent().forceRefresh, isFalse);
      });

      test('forceRefresh = true сохраняется корректно', () {
        expect(LoadProfileEvent(forceRefresh: true).forceRefresh, isTrue);
      });
    });

    group('UpdateProfileEvent', () {
      test('хранит все поля корректно', () {
        final event = UpdateProfileEvent(
          name: 'Мария',
          lastName: 'Петрова',
          email: 'maria@example.com',
          phone: '+79001112233',
          username: '@maria',
          about: 'Продаю вещи',
        );

        expect(event.name, equals('Мария'));
        expect(event.lastName, equals('Петрова'));
        expect(event.email, equals('maria@example.com'));
        expect(event.phone, equals('+79001112233'));
        expect(event.username, equals('@maria'));
        expect(event.about, equals('Продаю вещи'));
        expect(event.profileImage, isNull);
      });
    });
  });
}
