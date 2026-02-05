import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';

  print('🔍 Fetching my adverts to check their structure...');

  final headers = {
    'Accept': 'application/json',
    'X-App-Client': 'mobile',
    'Content-Type': 'application/json',
  };

  try {
    final response = await http.get(
      Uri.parse('$baseUrl/adverts'),
      headers: headers,
    );

    print('Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (data['data'] != null && (data['data'] as List).isNotEmpty) {
        final advert = (data['data'] as List).first as Map<String, dynamic>;
        print('\n✅ First advert ID ${advert['id']}:');
        print('  name: ${advert['name']}');
        print('  address: ${advert['address']}');

        // Get the raw JSON
        print('\n📋 Full advert JSON:');
        print(jsonEncode(advert));
      }
    } else {
      print('Error: ${response.body}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
