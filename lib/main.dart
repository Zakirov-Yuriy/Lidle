// ============================================================
// "Главная функция и корневой виджет приложения"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lidle/pages/profile_menu/settings/contact_data/contact_data_screen.dart';
import 'package:lidle/pages/profile_menu/settings/privacy_settings/privacy_settings_screen.dart';
import 'package:lidle/pages/profile_menu/settings/chat_settings/chat_settings_screen.dart';
import 'package:lidle/pages/profile_menu/settings/username/username_screen.dart';
import 'package:lidle/pages/profile_menu/settings/change_photo/change_photo_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_event.dart';
import 'package:lidle/blocs/listings/listings_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/profile/profile_bloc.dart';
import 'package:lidle/blocs/password_recovery/password_recovery_bloc.dart';
import 'package:lidle/blocs/messages/messages_bloc.dart';
import 'package:lidle/blocs/messages/messages_event.dart';
import 'package:lidle/blocs/company_messages/company_messages_bloc.dart';
import 'package:lidle/blocs/company_messages/company_messages_event.dart';
import 'package:lidle/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:lidle/pages/filters_screen.dart';
import 'package:lidle/pages/auth/account_recovery.dart';
import 'package:lidle/pages/auth/register_screen.dart';
import 'package:lidle/pages/auth/register_verify_screen.dart';
import 'package:lidle/pages/auth/account_recovery_code.dart';
import 'package:lidle/pages/auth/account_recovery_new_password.dart';
import 'package:path_provider/path_provider.dart';
import 'constants.dart';
import 'pages/home_page.dart';
import 'pages/auth/sign_in_screen.dart';
import 'pages/profile_dashboard/profile_dashboard.dart';
import 'pages/profile_menu/profile_menu_screen.dart';
import 'pages/profile_menu/invite_friends/invite_friends_screen.dart';
import 'pages/profile_menu/invite_friends/find_by_phone_screen.dart';
import 'pages/profile_menu/invite_friends/connect_contacts_screen.dart';
import 'pages/profile_menu/settings/settings_screen.dart';
import 'pages/profile_menu/settings/devices/devices_screen.dart';
import 'pages/profile_menu/settings/delete_account/delete_account_screen.dart';
import 'pages/profile_menu/settings/privacy_policy/privacy_policy_screen.dart';
import 'pages/profile_menu/settings/faq/faq_screen.dart';
import 'pages/profile_menu/support_service_screen.dart';
import 'pages/favorites_screen.dart';
import 'pages/add_listing/add_listing_screen.dart';
import 'pages/add_listing/category_selection_screen.dart';
import 'pages/full_category_screen/full_category_screen.dart';
import 'pages/full_category_screen/map_screen.dart';
import 'pages/my_purchases_screen.dart';
import 'pages/messages/messages_page.dart'; // Corrected import
import 'pages/messages/messages_archive_page.dart';
import 'pages/profile_dashboard/user_messages/user_messages_list_screen.dart';
import 'pages/profile_dashboard/user_messages/user_messages_archive_list_screen.dart';
import 'pages/profile_dashboard/company_messages/company_messages_list_screen.dart';
import 'pages/profile_dashboard/company_messages/company_messages_archive_list_screen.dart';
import 'pages/profile_dashboard/offers/price_offers_empty_page.dart';
import 'pages/profile_dashboard/offers/price_accepted_page.dart';
import 'pages/profile_dashboard/offers/price_offers_list_page.dart'; // Import the new page
import 'pages/profile_dashboard/offers/incoming_price_offer_page.dart'; // Import the new page
import 'pages/profile_dashboard/offers/user_account_page.dart'; // Import UserAccountPage
import 'pages/profile_dashboard/offers/user_account_only_page.dart'; // Import UserAccountOnlyPage
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
import 'models/offer_model.dart';

// ============================================================
//  Главная функция
// Выполняет асинхронную инициализацию необходимых сервисов.
// ============================================================


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Загрузка переменных окружения
  await dotenv.load(fileName: kReleaseMode ? ".env.production" : ".env");

  if (kIsWeb) {
    await Hive.initFlutter();
  } else {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);
  }
  await HiveService.init();

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
//  Корневой виджет приложения
// ============================================================


class LidleApp extends StatelessWidget {
  /// Конструктор для LidleApp.
  const LidleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (context) => AuthBloc()..add(const CheckAuthStatusEvent())),
        BlocProvider<ListingsBloc>(create: (context) => ListingsBloc()),
        BlocProvider<NavigationBloc>(create: (context) => NavigationBloc()),
        BlocProvider<ProfileBloc>(create: (context) => ProfileBloc()),
        BlocProvider<PasswordRecoveryBloc>(
          create: (context) => PasswordRecoveryBloc(),
        ),
        BlocProvider<MessagesBloc>(create: (context) => MessagesBloc()..add(LoadMessages())),
        BlocProvider<CompanyMessagesBloc>(create: (context) => CompanyMessagesBloc()..add(LoadCompanyMessages())),
        BlocProvider<CartBloc>(create: (context) => CartBloc()),
      ],
      child: MaterialApp(
        title: appTitle,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          // scaffoldBackgroundColor: primaryBackground,
          fontFamily: 'Roboto',
          brightness: Brightness.dark,
        ),
        home: const HomePage(),
        // home: const FiltersCoworkingScreenen(),


        routes: {
          SignInScreen.routeName: (context) => const SignInScreen(),
          ProfileMenuScreen.routeName: (context) => const ProfileMenuScreen(),
          InviteFriendsScreen.routeName: (context) => const InviteFriendsScreen(),
          FindByPhoneScreen.routeName: (context) => const FindByPhoneScreen(),
          ConnectContactsScreen.routeName: (context) => const ConnectContactsScreen(),
          SettingsScreen.routeName: (context) => const SettingsScreen(),
          '/contact_data': (context) => ContactDataScreen(),
          '/privacy_settings': (context) => const PrivacySettingsScreen(),
          '/chat_settings': (context) => const ChatSettingsScreen(),
          '/username': (context) => const UsernameScreen(),
          '/change_photo': (context) => const ChangePhotoScreen(),
          '/devices': (context) => const DevicesScreen(),
          QrScannerScreen.routeName: (context) => const QrScannerScreen(),
          DeleteAccountScreen.routeName: (context) => const DeleteAccountScreen(),
          PrivacyPolicyScreen.routeName: (context) => const PrivacyPolicyScreen(),
          FaqScreen.routeName: (context) => const FaqScreen(),
          SupportServiceScreen.routeName: (context) => const SupportServiceScreen(),
          AccountRecovery.routeName: (context) => const AccountRecovery(),
          RegisterScreen.routeName: (context) => const RegisterScreen(),
          RegisterVerifyScreen.routeName: (context) =>
              const RegisterVerifyScreen(),
          AccountRecoveryCode.routeName: (context) =>
              const AccountRecoveryCode(),
          AccountRecoveryNewPassword.routeName: (context) =>
              const AccountRecoveryNewPassword(),
          ProfileDashboard.routeName: (context) => const ProfileDashboard(),
          FiltersScreen.routeName: (context) => const FiltersScreen(),
          FavoritesScreen.routeName: (context) => const FavoritesScreen(),
          AddListingScreen.routeName: (context) => const AddListingScreen(),
          CategorySelectionScreen.routeName: (context) => const CategorySelectionScreen(),
          CartScreen.routeName: (context) => const CartScreen(),
          FullCategoryScreen.routeName: (context) => const FullCategoryScreen(),
          MapScreen.routeName: (context) => const MapScreen(),
          MyPurchasesScreen.routeName: (context) =>  MyPurchasesScreen(), // Add the new route
          MessagesPage.routeName: (context) => const MessagesPage(), // Corrected route
          MessagesArchivePage.routeName: (context) => const MessagesArchivePage(),
          UserMessagesListScreen.routeName: (context) => const UserMessagesListScreen(),
          UserMessagesArchiveListScreen.routeName: (context) => const UserMessagesArchiveListScreen(),
          CompanyMessagesListScreen.routeName: (context) => const CompanyMessagesListScreen(),
          CompanyMessagesArchiveListScreen.routeName: (context) => const CompanyMessagesArchiveListScreen(),
          PriceOffersEmptyPage.routeName: (context) => const PriceOffersEmptyPage(),
          PriceAcceptedPage.routeName: (context) => PriceAcceptedPage(offer: ModalRoute.of(context)!.settings.arguments as Offer),
          PriceOffersListPage.routeName: (context) => PriceOffersListPage(offer: ModalRoute.of(context)!.settings.arguments as Offer), // Add new route
          IncomingPriceOfferPage.routeName: (context) => IncomingPriceOfferPage(offerItem: ModalRoute.of(context)!.settings.arguments as PriceOfferItem),
          UserAccountPage.routeName: (context) => UserAccountPage(offerItem: ModalRoute.of(context)!.settings.arguments as PriceOfferItem),
          UserAccountOnlyPage.routeName: (context) => UserAccountOnlyPage(offerItem: ModalRoute.of(context)!.settings.arguments as PriceOfferItem),
          SupportScreen.routeName: (context) => const SupportScreen(),
          DiscountsAndPromotionsPage.routeName: (context) => const DiscountsAndPromotionsPage(),
          SupportChatPage.routeName: (context) => const SupportChatPage(),
          ResponsesEmptyPage.routeName: (context) => const ResponsesEmptyPage(),
          ReviewsEmptyPage.routeName: (context) => const ReviewsEmptyPage(),
          MyListingsScreen.routeName: (context) => const MyListingsScreen(),
          '/contacts': (context) => const ContactsScreen(),
          '/user_qr': (context) => const UserQrScreen(),
          '/qr_print_templates': (context) => const QrPrintTemplatesScreen(),
        },
      ),
    );
  }
}
