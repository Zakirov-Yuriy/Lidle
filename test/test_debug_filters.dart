import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://dev-api.lidle.io/v1';
  const String token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJodHRwczovL2Rldi1hcGkubGlkbGUuaW8vdjEvYXV0aC9sb2dpbiIsImlhdCI6MTc3MDI3NTE1NiwiZXhwIjoxNzcwMjc4NzU2LCJuYmYiOjE3NzAyNzUxNTYsImp0aSI6InB2ZFZ0d3ZtOXdwTFh3OWkiLCJzdWIiOiI1NyIsInBydiI6IjIzYmQ1Yzg5NDlmNjAwYWRiMzllNzAxYzQwMDg3MmRiN2E1OTc2ZjcifQ.PJ-sd_XDytf9n0nK1xCQOb8EdDiPFFH6lL2L-Yzq54A';

  print('Getting create adverts parameters...');

  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  try {
    final response = await http.get(
      Uri.parse('$baseUrl/adverts/create?category_id=2'),
      headers: headers,
    );

    print('Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Print top-level keys
      print('\nTop-level keys: ${(data as Map).keys.toList()}');

      if (data['data'] != null) {
        final typeData = data['data'];
        print('data type: ${typeData.runtimeType}');
        print('data is List: ${typeData is List}');
        print('data is Map: ${typeData is Map}');

        if (typeData is List && typeData.isNotEmpty) {
          print('\nFirst element type: ${typeData[0].runtimeType}');
          print('First element keys: ${(typeData[0] as Map).keys.toList()}');

          final firstElem = typeData[0] as Map;
          if (firstElem['attributes'] != null) {
            print(
              '\nAttributes found! Count: ${(firstElem['attributes'] as List).length}',
            );

            // Find required attributes
            print('\n=== REQUIRED ATTRIBUTES ===');
            for (final attr in firstElem['attributes']) {
              if (attr['is_required'] == true) {
                print('\nAttribute ID: ${attr['id']}');
                print('  Title: ${attr['title']}');
                print('  is_required: ${attr['is_required']}');
                print('  is_multiple: ${attr['is_multiple']}');

                if (attr['values'] != null &&
                    (attr['values'] as List).isNotEmpty) {
                  print('  Values:');
                  for (final val in (attr['values'] as List).take(5)) {
                    print('    - ID: ${val['id']}, Value: ${val['value']}');
                  }
                }
              }
            }
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
