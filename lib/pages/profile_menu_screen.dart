import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lidle/constants.dart';

class ProfileMenuScreen extends StatelessWidget {
  static const routeName = '/profile-menu';

  const ProfileMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 31, vertical: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 41.0, bottom: 37.0),
                child: Row(
                  children: [
                    SvgPicture.asset(logoAsset, height: logoHeight),
                    const Spacer(),
                  ],
                ),
              ),

              _buildSearchBar(context),
              const SizedBox(height: 19),

              const Text(
                'Личная информация',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              _buildMainProfile(),
              const SizedBox(height: 22),
              const Divider(color: Color(0x33FFFFFF)),
              const SizedBox(height: 18),

              _buildAccountsBlock(),
              const SizedBox(height: 16),

              const Divider(color: Color(0x33FFFFFF)),
              const SizedBox(height: 20),

              _buildMenuItem(Icons.qr_code_rounded, 'QR код'),
              _buildMenuItem(Icons.credit_card, 'Ваши карты'),
              _buildMenuItem(Icons.phone, 'Контакты'),
              const SizedBox(height: 23),

              const Divider(color: Color(0x33FFFFFF)),

              _buildMenuItem(Icons.settings, 'Настройки'),

              const Divider(color: Color(0x33FFFFFF)),
              const SizedBox(height: 13),

              _buildMenuItem(Icons.support_agent, 'Служба поддержки'),
              _buildMenuItem(Icons.person_add_alt, 'Пригласить друзей'),
              _buildMenuItem(
                Icons.sentiment_satisfied_alt,
                'Возможности LIDLE',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ------------------------ UI COMPONENTS ------------------------ */

  Widget _buildLogo() {
    return Center(child: Image.asset(logoAsset, height: logoHeight));
  }

  Widget _buildSearchBar(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.close, color: Colors.white),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: secondaryBackground,
              borderRadius: BorderRadius.circular(5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Поиск',
                    style: TextStyle(color: textSecondary, fontSize: 16),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/filters'),
                  child: SvgPicture.asset(
                    settingsIconAsset,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      textSecondary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainProfile() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Аватар
        ClipRRect(
          borderRadius: BorderRadius.circular(60),
          child: Image.asset(
            'assets/profile_dashboard/Ellipse.png',
            width: 102,
            height: 102,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 23),

        // ИМЯ + ТЕЛЕФОН + НИК
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Vlad',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  '+7 949 609 59 28',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                SizedBox(height: 7),
                Text(
                  '@Namename',
                  style: TextStyle(color: Color(0xFF009EE2), fontSize: 14),
                ),
              ],
            ),
          ],
        ),

        const Spacer(),

        Column(
          children: [
            const Text(
              'Покупатель',
              style: TextStyle(
                color: Color(0xFFEAEF00),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountsBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Padding(
              padding: EdgeInsets.only(left: 30.0),
              child: Text(
                'Владислав',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            Spacer(),
            Text(
              'Компания',
              style: TextStyle(color: Color(0xFF19D849), fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 30.0),
          child: const Text(
            'Бизнес аккаунт',
            style: TextStyle(color: Color(0xFF009EE2), fontSize: 14),
          ),
        ),
        const SizedBox(height: 23),

        // Добавить аккаунт
        Row(
          children: const [
            Icon(Icons.add, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              'Добавить аккаунт',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 14),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }
}
