import 'package:flutter_bloc/flutter_bloc.dart';
import 'profile_event.dart';
import 'profile_state.dart';
import '../../hive_service.dart';
import '../../services/auth_service.dart';

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
  /// Загружает данные пользователя из локального хранилища.
  Future<void> _onLoadProfile(
    LoadProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    try {
      // В будущем здесь будет загрузка из API
      // final profile = await ApiService.getProfile();

      // Пока используем статические данные для демонстрации
      const name = 'Влад Борман';
      const userId = 'ID: 2342124342';
      const email = 'user@example.com';
      const phone = '+7 (999) 123-45-67';

      emit(ProfileLoaded(
        name: name,
        email: email,
        userId: userId,
        phone: phone,
      ));
    } catch (e) {
      emit(ProfileError(e.toString()));
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
      // В будущем здесь будет вызов API для обновления профиля
      // await ApiService.updateProfile(
      //   name: event.name,
      //   email: event.email,
      //   phone: event.phone,
      // );

      // Имитация успешного обновления
      await Future.delayed(const Duration(milliseconds: 500));

      emit(ProfileLoaded(
        name: event.name,
        email: event.email,
        userId: (state as ProfileLoaded).userId,
        phone: event.phone,
      ));

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
