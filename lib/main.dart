// ============================================================
// "Главная функция и корневой виджет приложения"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:workmanager/workmanager.dart';
import 'package:lidle/services/background_message_service.dart';
import 'package:lidle/pages/profile_menu/settings/contact_data/contact_data_screen.dart';
import 'package:lidle/pages/profile_menu/settings/privacy_settings/privacy_settings_screen.dart';
import 'package:lidle/pages/profile_menu/settings/chat_settings/chat_settings_screen.dart';
import 'package:lidle/pages/profile_menu/settings/username/username_screen.dart';
import 'package:lidle/pages/profile_menu/settings/change_photo/change_photo_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_state.dart';
import 'package:lidle/blocs/auth/auth_event.dart';
import 'package:lidle/services/token_service.dart';
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
import 'package:lidle/pages/filters_screen.dart';
import 'package:lidle/pages/auth/account_recovery.dart';
import 'package:lidle/pages/auth/register_screen.dart';
import 'package:lidle/pages/auth/register_verify_screen.dart';
import 'package:lidle/pages/auth/account_recovery_code.dart';
import 'package:lidle/pages/auth/account_recovery_new_password.dart';
import 'package:path_provider/path_provider.dart';
import 'constants.dart';
import 'package:lidle/pages/home_page.dart';
import 'package:lidle/pages/auth/sign_in_screen.dart';
import 'package:lidle/pages/profile_dashboard/profile_dashboard.dart';
import 'package:lidle/pages/profile_menu/profile_menu_screen.dart';
import 'package:lidle/pages/profile_menu/invite_friends/invite_friends_screen.dart';
import 'package:lidle/pages/profile_menu/invite_friends/find_by_phone_screen.dart';
import 'package:lidle/pages/profile_menu/invite_friends/connect_contacts_screen.dart';
import 'package:lidle/pages/profile_menu/settings/settings_screen.dart';
import 'package:lidle/pages/profile_menu/settings/devices/devices_screen.dart';
import 'package:lidle/pages/profile_menu/settings/delete_account/delete_account_screen.dart';
import 'package:lidle/pages/profile_menu/settings/privacy_policy/privacy_policy_screen.dart';
import 'package:lidle/pages/profile_menu/settings/faq/faq_screen.dart';
import 'package:lidle/pages/profile_menu/support_service_screen.dart';
import 'package:lidle/pages/favorites_screen.dart';
import 'package:lidle/pages/add_listing/add_listing_screen.dart';
import 'package:lidle/pages/add_listing/category_selection_screen.dart';
import 'package:lidle/pages/add_listing/payment_screen.dart';
import 'package:lidle/pages/full_category_screen/full_category_screen.dart';
import 'package:lidle/pages/full_category_screen/property_details_screen.dart';
import 'package:lidle/pages/full_category_screen/map_screen.dart';
import 'package:lidle/pages/my_purchases_screen.dart';
import 'package:lidle/pages/messages/messages_page.dart'; // Corrected import
import 'package:lidle/pages/messages/messages_archive_page.dart';
import 'package:lidle/pages/profile_dashboard/user_messages/user_messages_list_screen.dart';
import 'package:lidle/pages/profile_dashboard/user_messages/user_messages_archive_list_screen.dart';
import 'package:lidle/pages/profile_dashboard/company_messages/company_messages_list_screen.dart';
import 'package:lidle/pages/profile_dashboard/company_messages/company_messages_archive_list_screen.dart';
import 'package:lidle/pages/profile_dashboard/offers/price_offers_empty_page.dart';
import 'package:lidle/pages/profile_dashboard/offers/price_accepted_page.dart';
import 'package:lidle/pages/profile_dashboard/offers/price_offers_list_page.dart'; // Import the new page
import 'package:lidle/pages/profile_dashboard/offers/incoming_price_offer_page.dart'; // Import the new page
import 'package:lidle/pages/profile_dashboard/offers/user_account_page.dart'; // Import UserAccountPage
import 'package:lidle/pages/profile_dashboard/offers/user_account_only_page.dart'; // Import UserAccountOnlyPage
import 'package:lidle/pages/profile_dashboard/support/support_screen.dart';
import 'package:lidle/pages/profile_dashboard/support/discounts_and_promotions_page.dart';
import 'package:lidle/pages/profile_dashboard/support/support_chat_page.dart';
import 'package:lidle/pages/profile_dashboard/responses/responses_empty_page.dart';
import 'package:lidle/pages/profile_dashboard/reviews/reviews_empty_page.dart';
import 'package:lidle/pages/profile_dashboard/my_listings/my_listings_screen.dart';
import 'package:lidle/features/cart/domain/entities/cart_screen.dart';
import 'package:lidle/pages/profile_menu/settings/devices/qr_scanner/qr_scanner_screen.dart';
import 'package:lidle/pages/profile_menu/contacts/contacts_screen.dart';
import 'package:lidle/pages/profile_menu/user_qr/user_qr_screen.dart';
import 'package:lidle/pages/profile_menu/user_qr/qr_print_templates_screen.dart';
import 'package:lidle/models/offer_model.dart';

// RouteObserver для отслеживания навигации
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

// ============================================================
//  Callback Dispatcher для фоновых задач workmanager'а
// Эта функция вызывается в изолированном контексте (вне UI потока)
// ============================================================
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == 'backgroundMessageCheck') {
        // Вызываем функцию проверки сообщений для фонового контекста
        return await backgroundMessageCheck();
      }
      return false;
    } catch (e, st) {
      print('❌ Background task ошибка: $e\n$st');
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

  // 🌙 ИНИЦИАЛИЗАЦИЯ: Workmanager для фоновых задач
  // Инициализируем callback dispatcher для обработки фоновых задач
  try {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false, // Set to true for debug logging
    );
  } catch (e) {
    print('⚠️ Workmanager инициализация ошибка: $e');
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
    print('⚠️ Hive инициализация ошибка: $e');
  }

  // 🚀 ОПТИМИЗАЦИЯ #2: DeviceInfoService инициализируется асинхронно в фоне
  // Это не блокирует холодный старт (~50-80ms экономия)
  // Инициализация запускается без await, работает параллельно с UI отрисовкой
  DeviceInfoService.initialize().catchError((e) {
    print('⚠️ DeviceInfoService инициализация ошибка: $e');
  });

  // 🔔 ИНИЦИАЛИЗАЦИЯ: NotificationService для локальных пуш-уведомлений
  // Инициализируется без await, работает в фоне
  NotificationService().initialize().catchError((e) {
    print('⚠️ NotificationService инициализация ошибка: $e');
  });

  // 📩 ИНИЦИАЛИЗАЦИЯ: Загружаем сохранённые ID сообщений из хранилища
  // для восстановления Polling состояния после рестарта приложения
  MessagePollingService().loadLastMessageIds().catchError((e) {
    print('⚠️ MessagePollingService загрузка ID ошибка: $e');
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
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityBloc, ConnectivityState>(
      builder: (context, state) {
        // Показываем экран отсутствия интернета или несоответствия типа подключения
        if (state is DisconnectedState) {
          return NoInternetScreen(
            onRetry: () {
              // Проверяем соединение снова
              context
                  .read<ConnectivityBloc>()
                  .add(const CheckConnectivityEvent());
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
            
            print('🌙 Запущена фоновая задача проверки сообщений');
          } else if (state is AuthLoggedOut || state is AuthTokenExpired) {
            // Пользователь вышел или токен истёк — останавливаем таймер
            TokenService().dispose();
            
            // 🔔 Останавливаем мониторинг новых сообщений (FOREGROUND)
            MessagePollingService().stopPolling();
            
            // 🌙 Отменяем BACKGROUND задачу
            Workmanager().cancelByTag('check-messages');
            print('🌙 Отменена фоновая задача проверки сообщений');
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
          // home: const PropertyDetailsScreen(),
          routes: {
            HomePage.routeName: (context) => const HomePage(),
            SignInScreen.routeName: (context) => const SignInScreen(),
            ProfileMenuScreen.routeName: (context) => const ProfileMenuScreen(),
            InviteFriendsScreen.routeName: (context) =>
                const InviteFriendsScreen(),
            FindByPhoneScreen.routeName: (context) => const FindByPhoneScreen(),
            ConnectContactsScreen.routeName: (context) =>
                const ConnectContactsScreen(),
            SettingsScreen.routeName: (context) => const SettingsScreen(),
            '/contact_data': (context) => ContactDataScreen(),
            '/privacy_settings': (context) => const PrivacySettingsScreen(),
            '/chat_settings': (context) => const ChatSettingsScreen(),
            '/username': (context) => const UsernameScreen(),
            '/change_photo': (context) => const ChangePhotoScreen(),
            '/devices': (context) => const DevicesScreen(),
            QrScannerScreen.routeName: (context) => const QrScannerScreen(),
            DeleteAccountScreen.routeName: (context) =>
                const DeleteAccountScreen(),
            PrivacyPolicyScreen.routeName: (context) =>
                const PrivacyPolicyScreen(),
            FaqScreen.routeName: (context) => const FaqScreen(),
            SupportServiceScreen.routeName: (context) =>
                const SupportServiceScreen(),
            AccountRecovery.routeName: (context) => const AccountRecovery(),
            RegisterScreen.routeName: (context) => const RegisterScreen(),
            RegisterVerifyScreen.routeName: (context) {
              // Передаём email из arguments в конструктор для надёжной
              // передачи данных (ModalRoute.of в initState может вернуть null)
              final args =
                  ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;
              return RegisterVerifyScreen(email: args?['email'] as String?);
            },
            AccountRecoveryCode.routeName: (context) =>
                const AccountRecoveryCode(),
            AccountRecoveryNewPassword.routeName: (context) =>
                const AccountRecoveryNewPassword(),
            ProfileDashboard.routeName: (context) => const ProfileDashboard(),
            FiltersScreen.routeName: (context) => const FiltersScreen(),
            FavoritesScreen.routeName: (context) => const FavoritesScreen(),
            AddListingScreen.routeName: (context) => const AddListingScreen(),
            CategorySelectionScreen.routeName: (context) =>
                const CategorySelectionScreen(),
            PaymentScreen.routeName: (context) => PaymentScreen(
              tariffName:
                  (ModalRoute.of(context)!.settings.arguments
                      as Map<String, String>?)?['tariffName'] ??
                  'Неизвестный тариф',
              price:
                  (ModalRoute.of(context)!.settings.arguments
                      as Map<String, String>?)?['price'] ??
                  '0р',
            ),
            CartScreen.routeName: (context) => const CartScreen(),
            FullCategoryScreen.routeName: (context) =>
                const FullCategoryScreen(),
            MapScreen.routeName: (context) => const MapScreen(),
            MyPurchasesScreen.routeName: (context) =>
                MyPurchasesScreen(), // Add the new route
            MessagesPage.routeName: (context) =>
                const MessagesPage(), // Corrected route
            MessagesArchivePage.routeName: (context) =>
                const MessagesArchivePage(),
            UserMessagesListScreen.routeName: (context) =>
                const UserMessagesListScreen(),
            UserMessagesArchiveListScreen.routeName: (context) =>
                const UserMessagesArchiveListScreen(),
            CompanyMessagesListScreen.routeName: (context) =>
                const CompanyMessagesListScreen(),
            CompanyMessagesArchiveListScreen.routeName: (context) =>
                const CompanyMessagesArchiveListScreen(),
            PriceOffersEmptyPage.routeName: (context) =>
                const PriceOffersEmptyPage(),
            PriceAcceptedPage.routeName: (context) => PriceAcceptedPage(
              offer: ModalRoute.of(context)!.settings.arguments as Offer,
            ),
            PriceOffersListPage.routeName: (context) => PriceOffersListPage(
              offer: ModalRoute.of(context)!.settings.arguments as Offer,
            ), // Add new route
            IncomingPriceOfferPage.routeName: (context) =>
                IncomingPriceOfferPage(
                  offerItem:
                      ModalRoute.of(context)!.settings.arguments
                          as PriceOfferItem,
                ),
            UserAccountPage.routeName: (context) {
              // Может быть либо PriceOfferItem (из PriceOffersListPage)
              // либо Offer (из OfferCard), либо null
              final args = ModalRoute.of(context)?.settings.arguments;
              PriceOfferItem? offerItem;
              if (args is PriceOfferItem) {
                offerItem = args;
              }
              return UserAccountPage(offerItem: offerItem);
            },
            UserAccountOnlyPage.routeName: (context) => UserAccountOnlyPage(
              offerItem:
                  ModalRoute.of(context)!.settings.arguments as PriceOfferItem,
            ),
            SupportScreen.routeName: (context) => const SupportScreen(),
            DiscountsAndPromotionsPage.routeName: (context) =>
                const DiscountsAndPromotionsPage(),
            SupportChatPage.routeName: (context) => const SupportChatPage(),
            ResponsesEmptyPage.routeName: (context) =>
                const ResponsesEmptyPage(),
            ReviewsEmptyPage.routeName: (context) => const ReviewsEmptyPage(),
            MyListingsScreen.routeName: (context) {
              // Обработка параметров для перехода из dynamic_filter при публикации
              final args = ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
              return MyListingsScreen(
                categoryId: args?['categoryId'] as int?,
                tabIndex: args?['tabIndex'] as int?,
              );
            },
            '/property-details': (context) => PropertyDetailsScreen(
              advertisementId: 
                  ModalRoute.of(context)?.settings.arguments as String?,
            ),
            '/contacts': (context) => const ContactsScreen(),
            '/user_qr': (context) => const UserQrScreen(),
            '/qr_print_templates': (context) => const QrPrintTemplatesScreen(),
          },
        ),
      ),
    );
  }
}
