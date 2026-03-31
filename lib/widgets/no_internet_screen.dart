// ============================================================
// "Экран отсутствия интернета или соединения не соответствует типу"
// Отображается когда у пользователя нет соединения с интернетом
// или соединение не соответствует его предпочтениям
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/widgets/components/header.dart';

class NoInternetScreen extends StatelessWidget {
  /// Callback для повторной попытки (перезагрузки страницы)
  final VoidCallback onRetry;
  
  /// Причина отключения: 'no_internet' или 'preference_not_met'
  final String reason;
  
  /// Доступные типы подключения
  final List<String> availableTypes;
  
  /// Предпочтение пользователя
  final String? preferredType;

  const NoInternetScreen({
    super.key,
    required this.onRetry,
    this.reason = 'no_internet',
    this.availableTypes = const [],
    this.preferredType,
  });

  /// Получает заголовок в зависимости от причины
  String _getTitle() {
    switch (reason) {
      case 'preference_not_met':
        return 'Интернет не соответствует предпочтениям';
      case 'no_internet':
      default:
        return 'Нет соединения с интернетом';
    }
  }

  /// Получает описание в зависимости от причины и доступных типов
  String _getDescription() {
    switch (reason) {
      case 'preference_not_met':
        if (preferredType == 'wifi' && availableTypes.contains('mobile')) {
          return 'Доступен только мобильный интернет.\n'
              'Измените предпочтения в настройках приватности\n'
              'или подключитесь к Wi-Fi';
        } else if (preferredType == 'mobile' && availableTypes.contains('wifi')) {
          return 'Доступен только Wi-Fi.\n'
              'Измените предпочтения в настройках приватности\n'
              'или используйте мобильный интернет';
        }
        return 'Текущее соединение не соответствует вашим предпочтениям.\n'
            'Измените предпочтения в настройках приватности';
      case 'no_internet':
      default:
        return 'Страница будет загружена, как только вы вернетесь в сеть';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F2A37),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // LIDLE логотип/название приложения (без боковых отступов)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [const Header()],
            ),

            const Spacer(),

            // Остальной контент с боковыми отступами
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Иконка отсутствия интернета
                    Center(
                      child: SvgPicture.asset(
                        'assets/connectivity/connectivity.svg',
                        width: 90,
                        height: 90,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Заголовок
                    Center(
                      child: Text(
                        _getTitle(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Подтекст с описанием
                    Center(
                      child: Text(
                        _getDescription(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                      ),
                    ),

                    const Spacer(),
                    const SizedBox(height: 14),

                    // Кнопка для повторной попытки
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onRetry,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF3B82F6)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Перезагрузить страницу',
                          style: TextStyle(
                            color: Color(0xFF3B82F6),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

