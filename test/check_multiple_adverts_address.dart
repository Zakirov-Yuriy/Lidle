import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('🔍 Checking multiple adverts for address structure...\n');

  final token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2FwaS5saWR6YS50ZXN0L3YxL2F1dGgvbG9naW4iLCJpYXQiOjE3NTExMDM4NzIsImV4cCI6MTc1MTEwNzQ3MiwibmJmIjoxNzUxMTAzODcyLCJqdGkiOiJHd2tidlhXNmV5bVZ4Mk5yIiwic3ViIjoiMSIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.iJ0fH_lXmsSYWDX-XN713q7x6pLHfg0qoMb44dCvg60';

  final advertIds = [130, 129, 128, 127, 126];

  for (final id in advertIds) {
    try {
      final response = await http.get(
        Uri.parse('https://dev-api.lidle.io/v1/adverts/$id'),
        headers: {
          'Accept': 'application/json',
          'X-App-Client': 'mobile',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final dataList = jsonData['data'] as List;
        
        if (dataList.isNotEmpty) {
          final advert = dataList.first as Map<String, dynamic>;
          final address = advert['address'];
          
          print('📌 Advert #$id:');
          print('   Address: "$address"');
          
          // Check all keys that might be related to address
          final keys = advert.keys
              .where((k) => k.toString().toLowerCase().contains('address') ||
                  k.toString().toLowerCase().contains('street') ||
                  k.toString().toLowerCase().contains('house') ||
                  k.toString().toLowerCase().contains('building') ||
                  k.toString().toLowerCase().contains('location') ||
                  k.toString().toLowerCase().contains('geo'))
              .toList();
          
          if (keys.isNotEmpty) {
            print('   All address-related fields:');
            for (final key in keys) {
              print('      • $key: ${advert[key]}');
            }
          }
          print('');
        }
      }
    } catch (e) {
      print('   ❌ Error: $e\n');
    }
  }

  // Also check the full structure of one advert
  print('\n\n📝 Full keys in advert structure:');
  try {
    final response = await http.get(
      Uri.parse('https://dev-api.lidle.io/v1/adverts/130'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      final advert = jsonData['data'][0];
      print('All keys: ${(advert as Map).keys.toList()}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
