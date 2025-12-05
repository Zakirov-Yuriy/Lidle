import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_state.dart';
import 'package:lidle/pages/auth/sign_in_screen.dart';

class ProfileMenuScreen extends StatelessWidget {
  static const routeName = '/profile-menu';

  const ProfileMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthInitial || (state is AuthError && !(state is AuthAuthenticated))) {
          Navigator.of(context).pushReplacementNamed(SignInScreen.routeName);
        }
      },
      child: Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
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
      ),
    );
  }

  /* ------------------------ UI COMPONENTS ------------------------ */

  
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
