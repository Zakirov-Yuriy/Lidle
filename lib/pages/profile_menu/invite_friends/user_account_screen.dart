import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';

class UserAccountScreen extends StatelessWidget {
  static const routeName = '/user-account';

  final String? name;
  final String? phone;

  const UserAccountScreen({super.key, this.name, this.phone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF243241),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            // ───── Header ─────
            Padding(
              padding: const EdgeInsets.only(bottom: 30, right: 23),
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
                    'Аккаунт пользователя',
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

            // Profile info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: formBackground,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white24,
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name ?? 'Данил Данилов',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'В сети',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: activeIconColor,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: TextButton(
                        onPressed: () {},
                        child: const Text(
                          'Подписаться',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: TextButton(
                        onPressed: () {},
                        child: const Text(
                          'Написать',
                          style: TextStyle(
                            color: activeIconColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            const Divider(color: Colors.white10, height: 0),

            // User Details
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 20,
                ),
                children: [
                  _buildDetailItem(
                    'Номер аккаунта',
                    phone ?? '+7 949 545 54 45',
                  ),
                  const SizedBox(height: 20),
                  _buildDetailItem('Имя аккаунта', name ?? '@Postroisam'),
                  const SizedBox(height: 20),
                  _buildDetailItem('Напишите немного о себе', 'О себе'),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10, height: 0),
                  const SizedBox(height: 18),
                  const Text(
                    'Qr-код аккаунта',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  // const SizedBox(height: 15),
                  // Заполнитель для QR кода
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Icon(
                      Icons.qr_code_2,
                      color: Colors.white,
                      size: 120,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    height: 53,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: Colors.red.withOpacity(0.5)),
                    ),
                    child: TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Пожаловаться на аккаунт',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
