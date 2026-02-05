import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final email = 'workyury02@gmail.com';
  final password = '12345678';

  try {
    print('🔍 Проверяем статус верификации пользователя $email...\n');

    // Сначала входим в систему
    print('📝 Логин в систему...');
    final loginResponse = await http.post(
      Uri.parse('https://dev-api.lidle.io/v1/auth/login'),
      headers: {
        'Accept': 'application/json',
        'X-App-Client': 'mobile',
        'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'email': email, 'password': password}),
    );

    print('Login Status: ${loginResponse.statusCode}');

    if (loginResponse.statusCode == 200) {
      final loginData = jsonDecode(loginResponse.body);
      final token = loginData['access_token'];

      print('✅ Логин успешен\n');

      // Теперь получаем профиль
      print('📥 Загружаем профиль...');
      final profileResponse = await http.get(
        Uri.parse('https://dev-api.lidle.io/v1/me'),
        headers: {
          'Accept': 'application/json',
          'X-App-Client': 'mobile',
          'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
          'Authorization': 'Bearer $token',
        },
      );

      print('Profile Status: ${profileResponse.statusCode}\n');

      if (profileResponse.statusCode == 200) {
        final profileData = jsonDecode(profileResponse.body);

        if (profileData is Map &&
            profileData['data'] is List &&
            (profileData['data'] as List).isNotEmpty) {
          final user = (profileData['data'] as List)[0];
          print('👤 Пользователь: ${user['name']} ${user['last_name']}');
          print('📧 Email: ${user['email']}');
          print('🔑 Email верифицирован: ${user['email_verified_at']}');
          print('📞 Телефон верифицирован: ${user['phone_verified_at']}');

          if (user['email_verified_at'] != null) {
            print(
              '\n✅ EMAIL ВЕРИФИЦИРОВАН! Дата: ${user['email_verified_at']}',
            );
          } else {
            print('\n❌ EMAIL НЕ ВЕРИФИЦИРОВАН. Требуется пройти верификацию.');
          }
        }
      } else {
        print('❌ Ошибка при получении профиля: ${profileResponse.body}');
      }
    } else if (loginResponse.statusCode == 401) {
      print('❌ Ошибка входа: Неверные учетные данные');
      print('Response: ${loginResponse.body}');
    } else {
      print(
        '❌ Ошибка входа (статус ${loginResponse.statusCode}): ${loginResponse.body}',
      );
    }
  } catch (e) {
    print('❌ Ошибка: $e');
  }
}
