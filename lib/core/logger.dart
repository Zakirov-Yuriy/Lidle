import 'package:logger/logger.dart';

/// Глобальный экземпляр логгера для всего приложения
final log = Logger(
  printer: SimplePrinter(colors: true),
);
