import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lidle/models/home_models.dart';

void main() {
  group('Category Model', () {
    test('should create Category with required parameters', () {
      const category = Category(
        title: 'Test Category',
        color: Colors.blue,
        imagePath: 'assets/test.png',
      );

      expect(category.title, 'Test Category');
      expect(category.color, Colors.blue);
      expect(category.imagePath, 'assets/test.png');
    });

    test('should be const constructor', () {
      const category1 = Category(
        title: 'Test',
        color: Colors.red,
        imagePath: 'path.png',
      );

      const category2 = Category(
        title: 'Test',
        color: Colors.red,
        imagePath: 'path.png',
      );

      expect(category1, category2);
    });

    test('should handle different categories', () {
      const carCategory = Category(
        title: 'Автомобили',
        color: Colors.blue,
        imagePath: 'assets/car.png',
      );

      const realEstateCategory = Category(
        title: 'Недвижимость',
        color: Colors.green,
        imagePath: 'assets/house.png',
      );

      expect(carCategory.title, 'Автомобили');
      expect(realEstateCategory.title, 'Недвижимость');
      expect(carCategory.color, isNot(equals(realEstateCategory.color)));
    });
  });

  group('Listing Model', () {
    test('should create Listing with required parameters', () {
      final listing = Listing(
        id: 'test_listing_id_1',
        imagePath: 'assets/listing.png',
        title: 'Test Listing',
        price: '100 000 ₽',
        location: 'Москва',
        date: '2024-01-01',
        isFavorited: false,
      );

      expect(listing.imagePath, 'assets/listing.png');
      expect(listing.title, 'Test Listing');
      expect(listing.price, '100 000 ₽');
      expect(listing.location, 'Москва');
      expect(listing.date, '2024-01-01');
      expect(listing.isFavorited, false);
    });

    // Removed the "should be const constructor" test as Listing is no longer const

    test('should handle different listings', () {
      final carListing = Listing(
        id: 'car_listing_id',
        imagePath: 'assets/car.png',
        title: 'BMW X5',
        price: '5 000 000 ₽',
        location: 'Москва',
        date: '2024-01-15',
        isFavorited: false,
      );

      final apartmentListing = Listing(
        id: 'apartment_listing_id',
        imagePath: 'assets/apartment.png',
        title: '3-комнатная квартира',
        price: '15 000 000 ₽',
        location: 'Санкт-Петербург',
        date: '2024-01-20',
        isFavorited: true,
      );

      expect(carListing.title, 'BMW X5');
      expect(apartmentListing.title, '3-комнатная квартира');
      expect(carListing.price, '5 000 000 ₽');
      expect(apartmentListing.price, '15 000 000 ₽');
      expect(carListing.location, 'Москва');
      expect(apartmentListing.location, 'Санкт-Петербург');
      expect(carListing.isFavorited, false);
      expect(apartmentListing.isFavorited, true);
    });
  });
}
