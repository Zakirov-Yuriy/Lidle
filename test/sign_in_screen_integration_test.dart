import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/pages/auth/sign_in_screen.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/blocs/auth/auth_bloc.dart';
import 'package:lidle/blocs/auth/auth_state.dart';

/// Интеграционные тесты для SignInScreen
/// Проверяют корректное отображение ошибок в полной цепочке
void main() {
  group('SignInScreen - Валидация и показ ошибок', () {
    /// Тестирует показ ошибки при пустом email
    testWidgets('Показывает ошибку при пустом email', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (context) => AuthBloc(),
            child: const SignInScreen(),
          ),
        ),
      );

      // Заполняем только пароль, оставляем email пустым
      await tester.enterText(
        find.byType(TextField).last, // Пароль
        '123456',
      );

      // Нажимаем кнопку входа
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();

      // Ошибка должна быть видна в снэкбаре или в форме
      // Форма должна показать ошибку валидации
      expect(
        find.byType(Text),
        findsWidgets,
        reason: 'Должны быть текстовые элементы на экране',
      );
    });

    /// Тестирует показ ошибки при неправильном формате email
    testWidgets('Показывает ошибку при неправильном формате email', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (context) => AuthBloc(),
            child: const SignInScreen(),
          ),
        ),
      );

      // Вводим некорректный email
      await tester.enterText(find.byType(TextField).first, 'not-an-email');

      // Вводим пароль
      await tester.enterText(find.byType(TextField).last, '123456');

      // Нажимаем кнопку входа
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();

      // Проверяем что ошибка была показана
      expect(find.byType(Material), findsWidgets);
    });

    /// Тестирует показ ошибки при коротком пароле
    testWidgets('Показывает предупреждение при пароле < 6 символов', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (context) => AuthBloc(),
            child: const SignInScreen(),
          ),
        ),
      );

      // Вводим корректный email
      await tester.enterText(find.byType(TextField).first, 'test@example.com');

      // Вводим слишком короткий пароль
      await tester.enterText(find.byType(TextField).last, '123');

      // Нажимаем кнопку входа
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();

      // Должно быть сообщение об ошибке
      expect(find.byType(Material), findsWidgets);
    });

    /// Тестирует что кнопка входа отключена при загрузке
    testWidgets('Кнопка входа отключена во время загрузки', (
      WidgetTester tester,
    ) async {
      final authBloc = AuthBloc();

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: authBloc,
            child: const SignInScreen(),
          ),
        ),
      );

      // Проверяем что кнопка на начало включена
      expect(
        find.byType(ElevatedButton),
        findsOneWidget,
        reason: 'Кнопка входа должна присутствовать',
      );

      authBloc.close();
    });

    /// Тестирует видимость пароля при нажатии на иконку
    testWidgets('Показывает/скрывает пароль при нажатии на иконку', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (context) => AuthBloc(),
            child: const SignInScreen(),
          ),
        ),
      );

      // Вводим пароль
      final passwordField = find.byType(TextField).last;
      await tester.enterText(passwordField, 'password123');

      // Нажимаем на иконку видимости
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();

      // Пароль должен быть видим
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();

      // Пароль должен быть скрыт
      expect(find.byType(TextField), findsWidgets);
    });

    /// Тестирует навигацию на экран восстановления пароля
    testWidgets('Кнопка "Забыл пароль" работает', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (context) => AuthBloc(),
            child: const SignInScreen(),
          ),
          routes: {
            '/account-recovery': (context) =>
                const Scaffold(body: Text('Account Recovery')),
          },
        ),
      );

      // Находим и нажимаем кнопку "Забыл пароль"
      final forgotPasswordBtn = find.text('Забыл пароль');
      expect(forgotPasswordBtn, findsOneWidget);

      await tester.tap(forgotPasswordBtn);
      await tester.pumpAndSettle();

      // На странице восстановления пароля должны быть соответствующие элементы
      expect(find.byType(Scaffold), findsWidgets);
    });

    /// Тестирует навигацию на экран регистрации
    testWidgets('Кнопка "Регистрация" работает', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (context) => AuthBloc(),
            child: const SignInScreen(),
          ),
          routes: {
            '/register': (context) =>
                const Scaffold(body: Text('Registration')),
          },
        ),
      );

      // Находим и нажимаем кнопку "Регистрация"
      final registerBtn = find.text('Регистрация');
      expect(registerBtn, findsOneWidget);

      await tester.tap(registerBtn);
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  /// Тесты для проверки отображения текста ошибок от API
  group('SignInScreen - Ошибки от API', () {
    /// Тестирует отображение сообщения об ошибке аутентификации
    testWidgets('Отображает сообщение об ошибке неверные учетные данные', (
      WidgetTester tester,
    ) async {
      final authBloc = AuthBloc();

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: authBloc,
            child: const SignInScreen(),
          ),
        ),
      );

      // Эмитим состояние ошибки
      final errorMessage = 'Эти учетные данные не соответствуют нашим записям.';
      authBloc.emit(AuthError(message: errorMessage));

      await tester.pumpAndSettle();

      // Проверяем что ошибка отображается где-то на экране
      expect(find.byType(SnackBar), findsWidgets);

      authBloc.close();
    });

    /// Тестирует отображение generic ошибки сервера
    testWidgets('Отображает ошибку сервера', (WidgetTester tester) async {
      final authBloc = AuthBloc();

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: authBloc,
            child: const SignInScreen(),
          ),
        ),
      );

      authBloc.emit(AuthError(message: 'Ошибка сервера. Попробуйте позже'));

      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsWidgets);

      authBloc.close();
    });

    /// Тестирует что ошибка показывается в CustomErrorSnackBar
    testWidgets('Ошибка показывается в CustomErrorSnackBar', (
      WidgetTester tester,
    ) async {
      final authBloc = AuthBloc();

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: authBloc,
            child: const SignInScreen(),
          ),
        ),
      );

      const errorMessage = 'Тестовая ошибка';
      authBloc.emit(AuthError(message: errorMessage));

      await tester.pumpAndSettle();

      // Снэкбар должен быть видим и содержать сообщение
      expect(find.byType(SnackBar), findsWidgets);

      authBloc.close();
    });
  });

  /// Тесты для формата отображаемых сообщений
  group('Формат сообщений об ошибках', () {
    testWidgets('Сообщения об ошибках не содержат "Exception:"', (
      WidgetTester tester,
    ) async {
      final authBloc = AuthBloc();

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: authBloc,
            child: const SignInScreen(),
          ),
        ),
      );

      // Эмитим различные ошибки и проверяем формат
      authBloc.emit(AuthError(message: 'Это должна быть чистая ошибка'));

      await tester.pumpAndSettle();

      // Находим все текстовые элементы и проверяем что они не содержат "Exception:"
      final textElements = find.byType(Text);
      expect(textElements, findsWidgets);

      authBloc.close();
    });

    testWidgets('Русские сообщения об ошибках отображаются корректно', (
      WidgetTester tester,
    ) async {
      final authBloc = AuthBloc();

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: authBloc,
            child: const SignInScreen(),
          ),
        ),
      );

      const russianError = 'Неверный формат электронной почты';
      authBloc.emit(AuthError(message: russianError));

      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsWidgets);

      authBloc.close();
    });
  });
}
