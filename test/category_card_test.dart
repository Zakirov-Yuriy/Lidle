import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/widgets/category_card.dart';
import 'package:lidle/constants.dart';

void main() {
  group('CategoryCard Widget Tests', () {
    testWidgets('should display category title', (WidgetTester tester) async {
      const category = Category(
        title: 'Test Category',
        color: Colors.blue,
        imagePath: 'assets/home_page/14.png',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryCard(category: category),
          ),
        ),
      );

      expect(find.text('Test Category'), findsOneWidget);
    });

    testWidgets('should display image with correct path', (WidgetTester tester) async {
      const category = Category(
        title: 'Test Category',
        color: Colors.blue,
        imagePath: 'assets/home_page/14.png',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryCard(category: category),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<AssetImage>());
      final assetImage = imageWidget.image as AssetImage;
      expect(assetImage.assetName, 'assets/home_page/14.png');
    });

    testWidgets('should have correct dimensions', (WidgetTester tester) async {
      const category = Category(
        title: 'Test Category',
        color: Colors.blue,
        imagePath: 'assets/home_page/14.png',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryCard(category: category),
          ),
        ),
      );

      final containerFinder = find.byType(Container);
      expect(containerFinder, findsOneWidget);

      final containerWidget = tester.widget<Container>(containerFinder);
      expect(containerWidget.constraints?.maxWidth, categoryCardWidth);
    });

    testWidgets('should have ClipRRect with border radius', (WidgetTester tester) async {
      const category = Category(
        title: 'Test Category',
        color: Colors.blue,
        imagePath: 'assets/home_page/14.png',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryCard(category: category),
          ),
        ),
      );

      final clipRRectFinder = find.byType(ClipRRect);
      expect(clipRRectFinder, findsOneWidget);

      final clipRRectWidget = tester.widget<ClipRRect>(clipRRectFinder);
      expect(clipRRectWidget.borderRadius, BorderRadius.circular(5));
    });

    testWidgets('should position text correctly', (WidgetTester tester) async {
      const category = Category(
        title: 'Test Category',
        color: Colors.blue,
        imagePath: 'assets/home_page/14.png',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryCard(category: category),
          ),
        ),
      );

      final positionedFinder = find.byType(Positioned);
      expect(positionedFinder, findsOneWidget);

      final positionedWidget = tester.widget<Positioned>(positionedFinder);
      expect(positionedWidget.top, 15);
      expect(positionedWidget.left, 10);
    });

    testWidgets('should have correct text styling', (WidgetTester tester) async {
      const category = Category(
        title: 'Test Category',
        color: Colors.blue,
        imagePath: 'assets/home_page/14.png',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryCard(category: category),
          ),
        ),
      );

      final textFinder = find.text('Test Category');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.color, const Color.fromARGB(255, 0, 0, 0));
      expect(textWidget.style?.fontSize, 16);
      expect(textWidget.style?.fontWeight, FontWeight.w400);
      expect(textWidget.style?.height, 1.0);
    });

    testWidgets('should handle different category data', (WidgetTester tester) async {
      const carCategory = Category(
        title: 'Автомобили',
        color: Colors.blue,
        imagePath: 'assets/home_page/acura_mdx.png',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryCard(category: carCategory),
          ),
        ),
      );

      expect(find.text('Автомобили'), findsOneWidget);

      final imageFinder = find.byType(Image);
      final imageWidget = tester.widget<Image>(imageFinder);
      final assetImage = imageWidget.image as AssetImage;
      expect(assetImage.assetName, 'assets/home_page/acura_mdx.png');
    });

    testWidgets('should fit BoxFit.cover for image', (WidgetTester tester) async {
      const category = Category(
        title: 'Test Category',
        color: Colors.blue,
        imagePath: 'assets/home_page/14.png',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryCard(category: category),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.fit, BoxFit.cover);
    });
  });
}
