// ============================================================
// "Сервис: Отправка писем в поддержку через Formspree"
// ============================================================

import 'package:http/http.dart' as http;
import 'dart:convert';
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

  /// Отправить письмо в поддержку
  Future<Map<String, dynamic>> sendSupportEmail({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    try {
      _logger.i('📧 Отправка письма в поддержку...');

      final response = await http.post(
        Uri.parse(_formspreeUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'subject': subject,
          'message': message,
          '_replyto': email,
        }),
      ).timeout(
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
