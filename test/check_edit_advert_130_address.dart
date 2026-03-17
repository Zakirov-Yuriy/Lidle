import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('🔍 Checking address for EDIT endpoint advert 130...\n');

  final token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2FwaS5saWR6YS50ZXN0L3YxL2F1dGgvbG9naW4iLCJpYXQiOjE3NTExMDM4NzIsImV4cCI6MTc1MTEwNzQ3MiwibmJmIjoxNzUxMTAzODcyLCJqdGkiOiJHd2tidlhXNmV5bVZ4Mk5yIiwic3ViIjoiMSIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.iJ0fH_lXmsSYWDX-XN713q7x6pLHfg0qoMb44dCvg60';

  try {
    // Get advert for EDIT (different endpoint)
    print('📍 Trying: /v1/user/adverts/130/edit\n');
    final response = await http.get(
      Uri.parse('https://dev-api.lidle.io/v1/user/adverts/130/edit'),
      headers: {
        'Accept': 'application/json',
        'X-App-Client': 'mobile',
        'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
        'Authorization': 'Bearer $token',
      },
    );

    print('✅ Status: ${response.statusCode}');
    print('\n📋 Full Response:');
    
    if (response.statusCode == 200) {
      // Pretty print JSON
      final jsonData = jsonDecode(response.body);
      print(jsonEncode(jsonData));
      
      print('\n\n🏠 Analyzing address structure:\n');
      _analyzeAddressStructure(jsonData);
    } else {
      print(response.body);
    }

  } catch (e) {
    print('❌ Error: $e');
  }
}

void _analyzeAddressStructure(dynamic jsonData) {
  if (jsonData is Map) {
    if (jsonData.containsKey('data')) {
      var data = jsonData['data'];
      if (data is Map) {
        print('✅ Data is a Map');
        print('   Keys: ${data.keys}');
        
        // Check address fields
        if (data.containsKey('address')) {
          print('   - address: "${data['address']}"');
        }
        if (data.containsKey('addressUuid')) {
          print('   - addressUuid: "${data['addressUuid']}"');
        }
        if (data.containsKey('fullAddress')) {
          print('   - fullAddress: "${data['fullAddress']}"');
        }
        if (data.containsKey('building_number')) {
          print('   - building_number: "${data['building_number']}"');
        }
        if (data.containsKey('house')) {
          print('   - house: "${data['house']}"');
        }
        if (data.containsKey('flat')) {
          print('   - flat: "${data['flat']}"');
        }
        
        // Check if there's nested address object
        if (data.containsKey('location')) {
          print('   - location: ${data['location']}');
        }
        if (data.containsKey('address_data')) {
          print('   - address_data: ${data['address_data']}');
        }
        
        // Print all string/number fields that might be address-related
        print('\n   All potential address fields:');
        data.forEach((key, value) {
          if (key.toString().toLowerCase().contains('address') ||
              key.toString().toLowerCase().contains('street') ||
              key.toString().toLowerCase().contains('house') ||
              key.toString().toLowerCase().contains('building') ||
              key.toString().toLowerCase().contains('flat') ||
              key.toString().toLowerCase().contains('building_number') ||
              key.toString().toLowerCase().contains('location')) {
            print('   ✓ $key: $value');
          }
        });
      } else if (data is List) {
        print('✅ Data is a List with ${data.length} items');
        if (data.isNotEmpty) {
          print('   First item keys: ${(data[0] as Map).keys}');
        }
      }
    }
  }
}
