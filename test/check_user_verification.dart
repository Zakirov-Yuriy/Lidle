import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Токен пользователя workyury04@gmail.com
  final token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9yZWdpc3RlciIsImlhdCI6MTc3MDI3NDA0OCwiZXhwIjoxNzcwMjc3NjQ4LCJuYmYiOjE3NzAyNzQwNDgsImp0aSI6ImtIOGlHUVFjQ0lDQnlGdDUiLCJzdWIiOiI1OCIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.5-uWhkJurFUBZ8bQzrbxR0dtkxSzPkzOGIGzlp5Y9DM';

  try {
    print(
      '🔍 Проверяем статус верификации пользователя workyury04@gmail.com...\n',
    );

    final response = await http.get(
      Uri.parse('https://dev-api.lidle.io/v1/me'),
      headers: {
        'Accept': 'application/json',
        'X-App-Client': 'mobile',
        'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
        'Authorization': 'Bearer $token',
      },
    );

    print('📊 Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('\n✅ Получены данные профиля:');

      if (data is Map &&
          data['data'] is List &&
          (data['data'] as List).isNotEmpty) {
        final user = (data['data'] as List)[0];
        print('\n👤 Пользователь: ${user['name']} ${user['last_name']}');
        print('📧 Email: ${user['email']}');
        print('🔑 Email верифицирован: ${user['email_verified_at']}');
        print('📞 Телефон верифицирован: ${user['phone_verified_at']}');

        if (user['email_verified_at'] != null) {
          print('\n✅ EMAIL ВЕРИФИЦИРОВАН! Дата: ${user['email_verified_at']}');
        } else {
          print('\n❌ EMAIL НЕ ВЕРИФИЦИРОВАН. Требуется пройти верификацию.');
        }
      }
    } else {
      print('❌ Ошибка при получении профиля: ${response.body}');
    }
  } catch (e) {
    print('❌ Ошибка: $e');
  }
}
