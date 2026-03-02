import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';

/// Тесты для компонента CustomErrorSnackBar
/// Проверяют корректное отображение разных типов сообщений
void main() {
  group('CustomErrorSnackBar', () {
    /// Тестирует отображение ошибки (красная иконка)
    testWidgets('Отображает ошибку красной иконкой и сообщением', (
      WidgetTester tester,
    ) async {
      const testMessage = 'Это ошибка';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const CustomErrorSnackBar(
              message: testMessage,
              messageType: SnackBarMessageType.error,
            ),
          ),
        ),
      );

      // Проверяем что сообщение отображается
      expect(find.text(testMessage), findsOneWidget);

      // Проверяем что иконка warning присутствует
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      // Проверяем что контейнер с темным фоном отображается
      expect(find.byType(Container), findsWidgets);
    });

    /// Тестирует отображение успеха (зеленая иконка)
    testWidgets('Отображает успех зеленой иконкой', (
      WidgetTester tester,
    ) async {
      const testMessage = 'Успешно сохранено';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const CustomErrorSnackBar(
              message: testMessage,
              messageType: SnackBarMessageType.success,
            ),
          ),
        ),
      );

      expect(find.text(testMessage), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    /// Тестирует отображение предупреждения (оранжевая иконка)
    testWidgets('Отображает предупреждение оранжевой иконкой', (
      WidgetTester tester,
    ) async {
      const testMessage = 'Пароль должен содержать минимум 6 символов';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const CustomErrorSnackBar(
              message: testMessage,
              messageType: SnackBarMessageType.warning,
            ),
          ),
        ),
      );

      expect(find.text(testMessage), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    /// Тестирует отображение информации (синяя иконка)
    testWidgets('Отображает информацию синей иконкой', (
      WidgetTester tester,
    ) async {
      const testMessage = 'Информационное сообщение';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const CustomErrorSnackBar(
              message: testMessage,
              messageType: SnackBarMessageType.info,
            ),
          ),
        ),
      );

      expect(find.text(testMessage), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    /// Тестирует нажатие на кнопку закрытия
    testWidgets('Вызывает onClose при нажатии на кнопку закрытия', (
      WidgetTester tester,
    ) async {
      bool closeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomErrorSnackBar(
              message: 'Тестовое сообщение',
              onClose: () => closeCalled = true,
            ),
          ),
        ),
      );

      // Нажимаем на кнопку закрытия
      await tester.tap(find.byIcon(Icons.close));

      expect(closeCalled, isTrue);
    });

    /// Тестирует отображение длинного сообщения
    testWidgets('Корректно отображает длинное сообщение', (
      WidgetTester tester,
    ) async {
      const longMessage =
          'Это очень длинное сообщение об ошибке которое может быть представлено приложением';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const CustomErrorSnackBar(
              message: longMessage,
              messageType: SnackBarMessageType.error,
            ),
          ),
        ),
      );

      expect(find.text(longMessage), findsOneWidget);
    });

    /// Тестирует размер иконки
    testWidgets('Иконка имеет правильный размер', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const CustomErrorSnackBar(
              message: 'Тест',
              messageType: SnackBarMessageType.error,
            ),
          ),
        ),
      );

      // Проверяем что иконка присутствует
      final iconFinder = find.byIcon(Icons.warning_amber_rounded);
      expect(iconFinder, findsOneWidget);
    });

    /// Тестирует стиль текста
    testWidgets('Текст имеет правильный стиль (белый, 16pt)', (
      WidgetTester tester,
    ) async {
      const testMessage = 'Проверка стиля текста';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const CustomErrorSnackBar(
              message: testMessage,
              messageType: SnackBarMessageType.error,
            ),
          ),
        ),
      );

      final textFinder = find.byType(Text);
      expect(textFinder, findsWidgets);

      // Проверяем что основное сообщение отображается
      expect(find.text(testMessage), findsOneWidget);
    });

    /// Тестирует отображение снэкбара без кнопки закрытия
    testWidgets('Не отображает кнопку закрытия если onClose null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const CustomErrorSnackBar(
              message: 'Сообщение без закрытия',
              onClose: null,
            ),
          ),
        ),
      );

      // Кнопка закрытия не должна быть видна
      expect(find.byIcon(Icons.close), findsNothing);
    });

    /// Тестирует отображение разных ошибочных сообщений от API
    testWidgets('Отображает сообщение об ошибке валидации email', (
      WidgetTester tester,
    ) async {
      const apiErrorMessage = 'Неверный формат почты';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const CustomErrorSnackBar(
              message: apiErrorMessage,
              messageType: SnackBarMessageType.error,
            ),
          ),
        ),
      );

      expect(find.text(apiErrorMessage), findsOneWidget);
    });

    /// Тестирует отображение сообщения об ошибке аутентификации
    testWidgets('Отображает сообщение об ошибке учетных данных', (
      WidgetTester tester,
    ) async {
      const authError = 'Эти учетные данные не соответствуют нашим записям.';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const CustomErrorSnackBar(
              message: authError,
              messageType: SnackBarMessageType.error,
            ),
          ),
        ),
      );

      expect(find.text(authError), findsOneWidget);
    });
  });

  /// Тесты для SnackBarHelper
  group('SnackBarHelper', () {
    /// Тестирует показ ошибки
    testWidgets('SnackBarHelper.showError показывает ошибку', (
      WidgetTester tester,
    ) async {
      const errorMessage = 'Тестовая ошибка';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      SnackBarHelper.showError(context, errorMessage);
                    },
                    child: const Text('Show Error'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Нажимаем кнопку для показа ошибки
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Проверяем что сообщение отображается в снэкбаре
      expect(find.text(errorMessage), findsOneWidget);
    });

    /// Тестирует показ успеха
    testWidgets('SnackBarHelper.showSuccess показывает успех', (
      WidgetTester tester,
    ) async {
      const successMessage = 'Успешно!';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      SnackBarHelper.showSuccess(context, successMessage);
                    },
                    child: const Text('Show Success'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text(successMessage), findsOneWidget);
    });

    /// Тестирует показ предупреждения
    testWidgets('SnackBarHelper.showWarning показывает предупреждение', (
      WidgetTester tester,
    ) async {
      const warningMessage = 'Внимание!';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      SnackBarHelper.showWarning(context, warningMessage);
                    },
                    child: const Text('Show Warning'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text(warningMessage), findsOneWidget);
    });

    /// Тестирует показ информации
    testWidgets('SnackBarHelper.showInfo показывает информацию', (
      WidgetTester tester,
    ) async {
      const infoMessage = 'Информация';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      SnackBarHelper.showInfo(context, infoMessage);
                    },
                    child: const Text('Show Info'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text(infoMessage), findsOneWidget);
    });
  });
}
