/// Сервис для работы с локальным хранилищем данных Hive.
/// Предоставляет методы для инициализации, сохранения, получения и удаления данных
/// для пользовательских настроек и других данных приложения.
import 'package:hive/hive.dart';

/// `HiveService` - это статический класс, который управляет взаимодействием с Hive.
/// Он предоставляет удобный интерфейс для работы с двумя основными "боксами" (хранилищами):
/// `_userBox` для пользовательских данных и `_settingsBox` для настроек приложения.
class HiveService {
  /// Приватная константа для имени бокса, хранящего пользовательские данные.
  static const String _userBox = 'userBox';
  /// Приватная константа для имени бокса, хранящего настройки приложения.
  static const String _settingsBox = 'settingsBox';

  /// Инициализирует сервис Hive, открывая все необходимые боксы.
  /// Этот метод должен быть вызван перед любыми операциями с Hive.
  static Future<void> init() async {
    await Hive.openBox(_userBox);
    await Hive.openBox(_settingsBox);
  }

  /// Возвращает открытый бокс для пользовательских данных.
  static Box get userBox => Hive.box(_userBox);

  /// Сохраняет пару ключ-значение в бокс пользовательских данных.
  /// [key] - уникальный идентификатор для сохранения данных.
  /// [value] - данные, которые нужно сохранить.
  static Future<void> saveUserData(String key, dynamic value) async {
    await userBox.put(key, value);
  }

  /// Получает данные из бокса пользовательских данных по указанному ключу.
  /// [key] - ключ, по которому нужно получить данные.
  /// Возвращает данные, связанные с ключом, или `null`, если ключ не найден.
  static dynamic getUserData(String key) {
    return userBox.get(key);
  }

  /// Удаляет данные из бокса пользовательских данных по указанному ключу.
  /// [key] - ключ данных, которые нужно удалить.
  static Future<void> deleteUserData(String key) async {
    await userBox.delete(key);
  }

  /// Возвращает открытый бокс для настроек приложения.
  static Box get settingsBox => Hive.box(_settingsBox);

  /// Сохраняет пару ключ-значение в бокс настроек.
  /// [key] - уникальный идентификатор для сохранения настройки.
  /// [value] - значение настройки.
  static Future<void> saveSetting(String key, dynamic value) async {
    await settingsBox.put(key, value);
  }

  /// Получает значение настройки из бокса настроек по указанному ключу.
  /// [key] - ключ, по которому нужно получить настройку.
  /// [defaultValue] - значение, которое будет возвращено, если ключ не найден.
  /// Возвращает значение настройки или `defaultValue`, если оно предоставлено и ключ не найден.
  static dynamic getSetting(String key, {dynamic defaultValue}) {
    return settingsBox.get(key, defaultValue: defaultValue);
  }

  /// Очищает все данные из боксов пользовательских данных и настроек.
  /// Используется, например, при выходе пользователя из аккаунта.
  static Future<void> clearAllData() async {
    await userBox.clear();
    await settingsBox.clear();
  }

  /// Закрывает все открытые боксы Hive.
  /// Рекомендуется вызывать при завершении работы приложения для освобождения ресурсов.
  static Future<void> close() async {
    await Hive.close();
  }

  /// Возвращает список favorite ids из settingsBox.
  static List<String> getFavorites() {
    final favorites = settingsBox.get('favorites', defaultValue: <String>[]);
    return favorites is List ? favorites.cast<String>() : [];
  }

  /// Добавляет или удаляет favorite id из списка favorites.
  static Future<void> toggleFavorite(String listingId) async {
    final favorites = getFavorites().toSet();
    if (favorites.contains(listingId)) {
      favorites.remove(listingId);
    } else {
      favorites.add(listingId);
    }
    await settingsBox.put('favorites', favorites.toList());
  }
}
