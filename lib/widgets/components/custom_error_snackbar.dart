import 'package:flutter/material.dart';

/// Enum для определения типа сообщения в snackbar
enum SnackBarMessageType {
  error, // Ошибка - красный цвет
  success, // Успех - зеленый цвет
  info, // Информация - синий цвет
  warning, // Предупреждение - оранжевый цвет
}

/// Универсальный компонент для отображения уведомлений
class CustomErrorSnackBar extends StatelessWidget {
  final String message;
  final VoidCallback? onClose;
  final SnackBarMessageType messageType;

  const CustomErrorSnackBar({
    super.key,
    required this.message,
    this.onClose,
    this.messageType = SnackBarMessageType.error,
  });

  /// Получить цвет иконки на основе типа сообщения
  Color get _iconColor {
    switch (messageType) {
      case SnackBarMessageType.success:
        return const Color(0xFF4CAF50); // Зеленый
      case SnackBarMessageType.info:
        return const Color(0xFF2196F3); // Синий
      case SnackBarMessageType.warning:
        return const Color(0xFFFFC107); // Оранжевый
      case SnackBarMessageType.error:
        return const Color(0xFFEF5350); // Красный
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C), // Dark background color
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _iconColor, size: 24.0),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            if (onClose != null)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onClose,
              ),
          ],
        ),
      ),
    );
  }
}

/// Вспомогательный класс для простого показа снэкбаров
class SnackBarHelper {
  /// Показать ошибку
  static void showError(BuildContext context, String message) {
    _show(context, message, SnackBarMessageType.error);
  }

  /// Показать успех
  static void showSuccess(BuildContext context, String message) {
    _show(context, message, SnackBarMessageType.success);
  }

  /// Показать информацию
  static void showInfo(BuildContext context, String message) {
    _show(context, message, SnackBarMessageType.info);
  }

  /// Показать предупреждение
  static void showWarning(BuildContext context, String message) {
    _show(context, message, SnackBarMessageType.warning);
  }

  /// Внутренний метод для показа снэкбара
  static void _show(
    BuildContext context,
    String message,
    SnackBarMessageType type,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: CustomErrorSnackBar(
          message: message,
          messageType: type,
          onClose: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
