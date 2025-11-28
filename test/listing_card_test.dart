import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/widgets/listing_card.dart';
import 'package:lidle/constants.dart';

void main() {
  group('ListingCard Widget Tests', () {
    testWidgets('should display listing title', (WidgetTester tester) async {
      const listing = Listing(
        id: 'test_listing_1',
        imagePath: 'assets/home_page/apartment1.png',
        title: 'Test Listing',
        price: '100 000 ₽',
        location: 'Москва',
        date: '2024-01-01',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 263,
              width: 180,
              child: ListingCard(listing: listing),
            ),
          ),
        ),
      );

      expect(find.text('Test Listing'), findsOneWidget);
    });

    testWidgets('should display listing price', (WidgetTester tester) async {
      const listing = Listing(
        id: 'test_listing_2',
        imagePath: 'assets/home_page/apartment1.png',
        title: 'Test Listing',
        price: '100 000 ₽',
        location: 'Москва',
        date: '2024-01-01',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 263,
              width: 180,
              child: ListingCard(listing: listing),
            ),
          ),
        ),
      );

      expect(find.text('100 000 ₽'), findsOneWidget);
    });

    testWidgets('should display listing location', (WidgetTester tester) async {
      const listing = Listing(
        id: 'test_listing_3',
        imagePath: 'assets/home_page/apartment1.png',
        title: 'Test Listing',
        price: '100 000 ₽',
        location: 'Москва',
        date: '2024-01-01',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 263,
              width: 180,
              child: ListingCard(listing: listing),
            ),
          ),
        ),
      );

      expect(find.text('Москва'), findsOneWidget);
    });

    testWidgets('should display listing date', (WidgetTester tester) async {
      const listing = Listing(
        id: 'test_listing_4',
        imagePath: 'assets/home_page/apartment1.png',
        title: 'Test Listing',
        price: '100 000 ₽',
        location: 'Москва',
        date: '2024-01-01',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 263,
              width: 180,
              child: ListingCard(listing: listing),
            ),
          ),
        ),
      );

      expect(find.text('2024-01-01'), findsOneWidget);
    });

    testWidgets('should display image', (WidgetTester tester) async {
      const listing = Listing(
        id: 'test_listing_5',
        imagePath: 'assets/home_page/apartment1.png',
        title: 'Test Listing',
        price: '100 000 ₽',
        location: 'Москва',
        date: '2024-01-01',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 263,
              width: 180,
              child: ListingCard(listing: listing),
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<AssetImage>());
      final assetImage = imageWidget.image as AssetImage;
      expect(assetImage.assetName, 'assets/home_page/apartment1.png');
    });

    testWidgets('should have favorite icon', (WidgetTester tester) async {
      const listing = Listing(
        id: 'test_listing_6',
        imagePath: 'assets/home_page/apartment1.png',
        title: 'Test Listing',
        price: '100 000 ₽',
        location: 'Москва',
        date: '2024-01-01',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 263,
              width: 180,
              child: ListingCard(listing: listing),
            ),
          ),
        ),
      );

      final iconFinder = find.byIcon(Icons.favorite_border);
      expect(iconFinder, findsOneWidget);
    });

    testWidgets('should have ClipRRect for image', (WidgetTester tester) async {
      const listing = Listing(
        imagePath: 'assets/home_page/apartment1.png',
        title: 'Test Listing',
        price: '100 000 ₽',
        location: 'Москва',
        date: '2024-01-01',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 263,
              width: 180,
              child: ListingCard(listing: listing),
            ),
          ),
        ),
      );

      final clipRRectFinder = find.byType(ClipRRect);
      expect(clipRRectFinder, findsOneWidget);
    });

    testWidgets('should handle long title with ellipsis', (WidgetTester tester) async {
      const listing = Listing(
        imagePath: 'assets/home_page/apartment1.png',
        title: 'Very Long Listing Title That Should Be Truncated',
        price: '100 000 ₽',
        location: 'Москва',
        date: '2024-01-01',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 263,
              width: 180,
              child: ListingCard(listing: listing),
            ),
          ),
        ),
      );

      final textFinder = find.text('Very Long Listing Title That Should Be Truncated');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('should handle long location with ellipsis', (WidgetTester tester) async {
      const listing = Listing(
        imagePath: 'assets/home_page/apartment1.png',
        title: 'Test Listing',
        price: '100 000 ₽',
        location: 'Very Long Location Name That Should Be Truncated',
        date: '2024-01-01',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 263,
              width: 180,
              child: ListingCard(listing: listing),
            ),
          ),
        ),
      );

      final textFinder = find.text('Very Long Location Name That Should Be Truncated');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('should have correct text colors', (WidgetTester tester) async {
      const listing = Listing(
        imagePath: 'assets/home_page/apartment1.png',
        title: 'Test Listing',
        price: '100 000 ₽',
        location: 'Москва',
        date: '2024-01-01',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 263,
              width: 180,
              child: ListingCard(listing: listing),
            ),
          ),
        ),
      );

      // Title should be textPrimary
      final titleText = tester.widget<Text>(find.text('Test Listing'));
      expect(titleText.style?.color, textPrimary);

      // Price should be textPrimary
      final priceText = tester.widget<Text>(find.text('100 000 ₽'));
      expect(priceText.style?.color, textPrimary);

      // Location should be textSecondary
      final locationText = tester.widget<Text>(find.text('Москва'));
      expect(locationText.style?.color, textSecondary);

      // Date should be textMuted
      final dateText = tester.widget<Text>(find.text('2024-01-01'));
      expect(dateText.style?.color, textMuted);
    });

    testWidgets('should use LayoutBuilder for responsive design', (WidgetTester tester) async {
      const listing = Listing(
        imagePath: 'assets/home_page/apartment1.png',
        title: 'Test Listing',
        price: '100 000 ₽',
        location: 'Москва',
        date: '2024-01-01',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 263,
              width: 180,
              child: ListingCard(listing: listing),
            ),
          ),
        ),
      );

      final layoutBuilderFinder = find.byType(LayoutBuilder);
      expect(layoutBuilderFinder, findsOneWidget);
    });
  });
}
