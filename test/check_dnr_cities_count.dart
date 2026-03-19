// Диагностический скрипт для проверки количества городов в dnr_cities
import 'package:lidle/constants/dnr_cities.dart';

void main() {
  print('=== Статистика городов ДНР ===');
  print('Всего городов в списке: ${dnrCities.length}');
  
  // Проверяем уникальные города (ищем дубликаты)
  final uniqueCities = <String>{...dnrCities};
  print('Уникальных городов: ${uniqueCities.length}');
  print('Дубликатов: ${dnrCities.length - uniqueCities.length}');
  
  // Ищем какие города повторяются
  final duplicates = <String>[];
  for (final city in dnrCities) {
    final count = dnrCities.where((c) => c == city).length;
    if (count > 1 && !duplicates.contains(city)) {
      duplicates.add(city);
      print('   Дубликат: "$city" появляется $count раз');
    }
  }
  
  print('\nПолный список (${uniqueCities.length} уникальных):');
  final sortedCities = uniqueCities.toList()..sort();
  for (int i = 0; i < sortedCities.length; i++) {
    print('  ${i + 1}. ${sortedCities[i]}');
  }
}
