import 'package:flutter/material.dart';
import 'package:lidle/widgets/components/header.dart';

class ContactDataScreen extends StatelessWidget {
  static const routeName = '/contact_data';

  ContactDataScreen({super.key});

  static const bgColor = Color(0xFF243241);
  static const fieldColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const hintColor = Colors.white54;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ───── Header ─────
              Padding(
                padding: const EdgeInsets.only(bottom: 20, right: 23),
                child: Row(
                  children: const [Header()],
                ),
              ),

              // ───── Back row ─────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Контактные данные',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Назад',
                        style: TextStyle(color: accentColor, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ───── Description ─────
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 25),
                child: Text(
                  'На этой странице, вы указываете вашу личную информацию '
                  'которая будет видна в объявлениях',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ───── Fields ─────
              _label('Контактное лицо'),
              _field(initialValue: 'Александр'),

              _label('Электронная почта'),
              _field(initialValue: 'AlexAlex@mail.ru'),

              _label('Номер телефона 1'),
              _field(initialValue: '+7 949 456 65 56'),

              _label('Номер телефона 2'),
              _field(hint: 'Введите'),

              _label('Ссылка на ваш чат в телеграм'),
              _field(initialValue: 'https://t.me/Namename'),

              _label('Ссылка на ваш whatsapp'),
              _field(initialValue: 'https://whatsapp/Namename'),

              const SizedBox(height: 24),

              // ───── Save button ─────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: SizedBox(
                  width: double.infinity,
                  height: 47,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    onPressed: () {},
                    child: const Text(
                      'Сохранить',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  static Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 14, 25, 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  static Widget _field({String? initialValue, String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: fieldColor,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller:
              initialValue != null ? TextEditingController(text: initialValue) : null,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: hint,
            hintStyle: const TextStyle(color: hintColor),
          ),
        ),
      ),
    );
  }
}
