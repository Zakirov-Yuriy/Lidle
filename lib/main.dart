import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/pages/account_recovery.dart';
import 'package:lidle/pages/register_screen.dart';
import 'package:lidle/pages/register_verify_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'constants.dart';
import 'pages/home_page.dart';
import 'pages/signIn_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Hive
  if (kIsWeb) {
    // Для веб-платформы
    await Hive.initFlutter();
  } else {
    // Для мобильных платформ
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);
  }
  await HiveService.init();

  // Устанавливаем стиль системной панели
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const LidleApp());
}

class LidleApp extends StatelessWidget {
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
      },
    );
  }
}
