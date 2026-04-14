import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lidle/core/logger.dart';

/// Диалоговое окно финансовой поддержки владельца LIDLE
/// Отображает призыв к пожертвованиям с ссылкой на Тинькофф
class FinancialSupportDialog {
  static const String _tinkoffUrl = 'https://www.tbank.ru/cf/5qAdXjeRcgu';

  /// Показывает диалоговое окно финансовой поддержки
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: const Color(0xFF2A2A2A),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Кнопка закрытия
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Основной текст
                const Text(
                  'Ваш вклад — энергия для новых функций и быстрого роста.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                // const SizedBox(height: 12),
                // Ссылка
                GestureDetector(
                  onTap: () => _launchTinkoffLink(context),
                  child: const Text(
                    _tinkoffUrl,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      // decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                // const SizedBox(height: 12),
                // Описание
                const Text(
                  'Перейдите по ссылке, чтобы отправить любую сумму. Каждый ваш ресурс делает сервис лучше и доступнее.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Открывает ссылку Тинькофф в браузере
  static Future<void> _launchTinkoffLink(BuildContext context) async {
    try {
      final uri = Uri.parse(_tinkoffUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        log.e('Не удалось открыть ссылку: $_tinkoffUrl');
        _showErrorSnackBar(context, 'Не удалось открыть ссылку');
      }
    } catch (e) {
      log.e('Ошибка при открытии ссылки: $e');
      _showErrorSnackBar(context, 'Ошибка при открытии ссылки');
    }
  }

  /// Показывает сообщение об ошибке
  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
