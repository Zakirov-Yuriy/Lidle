import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lidle/services/api_service.dart';

void main() {
  setUp(() {
    // Инициализируем dotenv для тестов с dev URL
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://dev-api.lidle.io/v1');
  });

  group('ApiService', () {
    test('should have correct base URL', () {
      expect(ApiService.baseUrl, 'https://dev-api.lidle.io/v1');
    });

    test('should have correct default headers', () {
      expect(ApiService.defaultHeaders['Accept'], 'application/json');
      expect(ApiService.defaultHeaders['X-App-Client'], 'mobile');
      expect(
        ApiService.defaultHeaders['Accept-Language'],
        'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
      );
      expect(ApiService.defaultHeaders['Content-Type'], 'application/json');
    });

    test('should have all required headers', () {
      final headers = ApiService.defaultHeaders;
      expect(headers.length, 4);
      expect(headers.containsKey('Accept'), true);
      expect(headers.containsKey('X-App-Client'), true);
      expect(headers.containsKey('Accept-Language'), true);
      expect(headers.containsKey('Content-Type'), true);
    });

    test('should have correct header values', () {
      final headers = ApiService.defaultHeaders;
      expect(headers['Accept'], equals('application/json'));
      expect(headers['X-App-Client'], equals('mobile'));
      expect(headers['Accept-Language'], contains('ru-RU'));
      expect(headers['Content-Type'], equals('application/json'));
    });
  });

  // Note: For comprehensive testing of HTTP methods, we would need to refactor
  // ApiService to accept an HTTP client dependency for proper mocking.
  // The current static implementation makes unit testing challenging.
  // Consider this a foundation that can be expanded when the service is refactored.
}
