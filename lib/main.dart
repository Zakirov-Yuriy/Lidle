import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants.dart';
import 'pages/home_page.dart';

void main() {
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
    );
  }
}
