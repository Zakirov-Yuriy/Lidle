import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('🔍 Testing different edit endpoints for advert 130...\n');

  final token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2FwaS5saWR6YS50ZXN0L3YxL2F1dGgvbG9naW4iLCJpYXQiOjE3NTExMDM4NzIsImV4cCI6MTc1MTEwNzQ3MiwibmJmIjoxNzUxMTAzODcyLCJqdGkiOiJHd2tidlhXNmV5bVZ4Mk5yIiwic3ViIjoiMSIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.iJ0fH_lXmsSYWDX-XN713q7x6pLHfg0qoMb44dCvg60';

  final endpoints = [
    'https://dev-api.lidle.io/v1/adverts/130/edit',
    'https://dev-api.lidle.io/v1/adverts/130',
    'https://dev-api.lidle.io/v1/user/adverts/130',
    'https://dev-api.lidle.io/v1/user/adverts',
  ];

  for (final endpoint in endpoints) {
    try {
      print('📍 Testing: $endpoint\n');
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Accept': 'application/json',
          'X-App-Client': 'mobile',
          'Authorization': 'Bearer $token',
        },
      );

      print('   Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        print('   ✅ Success! Response preview:');
        print('   ${jsonEncode(jsonData).substring(0, 200)}...\n');
        
        // Analyze structure
        _analyzeAddressInResponse(jsonData);
      }
      print('');
    } catch (e) {
      print('   ❌ Error: $e\n');
    }
  }
}

void _analyzeAddressInResponse(dynamic data) {
  try {
    Map<String, dynamic>? targetMap;
    
    if (data is Map && data.containsKey('data')) {
      var innerData = data['data'];
      if (innerData is List && innerData.isNotEmpty) {
        targetMap = innerData.first as Map<String, dynamic>;
      } else if (innerData is Map) {
        targetMap = innerData as Map<String, dynamic>;
      }
    } else if (data is Map) {
      targetMap = data as Map<String, dynamic>;
    }

    if (targetMap != null) {
      print('   📍 Address-related fields in response:');
      targetMap.forEach((key, value) {
        if (key.toString().toLowerCase().contains('address') ||
            key.toString().toLowerCase().contains('street') ||
            key.toString().toLowerCase().contains('house') ||
            key.toString().toLowerCase().contains('building') ||
            key.toString().toLowerCase().contains('building_number')) {
          print('      ✓ $key: $value');
        }
      });
    }
  } catch (e) {
    print('   Error analyzing: $e');
  }
}
