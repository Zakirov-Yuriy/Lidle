import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

/// ============================================================
/// "Виджет: Поле для ввода адреса (город + улица)"
/// ============================================================
/// Компонент для отображения выбранного адреса.
/// Управление данными осуществляется в экране-родителе.
/// ============================================================
class AddressField extends StatelessWidget {
  /// Выбранный город
  final String selectedCity;

  /// Выбранная улица
  final String selectedStreet;

  /// Callback когда нужно открыть выбор города
  final VoidCallback onCityTap;

  /// Callback когда нужно открыть выбор улицы
  final VoidCallback onStreetTap;

  const AddressField({
    required this.selectedCity,
    required this.selectedStreet,
    required this.onCityTap,
    required this.onStreetTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Адрес*',
          style: TextStyle(color: textPrimary, fontSize: 16),
        ),
        const SizedBox(height: 9),
        
        // Поле выбора города
        _buildAddressField(
          label: 'Город',
          value: selectedCity.isEmpty ? 'Выберите город' : selectedCity,
          onTap: onCityTap,
        ),
        const SizedBox(height: 10),
        
        // Поле выбора улицы
        _buildAddressField(
          label: 'Улица/Площадь',
          value: selectedStreet.isEmpty ? 'Выберите улицу' : selectedStreet,
          onTap: onStreetTap,
        ),
      ],
    );
  }

  /// Построение поля адреса
  Widget _buildAddressField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
