// ============================================================
// "Главная функция и корневой виджет приложения"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lidle/pages/add_listing/published_screen.dart';
import 'package:lidle/pages/profile_dashboard/my_listings/new_listing_notifier.dart';
import 'package:workmanager/workmanager.dart';
import 'package:lidle/services/background_message_service.dart';
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
        return await backgroundMessageCheck();
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
      );
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
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc()..add(const CheckAuthStatusEvent()),
        ),
        BlocProvider<ListingsBloc>(create: (context) => ListingsBloc()),
        BlocProvider<NavigationBloc>(create: (context) => NavigationBloc()),
        BlocProvider<ProfileBloc>(create: (context) => ProfileBloc()),
        BlocProvider<PasswordRecoveryBloc>(
          create: (context) => PasswordRecoveryBloc(),
        ),
        BlocProvider<MessagesBloc>(create: (context) => MessagesBloc()),
        BlocProvider<CompanyMessagesBloc>(
          create: (context) => CompanyMessagesBloc(),
        ),
        BlocProvider<CartBloc>(create: (context) => CartBloc()),
        BlocProvider<CatalogBloc>(create: (context) => CatalogBloc()),
        BlocProvider<DevicesBloc>(create: (context) => DevicesBloc()),
        BlocProvider<WishlistBloc>(create: (context) => WishlistBloc()),
        BlocProvider<ConnectivityBloc>(create: (context) => ConnectivityBloc()),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          // Управляем TokenService в зависимости от состояния авторизации
          if (state is AuthAuthenticated) {
            // Пользователь авторизован — запускаем фоновое обновление токена
            TokenService().init(context);

            // Загружаем wishlist (избранное) с сервера
            context.read<WishlistBloc>().add(const LoadWishlistEvent());

            // 🔔 Запускаем систему мониторинга новых сообщений (FOREGROUND timer)
            MessagePollingService().startPolling(
              interval: const Duration(seconds: 15),
            );

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
            TokenService().dispose();

            // 🔔 Останавливаем мониторинг новых сообщений (FOREGROUND)
            MessagePollingService().stopPolling();

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
