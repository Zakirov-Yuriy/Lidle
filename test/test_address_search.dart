import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MDI3NTE1NiwiZXhwIjoxNzcwMjc4NzU2LCJuYmYiOjE3NzAyNzUxNTYsImp0aSI6InB2ZFZ0d3ZtOXdwTFh3OWkiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.PJ-sd_XDytf9n0nK1xCQOb8EdDiPFFH6lL2L-Yzq54A';

  // Test address search
  final query = 'ул. Артёма г. Мариуполь';
  print('🔍 Testing address search for: "$query"');
  print('════════════════════════════════════════════════════════');

  final params = {'q': query};
  final uri = Uri.parse(
    '$baseUrl/addresses/search',
  ).replace(queryParameters: params);

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'X-App-Client': 'mobile',
    'Content-Type': 'application/json',
  };

  try {
    final response = await http.get(uri, headers: headers);
    print('Status: ${response.statusCode}');
    print('Response body:');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      print(jsonEncode(data));

      if (data['data'] != null && (data['data'] as List).isNotEmpty) {
        final firstResult =
            (data['data'] as List).first as Map<String, dynamic>;
        print('\n✅ First result found:');
        print('Full address: ${firstResult['full_address']}');
        print('\nAddress components:');
        print('  main_region: ${firstResult['main_region']}');
        print('  region: ${firstResult['region']}');
        print('  city: ${firstResult['city']}');
        print('  street: ${firstResult['street']}');
        print('  building: ${firstResult['building']}');

        print('\n🔍 Extracting IDs:');
        if (firstResult['city']?['region_id'] != null) {
          print('  city.region_id: ${firstResult['city']['region_id']} ✅');
        } else {
          print('  city.region_id: NOT FOUND ❌');
        }
        if (firstResult['main_region']?['id'] != null) {
          print('  main_region.id: ${firstResult['main_region']['id']}');
        }
        if (firstResult['region']?['id'] != null) {
          print('  region.id: ${firstResult['region']['id']}');
        }
        if (firstResult['city']?['id'] != null) {
          print('  city.id: ${firstResult['city']['id']}');
        }
        if (firstResult['street']?['id'] != null) {
          print('  street.id: ${firstResult['street']['id']}');
        }

        // ISSUE DIAGNOSIS: Check full city object
        print('\n🔧 Full city object:');
        print('  ${firstResult['city']}');
      } else {
        print('\n❌ No results found');
      }
    } else {
      print(response.body);
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
