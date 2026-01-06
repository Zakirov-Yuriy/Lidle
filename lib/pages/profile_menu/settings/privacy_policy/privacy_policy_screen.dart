import 'package:flutter/material.dart';
import 'package:lidle/widgets/components/header.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  static const routeName = '/privacy_policy';

  const PrivacyPolicyScreen({super.key});

  static const bgColor = Color(0xFF243241);
  static const dividerColor = Colors.white24;
  static const textPrimary = Colors.white;
  static const textSecondary = Colors.white70;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ───── Header ─────
            Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 23),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [const Header()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      color: Color.fromARGB(255, 255, 255, 255),
                      size: 16,
                    ),
                  ),
                  const Text(
                    'Политика конфидициальности',
                    style: TextStyle(
                      color: Color.fromARGB(255, 255, 255, 255),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(color: dividerColor, height: 0),

            // ───── Content ─────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    // ───── Section 1 ─────
                    Text(
                      'Отказ от ответственности',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Материалы и услуги этого сайта предоставляются «как есть» '
                      'без каких-либо гарантий. Розетка не гарантирует точности и '
                      'полноты материалов, программ и услуг, предоставляемых на '
                      'этом Сайте. В любое время без уведомления может вносить '
                      'изменения в материалы и услуги, предоставляемые на этом '
                      'Сайте, а также в упомянутые в них продукты и цены. В случае '
                      'устаревания материалов и услуг на этом Сайте Розетка не '
                      'обязуется обновлять их. Розетка ни при каких обстоятельствах '
                      'не несет ответственности за любой ущерб (включая, но не '
                      'ограничиваясь ущербом от потери прибыли, данных или от '
                      'прерывания деловой активности), возникший вследствие '
                      'использования, невозможности использования или результатов '
                      'использования этого сайта.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),

                    SizedBox(height: 24),

                    // ───── Section 2 ─────
                    Text(
                      'Первичная документация',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 18),
                    Divider(color: dividerColor),
                    SizedBox(height: 14),
                    Text(
                      'При разработке технической документации на проект это стоит '
                      'обязательно учитывать, так как интерфейс нагляден и на его '
                      'основе проще проводить разделение проекта на разделы. Да и '
                      'сама модель предметной области очень хорошо описывается '
                      'интерфейсом — в ней необходимо учитывать в основном те '
                      'данные (и их производные), которые вводятся пользователем, '
                      'отображаются на экране и управляют его поведением. '
                      'Бизнес-сценарии также напрямую завязаны на поведение '
                      'пользовательского интерфейса.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
