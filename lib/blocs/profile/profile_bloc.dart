import 'package:flutter_bloc/flutter_bloc.dart';
import 'profile_event.dart';
import 'profile_state.dart';
import '../../hive_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';

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
      final token = HiveService.getUserData('token');
      // print('🔑 Token from Hive: $token');
      if (token == null) {
        // print('❌ Токен не найден!');
        emit(const ProfileError('Токен не найден'));
        return;
      }

      if (token.isEmpty) {
        // print('❌ Токен пуст!');
        emit(const ProfileError('Токен пуст'));
        return;
      }

      // Если forceRefresh = true, сразу показываем загрузку
      if (event.forceRefresh) {
        // print('🔄 Принудительное обновление профиля (forceRefresh=true)');
        emit(const ProfileLoading());
      } else {
        // Иначе показываем данные из Hive (если есть)
        final cachedName = HiveService.getUserData('name') ?? 'Пользователь';
        final cachedLastName = HiveService.getUserData('lastName') ?? '';
        final cachedEmail =
            HiveService.getUserData('email') ?? 'user@example.com';
        final cachedPhone =
            HiveService.getUserData('phone') ?? '+7 (999) 123-45-67';
        // Получаем userId из Hive с дефолтом ID: 0
        final cachedUserIdRaw = HiveService.getUserData('userId');
        final cachedUserId =
            cachedUserIdRaw != null && cachedUserIdRaw.isNotEmpty
            ? 'ID: $cachedUserIdRaw'
            : 'ID: 0';
        final cachedProfileImage = HiveService.getUserData('profileImage');
        final cachedUsername = HiveService.getUserData('username') ?? '@User';
        final cachedAbout = HiveService.getUserData('about');

        // Если есть кэшированные данные - показываем их сразу
        if (cachedName.isNotEmpty && cachedName != 'Пользователь') {
          // print('📖 Показываем кэшированные данные из Hive: $cachedName');
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
          // Если нет кэша - показываем загрузку
          emit(const ProfileLoading());
        }
      }

      // Загружаем свежие данные с API
      // print('📡 Загружаем профиль с API...');
      final profile = await UserService.getProfile(token: token);
      // print('✅ Профиль загружен: ${profile.name} ${profile.lastName}');

      // Сохраняем данные в Hive
      await HiveService.saveUserData('name', profile.name);
      await HiveService.saveUserData('lastName', profile.lastName);
      await HiveService.saveUserData('email', profile.email);
      await HiveService.saveUserData('phone', profile.phone ?? '');
      // Извлекаем userId из JWT токена (из claim 'sub')
      final userIdString = AuthService.extractUserIdFromToken(token);
      await HiveService.saveUserData('userId', userIdString);
      await HiveService.saveUserData('profileImage', profile.avatar);
      await HiveService.saveUserData('username', profile.name);
      await HiveService.saveUserData('about', profile.about ?? '');

      // Извлекаем base64 QR код из ответа API
      String? qrCodeBase64;
      if (profile.qrCode != null && profile.qrCode is Map<String, dynamic>) {
        qrCodeBase64 = profile.qrCode!['value'] as String?;
        if (qrCodeBase64 != null) {
          await HiveService.saveUserData('qrCode', qrCodeBase64);
          // print('✅ QR код сохранен в Hive');
        }
      }

      // print('💾 Данные сохранены в Hive');

      // Показываем свежие данные
      final userIdDisplay = 'ID: $userIdString';
      final displayName = '${profile.name} ${profile.lastName}';

      // print('🔍 DEBUG ProfileBloc._onLoadProfile():');
      // print('   - profile.name = "${profile.name}"');
      // print('   - profile.lastName = "${profile.lastName}"');
      // print('   - displayName (for UI) = "$displayName"');

      emit(
        ProfileLoaded(
          name: displayName,
          lastName: profile.lastName,
          email: profile.email,
          userId: userIdDisplay,
          phone: profile.phone ?? '+7 (999) 123-45-67',
          profileImage: profile.avatar,
          username: '@${profile.name}',
          about: profile.about,
          qrCode: qrCodeBase64,
        ),
      );
    } catch (e) {
      // print('❌ Ошибка загрузки профиля: $e');
      // print('📍 Stack trace: ${StackTrace.current}');

      // Fallback to Hive data if API fails
      final name = HiveService.getUserData('name') ?? 'Пользователь';
      final lastName = HiveService.getUserData('lastName') ?? '';
      final email = HiveService.getUserData('email') ?? 'user@example.com';
      final phone = HiveService.getUserData('phone') ?? '+7 (999) 123-45-67';
      final userId = HiveService.getUserData('userId') ?? 'ID: 0';
      final profileImage = HiveService.getUserData('profileImage');
      final username = HiveService.getUserData('username') ?? '@User';
      final about = HiveService.getUserData('about');
      final qrCode = HiveService.getUserData('qrCode');

      // print('📖 Fallback: Используем данные из Hive: $name $lastName');

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
      // Сохраняем данные в Hive
      await HiveService.saveUserData('name', event.name);
      await HiveService.saveUserData('lastName', event.lastName);
      await HiveService.saveUserData('email', event.email);
      await HiveService.saveUserData('phone', event.phone);
      await HiveService.saveUserData('profileImage', event.profileImage);
      if (event.username != null) {
        await HiveService.saveUserData('username', event.username);
      }
      if (event.about != null) {
        await HiveService.saveUserData('about', event.about);
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
      await HiveService.deleteUserData('token');
      emit(const ProfileLoggedOut());
    } catch (e) {
      // Даже если logout на сервере не удался, очищаем локальный токен
      await HiveService.deleteUserData('token');
      emit(const ProfileLoggedOut());
    }
  }
}

