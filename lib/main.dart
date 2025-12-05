import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_event.dart';
import 'package:lidle/blocs/listings/listings_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/profile/profile_bloc.dart';
import 'package:lidle/blocs/password_recovery/password_recovery_bloc.dart';
import 'package:lidle/pages/filters_screen.dart';
import 'package:lidle/pages/account_recovery.dart';
import 'package:lidle/pages/register_screen.dart';
import 'package:lidle/pages/register_verify_screen.dart';
import 'package:lidle/pages/account_recovery_code.dart';
import 'package:lidle/pages/account_recovery_new_password.dart';
import 'package:path_provider/path_provider.dart';
import 'constants.dart';
import 'pages/home_page.dart';
import 'pages/sign_in_screen.dart';
import 'pages/profile_dashboard.dart';
import 'pages/profile_menu_screen.dart';
import 'pages/favorites_screen.dart';
import 'pages/add_listing_screen.dart';
import 'pages/category_selection_screen.dart';
import 'pages/full_category_screen/full_category_screen.dart';
import 'pages/full_category_screen/map_screen.dart';
import 'pages/my_purchases_screen.dart'; // Import the new screen

// ============================================================
//  Главная функция
// Выполняет асинхронную инициализацию необходимых сервисов.
// ============================================================


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Hive.initFlutter();
  } else {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);
  }
  await HiveService.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
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
      ],
      child: MaterialApp(
        title: appTitle,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: primaryBackground,
          fontFamily: 'Roboto',
        ), 
        home: const HomePage(),
        // home: const RealEstateListingsScreen(),
       

        routes: {
          SignInScreen.routeName: (context) => const SignInScreen(),
          ProfileMenuScreen.routeName: (context) => const ProfileMenuScreen(),
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
          FullCategoryScreen.routeName: (context) => const FullCategoryScreen(),
          MapScreen.routeName: (context) => const MapScreen(),
          MyPurchasesScreen.routeName: (context) => const MyPurchasesScreen(), // Add the new route
        },
      ),
    );
  }
}
