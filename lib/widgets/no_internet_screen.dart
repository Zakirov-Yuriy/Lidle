// ============================================================
// "Экран отсутствия интернета"
// Отображается когда у пользователя нет соединения с интернетом
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/widgets/components/header.dart';

class NoInternetScreen extends StatelessWidget {
  /// Callback для повторной попытки (перезагрузки страницы)
  final VoidCallback onRetry;

  const NoInternetScreen({
    super.key,
    required this.onRetry,
  });

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
                    const Center(
                      child: Text(
                        'Нет соединения с интернетом',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Подтекст с описанием
                    const Center(
                      child: Text(
                        'Страница будет загружена, как только вы вернетесь в сеть',
                        textAlign: TextAlign.center,
                        style: TextStyle(
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
