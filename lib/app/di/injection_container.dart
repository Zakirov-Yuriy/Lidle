// ============================================================
// Dependency Injection Container
//
// Отвечает за:
// 1. Регистрацию всех BLoCs (12 штук)
// 2. Регистрацию всех Services (~27 штук)
// 3. Регистрацию HTTP client и утилит
// 4. Инициализацию setupServiceLocator()
//
// Используется pattern: Service Locator (get_it)
// ============================================================

import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ── BLOCS ────────────────────────────────────────────────────────
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/catalog/catalog_bloc.dart';
import 'package:lidle/blocs/connectivity/connectivity_bloc.dart';
import 'package:lidle/blocs/devices/devices_bloc.dart';
import 'package:lidle/blocs/listings/listings_bloc.dart';
import 'package:lidle/blocs/messages/messages_bloc.dart';
import 'package:lidle/blocs/company_messages/company_messages_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/password_recovery/password_recovery_bloc.dart';
import 'package:lidle/blocs/profile/profile_bloc.dart';
import 'package:lidle/blocs/wishlist/wishlist_bloc.dart';
import 'package:lidle/features/cart/presentation/bloc/cart_bloc.dart';

// ── SERVICES ─────────────────────────────────────────────────────
import 'package:lidle/services/auth_service.dart';
import 'package:lidle/services/address_service.dart';
import 'package:lidle/services/adverts_service.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/api_request_queue.dart';
import 'package:lidle/services/catalog_service.dart';
import 'package:lidle/services/contacts_check_service.dart';
import 'package:lidle/services/contact_service.dart';
import 'package:lidle/services/device_info_service.dart';
import 'package:lidle/services/device_service.dart';
import 'package:lidle/services/loading_timer_service.dart';
import 'package:lidle/services/message_polling_service.dart';
import 'package:lidle/services/meta_service.dart';
import 'package:lidle/services/my_adverts_service.dart';
import 'package:lidle/services/notification_service.dart';
import 'package:lidle/services/selected_city_service.dart';
import 'package:lidle/services/support_mail_service.dart';
import 'package:lidle/services/token_secure_storage.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/services/user_service.dart';
import 'package:lidle/services/websocket_service.dart';
import 'package:lidle/services/wishlist_service.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/core/logger.dart';

/// Service Locator instance
final sl = GetIt.instance;

/// Функция инициализации всех зависимостей
/// Вызывается в main() перед runApp()
///
/// Порядок регистрации:
/// 1. Services (базовые, без зависимостей)
/// 2. Services (зависящие от других services)
/// 3. BLoCs (зависят от services)
Future<void> setupServiceLocator() async {
  try {
    log.i('🔧 [DI] Начинаем регистрацию зависимостей...');

    // ═══════════════════════════════════════════════════════════════════
    // 1️⃣ РЕГИСТРАЦИЯ БАЗОВЫХ SERVICES (БЕЗ ЗАВИСИМОСТЕЙ)
    // ═══════════════════════════════════════════════════════════════════

    // 🔐 Token & Auth Services
    sl.registerSingleton<TokenService>(TokenService());
    log.d('  ✓ TokenService зарегистрирован');

    sl.registerSingleton<TokenSecureStorage>(TokenSecureStorage());
    log.d('  ✓ TokenSecureStorage зарегистрирован');

    // 📡 HTTP Client
    sl.registerSingleton<ApiService>(ApiService());
    log.d('  ✓ ApiService зарегистрирован');

    sl.registerSingleton<ApiRequestQueue>(ApiRequestQueue());
    log.d('  ✓ ApiRequestQueue зарегистрирован');

    // 🗄️ Local Storage
    sl.registerSingleton<HiveService>(HiveService());
    log.d('  ✓ HiveService зарегистрирован');

    // 📱 Device Info
    sl.registerSingleton<DeviceInfoService>(DeviceInfoService());
    log.d('  ✓ DeviceInfoService зарегистрирован');

    // 🔔 Notification Service
    sl.registerSingleton<NotificationService>(NotificationService());
    log.d('  ✓ NotificationService зарегистрирован');

    // 🌐 WebSocket
    sl.registerSingleton<WebSocketService>(WebSocketService());
    log.d('  ✓ WebSocketService зарегистрирован');

    // ═══════════════════════════════════════════════════════════════════
    // 2️⃣ РЕГИСТРАЦИЯ SECONDARY SERVICES (ЗАВИСЯТ ОТ БАЗОВЫХ)
    // ═══════════════════════════════════════════════════════════════════

    // 🔐 Auth & User Services
    sl.registerSingleton<AuthService>(AuthService());
    log.d('  ✓ AuthService зарегистрирован');

    sl.registerSingleton<UserService>(UserService());
    log.d('  ✓ UserService зарегистрирован');

    // 🏢 Address & Location Services
    sl.registerSingleton<AddressService>(AddressService());
    log.d('  ✓ AddressService зарегистрирован');

    sl.registerSingleton<SelectedCityService>(SelectedCityService());
    log.d('  ✓ SelectedCityService зарегистрирован');

    // 🛍️ Adverts & Catalog Services
    sl.registerSingleton<AdvertsService>(AdvertsService());
    log.d('  ✓ AdvertsService зарегистрирован');

    sl.registerSingleton<MyAdvertsService>(MyAdvertsService());
    log.d('  ✓ MyAdvertsService зарегистрирован');

    sl.registerSingleton<CatalogService>(CatalogService());
    log.d('  ✓ CatalogService зарегистрирован');

    // ❤️ Wishlist & Favorites
    sl.registerSingleton<WishlistService>(WishlistService());
    log.d('  ✓ WishlistService зарегистрирован');

    // 💬 Messages Services
    sl.registerSingleton<MessagePollingService>(MessagePollingService());
    log.d('  ✓ MessagePollingService зарегистрирован');

    // 📋 Other Services
    sl.registerSingleton<MetaService>(MetaService());
    log.d('  ✓ MetaService зарегистрирован');

    sl.registerSingleton<DeviceService>(DeviceService());
    log.d('  ✓ DeviceService зарегистрирован');

    sl.registerSingleton<ContactService>(ContactService());
    log.d('  ✓ ContactService зарегистрирован');

    sl.registerSingleton<ContactsCheckService>(ContactsCheckService());
    log.d('  ✓ ContactsCheckService зарегистрирован');

    sl.registerSingleton<SupportMailService>(SupportMailService());
    log.d('  ✓ SupportMailService зарегистрирован');

    sl.registerSingleton<LoadingTimerService>(LoadingTimerService());
    log.d('  ✓ LoadingTimerService зарегистрирован');

    // ═══════════════════════════════════════════════════════════════════
    // 3️⃣ РЕГИСТРАЦИЯ BLOCS (ЗАВИСЯТ ОТ SERVICES)
    // ═══════════════════════════════════════════════════════════════════

    // 🔐 Auth BLoC
    sl.registerFactory<AuthBloc>(
      () => AuthBloc(),
    );
    log.d('  ✓ AuthBloc зарегистрирован');

    // 🏠 Navigation BLoC
    sl.registerFactory<NavigationBloc>(
      () => NavigationBloc(),
    );
    log.d('  ✓ NavigationBloc зарегистрирован');

    // 📋 Listings BLoC
    sl.registerFactory<ListingsBloc>(
      () => ListingsBloc(),
    );
    log.d('  ✓ ListingsBloc зарегистрирован');

    // 🏢 Catalog BLoC
    sl.registerFactory<CatalogBloc>(
      () => CatalogBloc(),
    );
    log.d('  ✓ CatalogBloc зарегистрирован');

    // 👤 Profile BLoC
    sl.registerFactory<ProfileBloc>(
      () => ProfileBloc(),
    );
    log.d('  ✓ ProfileBloc зарегистрирован');

    // 💬 Messages BLoC
    sl.registerFactory<MessagesBloc>(
      () => MessagesBloc(),
    );
    log.d('  ✓ MessagesBloc зарегистрирован');

    // 🏢 Company Messages BLoC
    sl.registerFactory<CompanyMessagesBloc>(
      () => CompanyMessagesBloc(),
    );
    log.d('  ✓ CompanyMessagesBloc зарегистрирован');

    // 🛒 Cart BLoC
    sl.registerFactory<CartBloc>(
      () => CartBloc(),
    );
    log.d('  ✓ CartBloc зарегистрирован');

    // 🔐 Password Recovery BLoC
    sl.registerFactory<PasswordRecoveryBloc>(
      () => PasswordRecoveryBloc(),
    );
    log.d('  ✓ PasswordRecoveryBloc зарегистрирован');

    // 📱 Devices BLoC
    sl.registerFactory<DevicesBloc>(
      () => DevicesBloc(),
    );
    log.d('  ✓ DevicesBloc зарегистрирован');

    // ❤️ Wishlist BLoC
    sl.registerFactory<WishlistBloc>(
      () => WishlistBloc(),
    );
    log.d('  ✓ WishlistBloc зарегистрирован');

    // 📡 Connectivity BLoC
    sl.registerFactory<ConnectivityBloc>(
      () => ConnectivityBloc(),
    );
    log.d('  ✓ ConnectivityBloc зарегистрирован');

    // ═══════════════════════════════════════════════════════════════════
    // ✅ ЗАВЕРШЕНО
    // ═══════════════════════════════════════════════════════════════════

    log.i('✅ [DI] Регистрация зависимостей завершена успешно!');
    log.i('  📊 Зарегистрировано: 12 BLoCs + 23 Services + Utilities');

  } catch (e, st) {
    log.e('❌ [DI] Ошибка при регистрации зависимостей: $e\n$st');
    rethrow;
  }
}

/// Получить BLoC из Service Locator
///
/// Используется в BlocProvider:
/// ```dart
/// BlocProvider<AuthBloc>(
///   create: (_) => getIt<AuthBloc>(),
/// )
/// ```
T getIt<T extends Object>() {
  return sl.get<T>();
}
