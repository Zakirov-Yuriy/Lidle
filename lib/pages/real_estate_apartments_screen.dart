import 'package:flutter/material.dart';
import 'add_real_estate_apt_screen.dart';

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
            padding: const EdgeInsets.only(left: 10.0, right: 10, top: 20),
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
            padding: const EdgeInsets.only(left: 25.0, right: 25),
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
            if (title == "Продажа квартир") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddRealEstateAptScreen()),
              );
            } else {
              // TODO: handle other cases
            }
          },
        ),
        const Divider(color: Colors.white24, height: 0.9),
      ],
    );
  }
}
