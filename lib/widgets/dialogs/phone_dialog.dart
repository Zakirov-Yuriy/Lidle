// ============================================================
//  "Диалог телефона"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lidle/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lidle/core/logger.dart';

class PhoneDialog extends StatelessWidget {
  final List<String> phoneNumbers;

  const PhoneDialog({super.key, required this.phoneNumbers});

  /// 🎨 Красиво форматирует номер для показа: «+7 949 456-78-90».
  /// Только для отображения — на звонок не влияет (там номер чистится до цифр).
  /// Если формат не распознан, возвращает исходную строку как есть.
  String _formatPhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');

    // Приводим к 11 цифрам с кодом страны 7.
    if (digits.length == 11 && digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    } else if (digits.length == 10) {
      digits = '7$digits';
    }

    if (digits.length == 11 && digits.startsWith('7')) {
      final code = digits.substring(1, 4); // 949
      final a = digits.substring(4, 7); // 456
      final b = digits.substring(7, 9); // 78
      final c = digits.substring(9, 11); // 90
      return '+7 $code $a-$b-$c';
    }

    // Неизвестный формат — не трогаем.
    return raw;
  }

  /// 📞 Инициирует звонок на номер телефона
  /// Удаляет все нецифровые символы перед вызовом
  /// Использует url_launcher для открытия диалера телефона
  /// При ошибке предлагает fallback на SMS
  Future<void> _makePhoneCall(String phoneNumber, BuildContext context) async {
    try {
      // Очищаем номер от всех символов кроме цифр и +
      final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      // log.d('📋 Attempting to call: $cleanedNumber (original: $phoneNumber)');

      // Создаём tel: URI
      final Uri launchUri = Uri(
        scheme: 'tel',
        path: cleanedNumber,
      );

      // Проверяем, можно ли открыть этот URI
      if (await canLaunchUrl(launchUri)) {
        // log.i('✅ Launching call to: $cleanedNumber');
        await launchUrl(launchUri);
      } else {
        // log.w('❌ Could not launch tel: $launchUri, trying SMS fallback...');
        // Fallback на SMS
        await _showPhoneOptions(phoneNumber, cleanedNumber, context);
      }
    } catch (e) {
      // log.e('❌ Error making phone call: $e');
      if (context.mounted) {
        await _showPhoneOptions(phoneNumber, phoneNumber, context);
      }
    }
  }

  /// 📱 Показывает диалог с опциями контакта
  /// Позволяет выбрать звонок или SMS
  Future<void> _showPhoneOptions(
    String displayNumber,
    String cleanedNumber,
    BuildContext context,
  ) async {
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: primaryBackground,
        title: const Text(
          'Не удалось выполнить звонок',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Попробуйте отправить СМС на номер $displayNumber или звоните вручную.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Копируем номер в буфер обмена
              await _copyToClipboard(cleanedNumber, context);
            },
            child: const Text('Скопировать номер', style: TextStyle(color: Color(0xFF19D849))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Пробуем отправить SMS
              await _sendSMS(cleanedNumber, context);
            },
            child: const Text('Отправить СМС', style: TextStyle(color: Color(0xFF19D849))),
          ),
        ],
      ),
    );
  }

  /// 📋 Копирует номер в буфер обмена
  Future<void> _copyToClipboard(String number, BuildContext context) async {
    try {
      // ignore: deprecated_member_use
      await Clipboard.setData(ClipboardData(text: number));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Номер $number скопирован в буфер обмена'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // log.e('❌ Error copying to clipboard: $e');
    }
  }

  /// 💬 Отправляет SMS на номер
  Future<void> _sendSMS(String phoneNumber, BuildContext context) async {
    try {
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phoneNumber,
      );

      if (await canLaunchUrl(smsUri)) {
        // log.i('✅ Launching SMS to: $phoneNumber');
        await launchUrl(smsUri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось открыть приложение СМС'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // log.e('❌ Error sending SMS: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ограничиваем высоту диалога, чтобы при большом числе номеров он не
    // выходил за экран; список номеров делаем прокручиваемым.
    final maxHeight = MediaQuery.of(context).size.height * 0.7;

    // Показываем только два последних номера.
    final visibleNumbers = phoneNumbers.length > 2
        ? phoneNumbers.sublist(phoneNumbers.length - 2)
        : phoneNumbers;
    return Dialog(
      backgroundColor: primaryBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: primaryBackground,
          borderRadius: BorderRadius.circular(5),
        ),
        constraints: BoxConstraints(maxHeight: maxHeight),
        padding: const EdgeInsets.only(left: 25.0, right: 25.0, bottom: 20.0, top: 10.0),
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

            // Список номеров телефонов (только два последних)
            if (visibleNumbers.isEmpty)
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
              // Прокручиваемый список — при большом числе номеров не
              // переполняет диалог, а скроллится внутри ограниченной высоты.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: visibleNumbers.map((number) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Номер телефона (красиво отформатирован).
                            Text(
                              _formatPhone(number),
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
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}