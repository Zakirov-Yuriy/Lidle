import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/pages/account_recovery.dart';
import 'package:lidle/pages/register_screen.dart';
import 'package:lidle/pages/register_verify_screen.dart';
import 'package:lidle/pages/account_recovery_code.dart';
import 'package:lidle/pages/account_recovery_new_password.dart';
import 'package:path_provider/path_provider.dart';
import 'constants.dart';
import 'pages/home_page.dart';
import 'pages/sign_in_screen.dart';

/// Главная функция, точка входа в приложение.
/// Выполняет асинхронную инициализацию необходимых сервисов.
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

/// Корневой виджет приложения Lidle.
/// Определяет основные настройки приложения, такие как заголовок, тема и маршруты.
class LidleApp extends StatelessWidget {
  /// Конструктор для LidleApp.
  const LidleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: primaryBackground,
        fontFamily: 'Roboto',
      ),
      home: const HomePage(),

      routes: {
        SignInScreen.routeName: (context) => const SignInScreen(),
        AccountRecovery.routeName: (context) => const AccountRecovery(),
        RegisterScreen.routeName: (context) => const RegisterScreen(),
        RegisterVerifyScreen.routeName: (context) => const RegisterVerifyScreen(),
        AccountRecoveryCode.routeName: (context) => const AccountRecoveryCode(),
        AccountRecoveryNewPassword.routeName: (context) => const AccountRecoveryNewPassword(),
      },
    );
  }
}
