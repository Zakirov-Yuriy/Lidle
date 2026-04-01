// ============================================================
// "Определение маршрутов приложения"
// ============================================================
// Служит для углубления иерархии навигации:
// - Все маршруты определены в одном месте
// - Легче отслеживать все доступные экраны
// - Разгружает main.dart (было 400+ строк, теперь 300-)
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/pages/profile_menu/settings/contact_data/contact_data_screen.dart';
import 'package:lidle/pages/profile_menu/settings/privacy_settings/privacy_settings_screen.dart';
import 'package:lidle/pages/profile_menu/settings/chat_settings/chat_settings_screen.dart';
import 'package:lidle/pages/profile_menu/settings/username/username_screen.dart';
import 'package:lidle/pages/profile_menu/settings/change_photo/change_photo_screen.dart';
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
import 'package:lidle/pages/auth/account_recovery.dart';
import 'package:lidle/pages/auth/register_screen.dart';
import 'package:lidle/pages/auth/register_verify_screen.dart';
import 'package:lidle/pages/auth/account_recovery_code.dart';
import 'package:lidle/pages/auth/account_recovery_new_password.dart';
import 'package:lidle/pages/favorites_screen.dart';
import 'package:lidle/pages/add_listing/add_listing_screen.dart';
import 'package:lidle/pages/add_listing/category_selection_screen.dart';
import 'package:lidle/pages/add_listing/payment_screen.dart';
import 'package:lidle/pages/full_category_screen/full_category_screen.dart';
import 'package:lidle/pages/full_category_screen/property_details_screen.dart';
import 'package:lidle/pages/full_category_screen/map_screen.dart';
import 'package:lidle/pages/my_purchases_screen.dart';
import 'package:lidle/pages/messages/messages_page.dart';
import 'package:lidle/pages/messages/messages_archive_page.dart';
import 'package:lidle/pages/profile_dashboard/user_messages/user_messages_list_screen.dart';
import 'package:lidle/pages/profile_dashboard/user_messages/user_messages_archive_list_screen.dart';
import 'package:lidle/pages/profile_dashboard/company_messages/company_messages_list_screen.dart';
import 'package:lidle/pages/profile_dashboard/company_messages/company_messages_archive_list_screen.dart';
import 'package:lidle/pages/profile_dashboard/offers/price_offers_empty_page.dart';
import 'package:lidle/pages/profile_dashboard/offers/price_accepted_page.dart';
import 'package:lidle/pages/profile_dashboard/offers/price_offers_list_page.dart';
import 'package:lidle/pages/profile_dashboard/offers/incoming_price_offer_page.dart';
import 'package:lidle/pages/profile_dashboard/offers/user_account_page.dart';
import 'package:lidle/pages/profile_dashboard/offers/user_account_only_page.dart';
import 'package:lidle/pages/profile_dashboard/support/support_screen.dart';
import 'package:lidle/pages/profile_dashboard/support/discounts_and_promotions_page.dart';
import 'package:lidle/pages/profile_dashboard/support/support_chat_page.dart';
import 'package:lidle/pages/profile_dashboard/responses/responses_empty_page.dart';
import 'package:lidle/pages/profile_dashboard/reviews/reviews_empty_page.dart';
import 'package:lidle/pages/profile_dashboard/my_listings/my_listings_screen.dart';
import 'package:lidle/features/cart/presentation/pages/cart_screen.dart';
import 'package:lidle/pages/profile_menu/settings/devices/qr_scanner/qr_scanner_screen.dart';
import 'package:lidle/pages/profile_menu/contacts/contacts_screen.dart';
import 'package:lidle/pages/profile_menu/user_qr/user_qr_screen.dart';
import 'package:lidle/pages/profile_menu/user_qr/qr_print_templates_screen.dart';
import 'package:lidle/models/offer_model.dart';
import 'package:lidle/pages/filters_screen.dart';

/// ============================================================
/// Централизованное определение маршрутов приложения
/// 
/// Преимущества:
/// 1. Единая точка входа для всех маршрутов
/// 2. Легче поддерживать и отслеживать навигацию
/// 3. Разгружает main.dart
/// 4. Логика навигации не меняется, только место хранения
/// ============================================================
class AppRoutes {
  /// Возвращает Map всех маршрутов для использования в MaterialApp
  static Map<String, WidgetBuilder> get routes => {
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
        MyPurchasesScreen(),
    MessagesPage.routeName: (context) =>
        const MessagesPage(),
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
    ),
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
  };
}
