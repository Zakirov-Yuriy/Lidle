import 'package:flutter_bloc/flutter_bloc.dart';
import 'profile_event.dart';
import 'profile_state.dart';
import '../../services/token_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../core/cache/cache_service.dart';
import '../../core/cache/cache_keys.dart';
import 'package:lidle/core/logger.dart';

/// Bloc для управления состоянием профиля пользователя.
/// Обрабатывает события загрузки, обновления и выхода из профиля.
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  /// Конструктор ProfileBloc.
  /// Инициализирует Bloc с начальным состоянием ProfileInitial.
  ProfileBloc() : super(const ProfileInitial()) {
    on<LoadProfileEvent>(_onLoadProfile);
    on<UpdateProfileEvent>(_onUpdateProfile);
    on<LogoutProfileEvent>(_onLogoutProfile);
  }

  /// Обработчик события загрузки профиля.
  /// Загружает данные пользователя из API и сохраняет в локальное хранилище.
  Future<void> _onLoadProfile(
    LoadProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      final token = TokenService.currentToken;
      // log.d('🔑 Token from Hive: $token');
      if (token == null) {
        // log.d('❌ Токен не найден!');
        emit(const ProfileError('Токен не найден'));
        return;
      }

      if (token.isEmpty) {
        // log.d('❌ Токен пуст!');
        emit(const ProfileError('Токен пуст'));
        return;
      }

      // Если forceRefresh = true, сразу показываем загрузку
      if (event.forceRefresh) {
        // Инвалидируем L1-кеш профиля при принудительном обновлении
        AppCacheService().invalidate(CacheKeys.profileData);
        emit(const ProfileLoading());
      } else {
        // 📖 Сначала проверяем L1-кеш (быстрее, чем читать из Hive)
        final cachedProfile = AppCacheService().get<Map<String, dynamic>>(
          CacheKeys.profileData,
        );
        if (cachedProfile != null) {
          emit(
            ProfileLoaded(
              name: cachedProfile['name'] as String? ?? 'Пользователь',
              lastName: cachedProfile['lastName'] as String? ?? '',
              email: cachedProfile['email'] as String? ?? '',
              userId: cachedProfile['userId'] as String? ?? 'ID: 0',
              phone: cachedProfile['phone'] as String? ?? '',
              profileImage: cachedProfile['profileImage'],
              username: cachedProfile['username'] as String? ?? '@User',
              about: cachedProfile['about'],
              qrCode: cachedProfile['qrCode'],
            ),
          );
          return;
        }
        // L1 пуст — читаем из Hive (fallback).
        // Иначе показываем данные из Hive (если есть)
        final cachedName = UserService.getLocal('name') ?? 'Пользователь';
        final cachedLastName = UserService.getLocal('lastName') ?? '';
        final cachedEmail = UserService.getLocal('email') ?? 'user@example.com';
        final cachedPhone =
            UserService.getLocal('phone') ?? '+7 (999) 123-45-67';
        // Получаем userId из локального хранилища с дефолтом ID: 0
        final cachedUserIdRaw = UserService.getLocal('userId');
        final cachedUserId =
            cachedUserIdRaw != null && cachedUserIdRaw.isNotEmpty
            ? 'ID: $cachedUserIdRaw'
            : 'ID: 0';
        final cachedProfileImage = UserService.getLocal('profileImage');
        final cachedUsername = UserService.getLocal('username') ?? '@User';
        final cachedAbout = UserService.getLocal('about');

        // Если есть данные в Hive — показываем их
        if (cachedName.isNotEmpty && cachedName != 'Пользователь') {
          emit(
            ProfileLoaded(
              name: cachedLastName.isNotEmpty
                  ? '$cachedName $cachedLastName'
                  : cachedName,
              lastName: cachedLastName,
              email: cachedEmail,
              userId: cachedUserId,
              phone: cachedPhone,
              profileImage: cachedProfileImage,
              username: cachedUsername,
              about: cachedAbout,
            ),
          );
        } else {
          emit(const ProfileLoading());
        }
      }

      // Загружаем свежие данные с API
      final profile = await UserService.getProfile(token: token);

      // Сохраняем данные локально
      await UserService.saveLocal('name', profile.name);
      await UserService.saveLocal('lastName', profile.lastName);
      await UserService.saveLocal('email', profile.email);
      await UserService.saveLocal('phone', profile.phone ?? '');
      // Берём userId из ответа API (profile.id).
      // Fallback на JWT-декодирование только если API вернул null
      // (Sanctum opaque токены не содержат sub, поэтому extractUserIdFromToken → '0').
      final userIdString = profile.id != null
          ? profile.id.toString()
          : AuthService.extractUserIdFromToken(token);
      await UserService.saveLocal('userId', userIdString);
      await UserService.saveLocal('profileImage', profile.avatar);
      await UserService.saveLocal(
        'username',
        profile.nickname ?? '@${profile.name}',
      );
      await UserService.saveLocal('about', profile.about ?? '');

      // Извлекаем base64 QR код из ответа API
      String? qrCodeBase64;
      if (profile.qrCode != null && profile.qrCode is Map<String, dynamic>) {
        qrCodeBase64 = profile.qrCode!['value'] as String?;
        if (qrCodeBase64 != null) {
          await UserService.saveLocal('qrCode', qrCodeBase64);
          // log.d('✅ QR код сохранен в Hive');
        }
      }

      // log.d('💾 Данные сохранены в Hive');

      // 💾 Сохраняем свежие данные в L1-кеш профиля (TTL 5 мин)
      AppCacheService().set<Map<String, dynamic>>(CacheKeys.profileData, {
        'name': '${profile.name} ${profile.lastName}',
        'lastName': profile.lastName,
        'email': profile.email,
        'userId': 'ID: $userIdString',
        'phone': profile.phone ?? '',
        'profileImage': profile.avatar,
        'username': profile.nickname ?? '@${profile.name}',
        'about': profile.about,
        'qrCode': qrCodeBase64,
      });

      // Показываем свежие данные
      final userIdDisplay = 'ID: $userIdString';
      final displayName = '${profile.name} ${profile.lastName}';

      // log.d('🔍 DEBUG ProfileBloc._onLoadProfile():');
      // log.d('   - profile.name = "${profile.name}"');
      // log.d('   - profile.lastName = "${profile.lastName}"');
      // log.d('   - displayName (for UI) = "$displayName"');

      emit(
        ProfileLoaded(
          name: displayName,
          lastName: profile.lastName,
          email: profile.email,
          userId: userIdDisplay,
          phone: profile.phone ?? '+7 (999) 123-45-67',
          profileImage: profile.avatar,
          username: profile.nickname ?? '@${profile.name}',
          about: profile.about,
          qrCode: qrCodeBase64,
        ),
      );
    } catch (e) {
      // log.d('❌ Ошибка загрузки профиля: $e');
      // log.d('📍 Stack trace: ${StackTrace.current}');

      // Fallback to local data if API fails
      final name = UserService.getLocal('name') ?? 'Пользователь';
      final lastName = UserService.getLocal('lastName') ?? '';
      final email = UserService.getLocal('email') ?? 'user@example.com';
      final phone = UserService.getLocal('phone') ?? '+7 (999) 123-45-67';
      final userId = UserService.getLocal('userId') ?? 'ID: 0';
      final profileImage = UserService.getLocal('profileImage');
      final username = UserService.getLocal('username') ?? '@User';
      final about = UserService.getLocal('about');
      final qrCode = UserService.getLocal('qrCode');

      // log.d('📖 Fallback: Используем данные из Hive: $name $lastName');

      emit(
        ProfileLoaded(
          name: lastName.isNotEmpty ? '$name $lastName' : name,
          lastName: lastName,
          email: email,
          userId: userId,
          phone: phone,
          profileImage: profileImage,
          username: username,
          about: about,
          qrCode: qrCode,
        ),
      );
    }
  }

  /// Обработчик события обновления профиля.
  /// Обновляет данные пользователя.
  Future<void> _onUpdateProfile(
    UpdateProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    if (state is! ProfileLoaded) return;

    emit(const ProfileLoading());
    try {
      // Сохраняем данные локально
      await UserService.saveLocal('name', event.name);
      await UserService.saveLocal('lastName', event.lastName);
      await UserService.saveLocal('email', event.email);
      await UserService.saveLocal('phone', event.phone);
      await UserService.saveLocal('profileImage', event.profileImage);
      if (event.username != null) {
        await UserService.saveLocal('username', event.username);
      }
      if (event.about != null) {
        await UserService.saveLocal('about', event.about);
      }

      // Имитация успешного обновления
      await Future.delayed(const Duration(milliseconds: 500));

      emit(
        ProfileLoaded(
          name: '${event.name} ${event.lastName}',
          lastName: event.lastName,
          email: event.email,
          userId: (state as ProfileLoaded).userId,
          phone: event.phone,
          profileImage:
              event.profileImage ?? (state as ProfileLoaded).profileImage,
          username: event.username ?? (state as ProfileLoaded).username,
          about: event.about ?? (state as ProfileLoaded).about,
        ),
      );

      // Через некоторое время возвращаем состояние успешного обновления
      await Future.delayed(const Duration(seconds: 2));
      emit(const ProfileUpdated());
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }

  /// Обработчик события выхода из профиля.
  /// Выполняет выход пользователя и очищает локальные данные.
  Future<void> _onLogoutProfile(
    LogoutProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    try {
      await AuthService.logout();
      await UserService.deleteLocal('token');
      // Очищаем кеши профиля и объявлений при выходе
      AppCacheService().invalidate(CacheKeys.profileData);
      AppCacheService().invalidate(CacheKeys.profileListingsCounts);
      await AppCacheService().invalidateByPrefix(CacheKeys.advertsPrefix);
      emit(const ProfileLoggedOut());
    } catch (e) {
      // Даже если logout на сервере не удался, очищаем локальный токен и кеш
      await UserService.deleteLocal('token');
      AppCacheService().invalidate(CacheKeys.profileData);
      emit(const ProfileLoggedOut());
    }
  }
}
