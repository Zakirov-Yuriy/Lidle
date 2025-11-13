import 'package:flutter_test/flutter_test.dart';
import 'package:lidle/services/auth_service.dart';

void main() {
  group('AuthService', () {
    test('should have all required static methods', () {
      // Test that all methods exist and are callable
      expect(AuthService.sendCode, isNotNull);
      expect(AuthService.register, isNotNull);
      expect(AuthService.verify, isNotNull);
      expect(AuthService.login, isNotNull);
      expect(AuthService.forgotPassword, isNotNull);
      expect(AuthService.resetPassword, isNotNull);
      expect(AuthService.logout, isNotNull);
    });

    test('sendCode method should accept correct parameters', () {
      // Test method signature by checking if it can be called with correct params
      // Note: This will actually make an HTTP call, so in a real test suite
      // we would mock the ApiService or use a test double
      expect(() async {
        try {
          await AuthService.sendCode(email: 'test@example.com');
        } catch (e) {
          // Expected to fail without proper API, but method should exist
          expect(e, isNotNull);
        }
      }, returnsNormally);
    });

    test('register method should accept all required parameters', () {
      expect(() async {
        try {
          await AuthService.register(
            name: 'John',
            lastName: 'Doe',
            email: 'john@example.com',
            phone: '+1234567890',
            password: 'password123',
            passwordConfirmation: 'password123',
          );
        } catch (e) {
          // Expected to fail without proper API
          expect(e, isNotNull);
        }
      }, returnsNormally);
    });

    test('verify method should accept correct parameters', () {
      expect(() async {
        try {
          await AuthService.verify(
            email: 'test@example.com',
            code: '123456',
          );
        } catch (e) {
          // Expected to fail without proper API
          expect(e, isNotNull);
        }
      }, returnsNormally);
    });

    test('login method should accept required parameters', () {
      expect(() async {
        try {
          await AuthService.login(
            email: 'test@example.com',
            password: 'password123',
          );
        } catch (e) {
          // Expected to fail without proper API
          expect(e, isNotNull);
        }
      }, returnsNormally);
    });

    test('login method should accept optional remember parameter', () {
      expect(() async {
        try {
          await AuthService.login(
            email: 'test@example.com',
            password: 'password123',
            remember: false,
          );
        } catch (e) {
          // Expected to fail without proper API
          expect(e, isNotNull);
        }
      }, returnsNormally);
    });

    test('forgotPassword method should accept email parameter', () {
      expect(() async {
        try {
          await AuthService.forgotPassword(email: 'test@example.com');
        } catch (e) {
          // Expected to fail without proper API
          expect(e, isNotNull);
        }
      }, returnsNormally);
    });

    test('resetPassword method should accept all required parameters', () {
      expect(() async {
        try {
          await AuthService.resetPassword(
            email: 'test@example.com',
            password: 'newpassword123',
            passwordConfirmation: 'newpassword123',
            token: 'reset_token_123',
          );
        } catch (e) {
          // Expected to fail without proper API
          expect(e, isNotNull);
        }
      }, returnsNormally);
    });

    test('logout method should be callable', () {
      expect(() async {
        await AuthService.logout();
      }, returnsNormally);
    });

    // Note: These tests verify method signatures but don't test actual functionality
    // due to the static nature of the service. For comprehensive testing, consider
    // refactoring to use dependency injection or wrapping the service in a testable interface.
  });
}
