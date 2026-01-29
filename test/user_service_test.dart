import 'package:flutter_test/flutter_test.dart';
import 'package:lidle/services/user_service.dart';

void main() {
  group('UserService.deleteAccount', () {
    test('calls delete API with password and clears user data keys', () async {
      final deleted = <Map<String, dynamic>>[];
      final cleared = <String>[];

      final deleteFn =
          (String endpoint, {String? token, Map<String, dynamic>? body}) async {
            expect(endpoint, '/me/settings/account');
            expect(token, 'fake-token');
            expect(body, isNotNull);
            expect(body!['password'], '123123123');
            deleted.add({'endpoint': endpoint, 'body': body});
            return {}; // emulate ApiService response
          };

      final clearFn = (String key) async {
        cleared.add(key);
      };

      var clearAllCalled = false;
      final clearAllFn = () async {
        clearAllCalled = true;
      };

      await UserService.deleteAccount(
        token: 'fake-token',
        password: '123123123',
        deleteFn: deleteFn,
        deleteUserDataFn: clearFn,
        clearAllFn: clearAllFn,
      );

      expect(deleted, isNotEmpty);
      expect(
        cleared,
        containsAll(['token', 'name', 'email', 'phone', 'userId']),
      );
      expect(clearAllCalled, true);
    });

    test(
      'propagates exception from deleteFn and does not clear data',
      () async {
        var clearedCalled = false;

        final deleteFn =
            (
              String endpoint, {
              String? token,
              Map<String, dynamic>? body,
            }) async {
              throw Exception('server error');
            };

        final clearFn = (String key) async {
          clearedCalled = true;
        };

        expect(
          () => UserService.deleteAccount(
            token: 'fake-token',
            password: 'abc',
            deleteFn: deleteFn,
            deleteUserDataFn: clearFn,
          ),
          throwsA(isA<Exception>()),
        );

        expect(clearedCalled, false);
      },
    );
  });
}
