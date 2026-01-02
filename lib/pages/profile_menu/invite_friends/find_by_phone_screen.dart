import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';

class FindByPhoneScreen extends StatefulWidget {
  static const routeName = '/find-by-phone';

  const FindByPhoneScreen({super.key});

  @override
  State<FindByPhoneScreen> createState() => _FindByPhoneScreenState();
}

class _FindByPhoneScreenState extends State<FindByPhoneScreen> {
  final TextEditingController _phoneController = TextEditingController();

  static const bgColor = Color(0xFF243241);
  static const cardColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const hintColor = Colors.white54;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
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
                    'Найти по телефону',
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
                      'Назад',
                      style: TextStyle(color: activeIconColor, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ───── Title ─────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 25),
              child: Text(
                'Введите номер телефона',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ───── Subtitle ─────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 25),
              child: Text(
                'Если владелец уже в LIDLE, вы сможете сразу начать общаться.',
                style: TextStyle(
                  color: hintColor,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 13),

            // ───── Phone input (UI) ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 25),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  children: [
                    // flag placeholder
                    const Text(
                      '🇷🇺',
                      style: TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white54,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '+7',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        autofocus: true,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: const InputDecoration(
                          hintText: '000 9254499550000 00 00',
                          hintStyle: TextStyle(
                            color: Colors.white38,
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ───── Continue button ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  onPressed: () {},
                  child: const Text(
                    'Продолжить',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
