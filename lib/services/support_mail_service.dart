// ============================================================
// "Сервис: Отправка писем в поддержку через Formspree"
// ============================================================

import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:logger/logger.dart';

class SupportMailService {
  // ✅ Замените на ваш ID формы из Formspree
  // Инструкция: https://formspree.io/
  // 1. Зайдите на formspree.io
  // 2. Создайте новую форму с email info@lidle.io
  // 3. Скопируйте ID вида: xxxxxx
  static const String _formspreeFormId = 'mykbnvrg';
  static const String _formspreeUrl =
      'https://formspree.io/f/$_formspreeFormId';

  final Logger _logger = Logger();

  /// Отправить письмо в поддержку (с опциональным скриншотом)
  Future<Map<String, dynamic>> sendSupportEmail({
    required String name,
    required String email,
    required String subject,
    required String message,
    String? screenshotPath,
  }) async {
    try {
      _logger.i('📧 Отправка письма в поддержку...');

      final request = http.MultipartRequest('POST', Uri.parse(_formspreeUrl));
      
      // Добавить поля формы
      request.fields['name'] = name;
      request.fields['email'] = email;
      request.fields['subject'] = subject;
      request.fields['message'] = message;
      request.fields['_replyto'] = email;

      // Добавить скриншот, если есть
      if (screenshotPath != null && screenshotPath.isNotEmpty) {
        final file = File(screenshotPath);
        if (await file.exists()) {
          _logger.i('📎 Прикрепляем скриншот: $screenshotPath');
          final stream = http.ByteStream(file.openRead());
          final length = await file.length();
          
          request.files.add(
            http.MultipartFile(
              'screenshot',
              stream,
              length,
              filename: 'screenshot_${DateTime.now().millisecondsSinceEpoch}.png',
            ),
          );
        } else {
          _logger.w('⚠️ Файл скриншота не найден: $screenshotPath');
        }
      }

      final response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Timeout при отправке'),
      );

      _logger.i('📧 Получен ответ: ${response.statusCode}');

      if (response.statusCode == 200) {
        _logger.i('✅ Письмо успешно отправлено');
        return {
          'success': true,
          'message': 'Письмо успешно отправлено в поддержку',
        };
      } else {
        _logger.w('❌ Ошибка отправки: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Ошибка отправки письма: ${response.statusCode}',
        };
      }
    } on http.ClientException catch (e) {
      _logger.e('❌ Ошибка подключения: $e');
      return {
        'success': false,
        'message': 'Ошибка подключения: ${e.message}',
      };
    } catch (e) {
      _logger.e('❌ Неизвестная ошибка: $e');
      return {
        'success': false,
        'message': 'Ошибка: $e',
      };
    }
  }
}
