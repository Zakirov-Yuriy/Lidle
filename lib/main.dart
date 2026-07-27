// ============================================================
// "Главная функция и корневой виджет приложения"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lidle/app/di/injection_container.dart';
import 'package:lidle/pages/add_listing/published_screen.dart';
import 'package:lidle/pages/profile_dashboard/my_listings/new_listing_notifier.dart';
import 'package:workmanager/workmanager.dart';
import 'package:lidle/services/background_message_service.dart';
import 'package:lidle/services/background_ai_status_service.dart';
import 'package:lidle/services/websocket_service.dart';
import 'package:lidle/services/ws_foreground_service.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/core/config/app_config.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_state.dart';
import 'package:lidle/blocs/auth/auth_event.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/pages/auth/sign_in_screen.dart';
import 'package:lidle/pages/home_page.dart';
import 'package:lidle/blocs/listings/listings_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/profile/profile_bloc.dart';
import 'package:lidle/blocs/password_recovery/password_recovery_bloc.dart';
import 'package:lidle/blocs/messages/messages_bloc.dart';
import 'package:lidle/blocs/company_messages/company_messages_bloc.dart';
import 'package:lidle/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:lidle/blocs/catalog/catalog_bloc.dart';
import 'package:lidle/blocs/devices/devices_bloc.dart';
import 'package:lidle/blocs/wishlist/wishlist_bloc.dart';
import 'package:lidle/blocs/connectivity/connectivity_bloc.dart';
import 'package:lidle/blocs/connectivity/connectivity_state.dart';
import 'package:lidle/blocs/connectivity/connectivity_event.dart';
import 'package:lidle/services/device_info_service.dart';
import 'package:lidle/services/notification_service.dart';
import 'package:lidle/services/message_polling_service.dart';
import 'package:lidle/services/ai_completion_service.dart';
import 'package:lidle/services/badge_service.dart';
import 'package:lidle/core/cache/cache_service.dart';
import 'package:lidle/core/cache/cache_keys.dart';
import 'package:lidle/widgets/no_internet_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'constants.dart';
import 'package:lidle/app/routes.dart';
import 'dart:async';                                              // ← добавить
  

// RouteObserver для отслеживания навигации
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
// ── Добавить рядом с routeObserver ──────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ============================================================
//  Callback Dispatcher для фоновых задач workmanager'а
// Эта функция вызывается в изолированном контексте (вне UI потока)
// ============================================================
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == 'backgroundMessageCheck') {
        // Вызываем функцию проверки сообщений для фонового контекста
        final messagesOk = await backgroundMessageCheck();
        // 🤖 В том же цикле проверяем статус ИИ-обработки объявлений и, если
        // ИИ только что завершил обработку (all_done), показываем локальное
        // уведомление — оно приходит даже когда приложение закрыто.
        await backgroundAiStatusCheck();
        return messagesOk;
      }
      return false;
    } catch (e, st) {
      // log.e('❌ Background task ошибка: $e\n$st');
      return false;
    }
  });
}

// ============================================================
//  Главная функция
// Выполняет асинхронную инициализацию необходимых сервисов.
// ============================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔧 ИНИЦИАЛИЗАЦИЯ: Загружаем конфигурацию из .env файла
  // Это определяет окружение (dev/prod) для всех API endpoints
  try {
    await dotenv.load(fileName: '.env');
    final environment = dotenv.env['APP_ENVIRONMENT'] ?? 'prod';

    // 🔍 ДЕБАГ: Выводим что прочитали из .env
    // log.w('🔍 DEBUG: APP_ENVIRONMENT из .env = "$environment"');
    // log.w('🔍 DEBUG: Все переменные .env: ${dotenv.env}');

    await AppConfig.initialize(environmentValue: environment);
    // log.i('✅ AppConfig инициализирован: ${AppConfig().environment.value}');
    // log.i('   API URL: ${AppConfig().apiBaseUrl}');
    // log.i('   WebSocket URL: ${AppConfig().wsUrl}');
    // log.i('   Images URL: ${AppConfig().imageBaseUrl}');
  } catch (e, st) {
    // log.e('❌ AppConfig инициализация ошибка: $e\n$st');
    // Используем production по умолчанию если .env не найден
    await AppConfig.initialize(environmentValue: 'prod');
    // log.w('⚠️ Использован fallback - production сервер');
  }

  // 🌙 ИНИЦИАЛИЗАЦИЯ: Workmanager для фоновых задач
  // Инициализируем callback dispatcher для обработки фоновых задач
  try {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false, // Set to true for debug logging
    );
  } catch (e) {
    log.w('⚠️ Workmanager инициализация ошибка: $e');
  }

  // 🚀 ОПТИМИЗАЦИЯ #1: Быстрая инициализация Hive (обязательна для кеша)
  // Инициализируем ДО runApp(), но максимально быстро без лишних задержек
  try {
    if (kIsWeb) {
      await Hive.initFlutter();
    } else {
      final appDocumentDir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(appDocumentDir.path);
    }
    await HiveService.init();

    // 🔒 SECURITY МИГРАЦИЯ: Переносим старые токены из Hive в secure storage
    // Это критическая операция - должна выполниться ДО первого использования токенов
    await HiveService.migrateTokensToSecureStorage();

    // 🔧 DEPENDENCY INJECTION: Инициализируем Service Locator
    // Регистрируем все BLoCs, Services и Utilities
    // Это должно быть ПОСЛЕ Hive и ДО первого использования сервисов
    await setupServiceLocator();
  } catch (e) {
    // Продолжаем работу даже если Hive не инициализирован
    log.w('⚠️ Hive инициализация ошибка: $e');
  }

  // � ОПТИМИЗАЦИЯ #2: DeviceInfoService инициализируется асинхронно в фоне
  // Это не блокирует холодный старт (~50-80ms экономия)
  // Инициализация запускается без await, работает параллельно с UI отрисовкой
  DeviceInfoService.initialize().catchError((e) {
    log.w('⚠️ DeviceInfoService инициализация ошибка: $e');
  });

  // 🔔 ИНИЦИАЛИЗАЦИЯ: NotificationService для локальных пуш-уведомлений
  // Инициализируется без await, работает в фоне
  NotificationService().initialize().catchError((e) {
    log.w('⚠️ NotificationService инициализация ошибка: $e');
  });

  // 🔔 ИНИЦИАЛИЗАЦИЯ: Восстанавливаем бейдж на иконке приложения из кеша
  // Если были непрочитанные сообщения до перезагрузки, они будут показаны на иконке
  _restoreBadgeOnStartup().catchError((e) {
    log.w('⚠️ Восстановление бейджа ошибка: $e');
  });

  // 📩 ИНИЦИАЛИЗАЦИЯ: Загружаем сохранённые ID сообщений из хранилища
  // для восстановления Polling состояния после рестарта приложения
  MessagePollingService().loadLastMessageIds().catchError((e) {
    log.w('⚠️ MessagePollingService загрузка ID ошибка: $e');
  });

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF232E3C),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF232E3C),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const LidleApp());
}

// ============================================================
//  Обёртка для отображения экрана отсутствия интернета
// ============================================================

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  StreamSubscription? _newListingSubscription;   // ← добавить

  @override
  void initState() {                              // ← добавить весь блок
    super.initState();
    _newListingSubscription =
        NewListingNotifier.instance.onNewListing.listen((advert) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => PublishedScreen(advert: advert)),
      ).then((_) {
        // Очищаем последнее уведомление после того как PublishedScreen закрывается
        NewListingNotifier.instance.clearLastNotification();
      });
    });
  }

  @override
  void dispose() {                                // ← добавить весь блок
    _newListingSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityBloc, ConnectivityState>(
    // ... дальше всё без изменений
      builder: (context, state) {
        // Показываем экран отсутствия интернета или несоответствия типа подключения
        if (state is DisconnectedState) {
          return NoInternetScreen(
            onRetry: () {
              // Проверяем соединение снова
              context.read<ConnectivityBloc>().add(
                const CheckConnectivityEvent(),
              );
            },
            reason: state.reason,
            availableTypes: state.availableTypes,
            preferredType: state.preferredType,
          );
        }

        // Показываем основное приложение при наличии соединения
        return const HomePage();
      },
    );
  }
}

// ============================================================
//  Корневой виджет приложения
// ============================================================

class LidleApp extends StatelessWidget {
  /// Конструктор для LidleApp.
  const LidleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // 🔐 Auth BLoC - с инициализацией проверки статуса
        BlocProvider<AuthBloc>(
          create: (_) => sl<AuthBloc>()..add(const CheckAuthStatusEvent()),
        ),
        // 🏠 Navigation BLoC
        BlocProvider<NavigationBloc>(
          create: (_) => sl<NavigationBloc>(),
        ),
        // 📋 Listings BLoC
        BlocProvider<ListingsBloc>(
          create: (_) => sl<ListingsBloc>(),
        ),
        // 👤 Profile BLoC
        BlocProvider<ProfileBloc>(
          create: (_) => sl<ProfileBloc>(),
        ),
        // 🔐 Password Recovery BLoC
        BlocProvider<PasswordRecoveryBloc>(
          create: (_) => sl<PasswordRecoveryBloc>(),
        ),
        // 💬 Messages BLoC
        BlocProvider<MessagesBloc>(
          create: (_) => sl<MessagesBloc>(),
        ),
        // 🏢 Company Messages BLoC
        BlocProvider<CompanyMessagesBloc>(
          create: (_) => sl<CompanyMessagesBloc>(),
        ),
        // 🛒 Cart BLoC
        BlocProvider<CartBloc>(
          create: (_) => sl<CartBloc>(),
        ),
        // 🏢 Catalog BLoC
        BlocProvider<CatalogBloc>(
          create: (_) => sl<CatalogBloc>(),
        ),
        // 📱 Devices BLoC
        BlocProvider<DevicesBloc>(
          create: (_) => sl<DevicesBloc>(),
        ),
        // ❤️ Wishlist BLoC
        BlocProvider<WishlistBloc>(
          create: (_) => sl<WishlistBloc>(),
        ),
        // 📡 Connectivity BLoC
        BlocProvider<ConnectivityBloc>(
          create: (_) => sl<ConnectivityBloc>(),
        ),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          // Управляем TokenService в зависимости от состояния авторизации
          if (state is AuthAuthenticated) {
            // Пользователь авторизован — запускаем фоновое обновление токена
            sl<TokenService>().init(context);

            // 🎏 Синхронизируем локальное избранное с серверным при авторизации
            context.read<WishlistBloc>().add(const SyncLocalWishlistOnAuthEvent());

            // � Загружаем сообщения для бейджа в bottom_navigation (на ЛЮБОМ экране)
            // Это обеспечивает показ бейджа сразу после авторизации без открытия messages_page
            context.read<MessagesBloc>().loadMessagesFromAPI();

            // �🔔 Запускаем систему мониторинга новых сообщений (FOREGROUND timer)
            sl<MessagePollingService>().startPolling(
              interval: const Duration(seconds: 15),
            );

            // 🤖 Наблюдатель за завершением ИИ-обработки объявлений из фида:
            // когда ИИ обработал все объявления, покажет оповещение на любом
            // экране с переходом на предпросмотр для публикации.
            AiCompletionService.instance.start();

            // 🔌 Подключаемся к Reverb (WebSocket) и слушаем канал пользователя:
            // сервер мгновенно пришлёт событие о завершении ИИ-обработки.
            // Android — через foreground-сервис (держит связь и при закрытом
            // приложении, этап 3); остальные платформы — main-изолят.
            if (!kIsWeb && Platform.isAndroid) {
              WsForegroundService.start();
            } else {
              WebSocketService().start();
            }

            // 🌙 Запускаем BACKGROUND задачу для проверки сообщений
            // Эта задача запускается периодически даже когда приложение свернуто
            Workmanager().registerPeriodicTask(
              'check-messages',
              'backgroundMessageCheck',
              frequency: const Duration(minutes: 15),
              initialDelay: const Duration(seconds: 30),
            );

            log.d('🌙 Запущена фоновая задача проверки сообщений');
          } else if (state is AuthLoggedOut || state is AuthTokenExpired) {
            // Пользователь вышел или токен истёк — останавливаем таймер
            sl<TokenService>().dispose();

            // 🔔 Останавливаем мониторинг новых сообщений (FOREGROUND)
            sl<MessagePollingService>().stopPolling();

            // 🤖 Останавливаем наблюдатель за ИИ-обработкой.
            AiCompletionService.instance.stop();

            // 🔌 Отключаем WebSocket.
            if (!kIsWeb && Platform.isAndroid) {
              WsForegroundService.stop();
            } else {
              WebSocketService().stop();
            }

            // 🌙 Отменяем BACKGROUND задачу
            Workmanager().cancelByTag('check-messages');
            // log.d('🌙 Отменена фоновая задача проверки сообщений');
          }

          // При истечении токена — перенаправляем на экран входа
          if (state is AuthTokenExpired) {
            // Закрываем все экраны и открываем SignIn
            Navigator.of(
              context,
              rootNavigator: true,
            ).pushNamedAndRemoveUntil(SignInScreen.routeName, (route) => false);
            // Показываем уведомление пользователю
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Сессия истекла. Пожалуйста, войдите снова.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
        },
        child: MaterialApp(
          title: appTitle,
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,   // ← добавить эту строку
          theme: ThemeData(fontFamily: 'Roboto', brightness: Brightness.dark),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en', ''), Locale('ru', '')],
          navigatorObservers: [routeObserver],
          // Обработка ошибок при построении
          builder: (context, home) {
            return home ?? ErrorWidget(Exception('Unknown error'));
          },

          // Production home с обёрткой для проверки интернета
          home: const AppWrapper(),
          // home: const PublishedScreen(),
          // home: const PropertyDetailsScreen(),
          routes: AppRoutes.routes,
        ),
      ),
    );
  }
}

// ============================================================
//  Вспомогательная функция: Восстановить бейдж при запуске
// ============================================================
/// Восстанавливает количество непрочитанных сообщений на иконке приложения
/// при запуске из кешированных данных.
/// 
/// Это гарантирует, что если пользователь закрыл приложение с 5 непрочитанными
/// сообщениями, при следующем запуске ба увидит бейдж "5" на иконке приложения,
/// пока сообщения не будут загружены с сервера.
Future<void> _restoreBadgeOnStartup() async {
  try {
    log.d('🔔 Восстановление бейджа при запуске приложения...');
    
    // Получаем кешированные сообщения
    final cached = AppCacheService().get<Map<String, dynamic>>(CacheKeys.messagesData);
    
    if (cached == null) {
      log.d('ℹ️ Кеш сообщений пуст, бейдж не требуется на этом этапе');
      return;
    }
    
    final mainMessages = cached['main'] as List? ?? [];
    
    if (mainMessages.isEmpty) {
      log.d('ℹ️ Нет кешированных сообщений');
      return;
    }
    
    // Рассчитываем общее количество непрочитанных
    int totalUnread = 0;
    for (final msg in mainMessages) {
      final count = (msg as Map)['unreadCount'];
      final unreadInt = count is int ? count : int.tryParse(count.toString()) ?? 0;
      totalUnread += unreadInt;
    }
    
    if (totalUnread > 0) {
      log.i('🔔 Восстановлено $totalUnread непрочитанных сообщений на иконке приложения');
      await BadgeService().updateBadgeCount(totalUnread);
    } else {
      log.d('ℹ️ Нет непрочитанных сообщений в кеше');
    }
  } catch (e, st) {
    log.w('⚠️ Ошибка восстановления бейджа: $e\n$st');
  }
}
