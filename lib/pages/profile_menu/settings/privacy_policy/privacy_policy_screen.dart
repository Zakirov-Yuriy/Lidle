// ============================================================
// "Виджет: Экран политики конфиденциальности"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/core/config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';

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
                    'Документы',
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

            // ───── Content (menu list like on the screenshot) ─────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // local builder for menu item
                    Builder(
                      builder: (context) {
                        Widget menuItem(String title, {String? url}) {
                          return InkWell(
                            onTap: () async {
                              if (url != null) {
                                final uri = Uri.parse(url);
                                try {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                } catch (_) {}
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16.0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        color: textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: textPrimary,
                                    size: 25,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            menuItem(
                              'Пользовательское соглашение',
                              url: AppConfig().userAgreementUrl,
                            ),
                            const Divider(color: dividerColor, height: 0),
                            menuItem(
                              'Оферта',
                              url: AppConfig().publicOfferUrl,
                            ),
                            const Divider(color: dividerColor, height: 0),
                            menuItem(
                              'Согласие на обработку персональных данных',
                              url: AppConfig().consentUrl,
                            ),
                            const Divider(color: dividerColor, height: 0),
                            menuItem(
                              'Политика конфиденциальности',
                              url: AppConfig().privacyPolicyUrl,
                            ),
                            const Divider(color: dividerColor, height: 0),
                            menuItem(
                              'Согласие получение сообщений рекламного и информационного характера',
                              url: AppConfig().mailingUrl,
                            ),
                          ],
                        );
                      },
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
