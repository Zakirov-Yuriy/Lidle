import 'package:flutter/material.dart';
import 'package:lidle/widgets/header.dart';

class RealEstateApartmentsScreen extends StatelessWidget {
  const RealEstateApartmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // тёмный фон
      
      body: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Padding(
            padding: const EdgeInsets.only(top: 20.0, bottom: 30),
            child:  const Header(),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20.0, right: 20),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.lightBlueAccent, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'Назад',
                  style: TextStyle(
                    color: Colors.lightBlueAccent,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Закрыть экран при отмене
                  },
                  child: const Text(
                    'Отмена',
                    style: TextStyle(
                      color: Colors.lightBlueAccent,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32.0, right: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Недвижимость: Квартиры',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildOptionTile(context, "Продажа квартир"),
                _buildOptionTile(context, "Долгосрочная аренда квартир"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(BuildContext context, String title) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            title,
            style: const TextStyle(color: Colors.white),
          ),
          onTap: () {
            // TODO: navigate to detailed form or filtered listings
          },
        ),
        const Divider(color: Colors.white24, height: 0.9),
      ],
    );
  }
}
