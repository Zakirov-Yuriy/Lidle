import 'package:flutter/material.dart';
import 'package:lidle/pages/full_category_screen/property_details_screen.dart';

class MapScreen extends StatelessWidget {
  static const String routeName = '/map';

  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PropertyDetailsScreen()),
            );
          },
          child: Image.asset(
            'assets/map/map.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
