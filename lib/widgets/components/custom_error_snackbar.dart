import 'package:flutter/material.dart';

/// Enum для определения типа сообщения в snackbar
enum SnackBarMessageType {
  error, // Ошибка - красный цвет
  success, // Успех - зеленый цвет
  info, // Информация - синий цвет
  warning, // Предупреждение - оранжевый цвет
  authRequired, // Требуется авторизация - с кнопкой действия
}

/// Универсальный компонент для отображения уведомлений
class CustomErrorSnackBar extends StatelessWidget {
  final String message;
  final VoidCallback? onClose;
  final SnackBarMessageType messageType;
  final String? actionButtonText;
  final VoidCallback? onActionPressed;

  const CustomErrorSnackBar({
    super.key,
    required this.message,
    this.onClose,
    this.messageType = SnackBarMessageType.error,
    this.actionButtonText,
    this.onActionPressed,
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
      case SnackBarMessageType.authRequired:
        return const Color(0xFF9CA3AF); // Серый для авторизации
      case SnackBarMessageType.error:
        return const Color(0xFFEF5350); // Красный
    }
  }

  /// Получить иконку на основе типа сообщения
  IconData get _icon {
    switch (messageType) {
      case SnackBarMessageType.success:
        return Icons.check_circle_rounded;
      case SnackBarMessageType.info:
        return Icons.info_rounded;
      case SnackBarMessageType.warning:
        return Icons.warning_amber_rounded;
      case SnackBarMessageType.authRequired:
        return Icons.error; // Восклицательный знак в кругле для авторизации
      case SnackBarMessageType.error:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Для сообщений об авторизации используем специальный дизайн с кнопкой
    if (messageType == SnackBarMessageType.authRequired) {
      return _buildAuthRequiredSnackBar(context);
    }

    // Стандартный дизайн для остальных типов
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
            Icon(_icon, color: _iconColor, size: 24.0),
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

  /// Построить специализированный снэкбар для авторизации
  Widget _buildAuthRequiredSnackBar(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF374151), // Темный серо-коричневый фон
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок с иконкой и текстом
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _icon,
                  color: _iconColor,
                  size: 28.0,
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.0,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            // Кнопка действия во всю ширину
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onActionPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F2937), // Еще более темный фон кнопки
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    // side: const BorderSide(
                    //   color: Color.fromARGB(255, 99, 75, 78),
                    //   width: 1.0,
                    // ),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  actionButtonText ?? 'Действие',
                  style: const TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
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

  /// Показать требуется авторизация с кнопкой действия
  static void showAuthRequired(
    BuildContext context,
    String message, {
    String? actionButtonText,
    VoidCallback? onActionPressed,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: CustomErrorSnackBar(
          message: message,
          messageType: SnackBarMessageType.authRequired,
          actionButtonText: actionButtonText ?? 'Войти или создать профиль',
          onActionPressed: onActionPressed ?? () => Navigator.of(context).pushNamed('/sign-in'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
      ),
    );
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
