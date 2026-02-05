import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MDI3NTE1NiwiZXhwIjoxNzcwMjc4NzU2LCJuYmYiOjE3NzAyNzUxNTYsImp0aSI6InB2ZFZ0d3ZtOXdwTFh3OWkiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.PJ-sd_XDytf9n0nK1xCQOb8EdDiPFFH6lL2L-Yzq54A';

  print('Getting user profile to find contact IDs...\n');

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  try {
    final response = await http.get(
      Uri.parse('$baseUrl/user/profile'),
      headers: headers,
    );

    print('Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final utf8Response = utf8.decode(response.bodyBytes);
      final data = jsonDecode(utf8Response);

      print('Profile data:');
      print(jsonEncode(data));

      if (data['data'] != null) {
        final user = data['data'] as Map;
        print('\n\nUser details:');
        print('ID: ${user['id']}');
        print('Name: ${user['name']}');
        print('Email: ${user['email']}');
        print('Phone: ${user['phone']}');

        if (user['contacts'] != null) {
          print('\nContacts:');
          final contacts = user['contacts'] as List;
          for (final contact in contacts) {
            print(
              '  - Type: ${contact['type']}, ID: ${contact['id']}, Value: ${contact['value']}',
            );
          }
        }

        if (user['user_phones'] != null) {
          print('\nUser phones:');
          final phones = user['user_phones'] as List;
          for (final phone in phones) {
            print('  - ID: ${phone['id']}, Phone: ${phone['phone']}');
          }
        }

        if (user['user_emails'] != null) {
          print('\nUser emails:');
          final emails = user['user_emails'] as List;
          for (final email in emails) {
            print('  - ID: ${email['id']}, Email: ${email['email']}');
          }
        }
      }
    } else {
      print('Error: ${response.body}');
    }
  } catch (e) {
    print('Exception: $e');
  }
}
