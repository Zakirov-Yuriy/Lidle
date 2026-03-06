import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('═══════════════════════════════════════════════════════');
  print('🔐 Получение токена через вход в приложение');
  print('═══════════════════════════════════════════════════════');
  print('');

  // Данные для входа (используем реальные данные тестового пользователя)
  const String phone = '+79254499552'; // из скриншота
  const String password = 'Password123'; // предполагаемый пароль

  print('📱 Вход по номеру: $phone');
  print('');

  // STEP 1: Запрос кода подтверждения
  print('📤 Шаг 1: Запрашиваю код подтверждения...');
  var sendCodeResponse = await http.post(
    Uri.parse('https://api.lidle.kz/api/login/send-code'),
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    body: jsonEncode({'phone': phone}),
  );

  print('   Status: ${sendCodeResponse.statusCode}');
  final sendCodeBody = jsonDecode(sendCodeResponse.body);
  print('   Response: ${jsonEncode(sendCodeBody)}');
  print('');

  if (sendCodeResponse.statusCode != 200) {
    print('❌ Ошибка при отправке кода');
    return;
  }

  // STEP 2: Получить код из консоли
  print('📋 В реальном приложении нужно ввести код из SMS');
  print('   Для диагностики используем код "123456" (может не работать)');
  print('');

  const String verificationCode = '123456';

  // STEP 3: Верифицировать код и получить токен
  print('📤 Шаг 2: Верифицирую код и получаю токен...');
  var verifyResponse = await http.post(
    Uri.parse('https://api.lidle.kz/api/login/verify-code'),
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    body: jsonEncode({'phone': phone, 'code': verificationCode}),
  );

  print('   Status: ${verifyResponse.statusCode}');
  final verifyBody = jsonDecode(verifyResponse.body);
  print('   Response: ${jsonEncode(verifyBody)}');
  print('');

  if (verifyResponse.statusCode != 200) {
    print('❌ Ошибка при верификации кода');
    print('   Это нормально если код не совпадает');
    print('   Укажите реальный код вручную в переменной verificationCode');
    return;
  }

  // Получим токен из ответа
  final token = verifyBody['data']?['access_token'];
  if (token == null) {
    print('❌ Токен не найден в ответе');
    return;
  }

  print('✅ Токен получен: ${token.toString().substring(0, 20)}...');
  print('');
  print('═══════════════════════════════════════════════════════');
}
