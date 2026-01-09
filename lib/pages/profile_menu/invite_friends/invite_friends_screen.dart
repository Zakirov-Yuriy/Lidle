// ============================================================
// "Виджет: Экран приглашения друзей"
// ============================================================

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/pages/profile_menu/invite_friends/find_by_phone_screen.dart';
import 'package:lidle/pages/profile_menu/invite_friends/connect_contacts_screen.dart';

class InviteFriendsScreen extends StatelessWidget {
  static const routeName = '/invite-friends';

  const InviteFriendsScreen({super.key});

  static const bgColor = primaryBackground;
  static const cardBlue = Color(0xFF00A3E0);
  static const accentColor = Color(0xFF00B7FF);

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
                    'Пригласить друзей',
                    style: TextStyle(
                      color: Color.fromARGB(255, 255, 255, 255),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Отмена',
                      style: TextStyle(color: activeIconColor, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ───── Blue Card ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, ConnectContactsScreen.routeName),
                child: Container(
                  height: 96,
                  decoration: BoxDecoration(
                    color: cardBlue,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Подключить контакты',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                 Icon(
                                  Icons.chevron_right,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ],
                            ),
                            SizedBox(height: 1),
                            Text(
                              'Все ваши контакты здесь',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Image.asset(
                        'assets/profile_menu/frends.png',
                        width: 85,
                        height: 91,
                      ),
                      const SizedBox(width: 36),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ───── Actions ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                children: [
                  _ActionRow(
                    leading: Image.asset('assets/profile_menu/Icon1.png', width: 24, height: 24, color: InviteFriendsScreen.accentColor),
                    title: 'Пригласить по QR-коду',
                    onTap: () => _showQrDialog(context),
                  ),
                  const SizedBox(height: 16),
                  _ActionRow(leading: Image.asset('assets/profile_menu/link-03.png', width: 24, height: 24, color: InviteFriendsScreen.accentColor), title: 'Пригласить по ссылке', onTap: () => Share.share('Приглашаю тебя в приложение LIDLE! Скачай и присоединяйся к нам.')),
                  const SizedBox(height: 16),
                  _ActionRow(leading: Image.asset('assets/profile_menu/Icon3.png', width: 24, height: 24, color: InviteFriendsScreen.accentColor), title: 'Найти по телефону', onTap: () => Navigator.pushNamed(context, FindByPhoneScreen.routeName)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQrDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF131C24), // Темный фон как на картинке
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ],
                ),
                const Text(
                  'Ваш QR-код',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: 'https://lidle.app/invite/user_id_placeholder', // Здесь должна быть ссылка для приглашения
                    version: QrVersions.auto,
                    size: 200.0,
                    gapless: false,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () {
                      Share.share('Приглашаю тебя в приложение LIDLE! Скачай и присоединяйся к нам: https://lidle.app/invite/user_id_placeholder');
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: accentColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Поделиться',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// ACTION ROW
// ─────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final VoidCallback? onTap;

  const _ActionRow({required this.leading, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: InviteFriendsScreen.accentColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
