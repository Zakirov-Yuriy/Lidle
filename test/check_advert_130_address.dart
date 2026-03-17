import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('🔍 Checking address for advert 130...\n');

  // Token from test API
  final token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2FwaS5saWR6YS50ZXN0L3YxL2F1dGgvbG9naW4iLCJpYXQiOjE3NTExMDM4NzIsImV4cCI6MTc1MTEwNzQ3MiwibmJmIjoxNzUxMTAzODcyLCJqdGkiOiJHd2tidlhXNmV5bVZ4Mk5yIiwic3ViIjoiMSIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.iJ0fH_lXmsSYWDX-XN713q7x6pLHfg0qoMb44dCvg60';

  try {
    // Get advert 130
    final response = await http.get(
      Uri.parse('https://dev-api.lidle.io/v1/adverts/130'),
      headers: {
        'Accept': 'application/json',
        'X-App-Client': 'mobile',
        'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
        'Authorization': 'Bearer $token',
      },
    );

    print('✅ Status: ${response.statusCode}');
    print('\n📋 Full Response:');
    print(response.body);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (jsonData['data'] as List).first as Map<String, dynamic>;
      
      print('\n🏠 Address Information:');
      print('- Address: ${data['address']}');
      print('- Full response keys: ${data.keys}');
      
      if (data['address'] != null) {
        print('\n✅ Address received successfully');
        print('Address value: "${data['address']}"');
      } else {
        print('\n❌ Address is null!');
      }
    } else {
      print('❌ Failed to get advert: ${response.statusCode}');
    }

  } catch (e) {
    print('❌ Error: $e');
  }
}
