import 'package:logger/logger.dart';

/// Глобальный экземпляр логгера для всего приложения
final log = Logger(
  printer: PrettyPrinter(
    methodCount: 1,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
  ),
);
