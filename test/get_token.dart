import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  const String apiUrl = 'https://dev-api.lidle.io/v1/auth/login';

  final Map<String, dynamic> credentials = {
    "email": "workyury02@gmail.com",
    "password": "12345678",
    "remember": true,
  };

  print("=== Получаем новый токен ===");

  try {
    final request = await HttpClient().postUrl(Uri.parse(apiUrl));
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Accept', 'application/json');

    request.write(utf8.encode(jsonEncode(credentials)));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(body);
      print("Status: ${response.statusCode}");
      print("Token: ${data['data']['token']}");
      print("\nСкопируй токен выше в test_correct_advert.dart");
    } else {
      print("Status: ${response.statusCode}");
      print("Response: $body");
    }
  } catch (e) {
    print("Ошибка запроса: $e");
  }
}
