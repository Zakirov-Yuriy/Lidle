import 'package:flutter/material.dart';

class Category {
  final String title;
  final Color color;
  final String imagePath;

  const Category({
    required this.title,
    required this.color,
    required this.imagePath,
  });
}

class Listing {
  final String imagePath;
  final String title;
  final String price;
  final String location;
  final String date;

  const Listing({
    required this.imagePath,
    required this.title,
    required this.price,
    required this.location,
    required this.date,
  });
}
