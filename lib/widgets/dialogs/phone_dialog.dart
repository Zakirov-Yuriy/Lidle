// ============================================================
//  "Диалог телефона"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:url_launcher/url_launcher.dart';

class PhoneDialog extends StatelessWidget {
  final List<String> phoneNumbers;

  const PhoneDialog({super.key, required this.phoneNumbers});

  /// 📞 Инициирует звонок на номер телефона
  /// Удаляет все нецифровые символы перед вызовом
  /// Использует url_launcher для открытия диалера телефона
  Future<void> _makePhoneCall(String phoneNumber, BuildContext context) async {
    try {
      // Очищаем номер от всех символов кроме цифр и +
      final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      print('📱 Attempting to call: $cleanedNumber (original: $phoneNumber)');

      // Создаём tel: URI
      final Uri launchUri = Uri(
        scheme: 'tel',
        path: cleanedNumber,
      );

      // Проверяем, можно ли открыть этот URI
      if (await canLaunchUrl(launchUri)) {
        print('✅ Launching call to: $cleanedNumber');
        await launchUrl(launchUri);
      } else {
        print('❌ Could not launch $launchUri');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Не удалось инициировать звонок на номер: $phoneNumber'),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error making phone call: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при инициировании звонка: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: primaryBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        decoration: BoxDecoration(
          color: primaryBackground,
          borderRadius: BorderRadius.circular(5),
        ),
        padding: const EdgeInsets.only(left: 25.0, right: 25.0, bottom: 43.0, top: 10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Кнопка закрытия
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            
            // Заголовок
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Телефоны продавца",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),

            // Список номеров телефонов
            if (phoneNumbers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Номера телефонов не найдены',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              )
            else
              ...phoneNumbers.asMap().entries.map((entry) {
                final index = entry.key;
                final number = entry.value;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Номер телефона
                      Text(
                        number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 10),
                      
                      // Кнопка звонка
                      GestureDetector(
                        onTap: () => _makePhoneCall(number, context),
                        child: Container(
                          height: 43,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(
                              color: const Color(0xFF19D849),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.phone,
                                  color: Color(0xFF19D849),
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Позвонить",
                                  style: TextStyle(
                                    color: Color(0xFF19D849),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}

