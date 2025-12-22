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

  /// Проверяет, является ли объявление избранным.
  static bool isFavorite(String listingId) {
    return getFavorites().contains(listingId);
  }

  /// Добавляет или удаляет favorite id из списка favorites.
  /// Возвращает true, если объявление стало избранным, иначе false.
  static bool toggleFavorite(String listingId) {
    final favorites = getFavorites().toSet();
    bool newFavoriteStatus;
    if (favorites.contains(listingId)) {
      favorites.remove(listingId);
      newFavoriteStatus = false;
    } else {
      favorites.add(listingId);
      newFavoriteStatus = true;
    }
    settingsBox.put('favorites', favorites.toList());
    return newFavoriteStatus;
  }

  /// Сохраняет выбранный город в настройки.
  static Future<void> saveSelectedCity(String city) async {
    await settingsBox.put('selectedCity', city);
  }

  /// Получает выбранный город из настроек, по умолчанию 'г. Мариуполь. ДНР'.
  static String getSelectedCity() {
    return settingsBox.get('selectedCity', defaultValue: 'г. Мариуполь. ДНР');
  }

  /// Сохраняет архивные сообщения.
  static Future<void> saveArchivedMessages(List<Map<String, dynamic>> messages) async {
    await settingsBox.put('archivedMessages', messages);
  }

  /// Получает архивные сообщения.
  static List<Map<String, dynamic>> getArchivedMessages() {
    final raw = settingsBox.get('archivedMessages', defaultValue: []);
    if (raw is List) {
      return raw.map((item) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        } else {
          return <String, dynamic>{};
        }
      }).toList();
    }
    return [];
  }

  /// Добавляет сообщение в архив.
  static Future<void> addToArchive(Map<String, dynamic> message) async {
    final archived = getArchivedMessages();
    archived.add(message);
    await saveArchivedMessages(archived);
  }

  /// Удаляет сообщение из архива по индексу.
  static Future<void> removeFromArchive(int index) async {
    final archived = getArchivedMessages();
    if (index >= 0 && index < archived.length) {
      archived.removeAt(index);
      await saveArchivedMessages(archived);
    }
  }

  /// Сохраняет текущие сообщения.
  static Future<void> saveCurrentMessages(List<Map<String, dynamic>> messages) async {
    await settingsBox.put('currentMessages', messages);
  }

  /// Получает текущие сообщения.
  static List<Map<String, dynamic>> getCurrentMessages() {
    final raw = settingsBox.get('currentMessages', defaultValue: []);
    if (raw is List) {
      return raw.map((item) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        } else {
          return <String, dynamic>{};
        }
      }).toList();
    }
    return [];
  }

  /// Восстанавливает сообщение из архива в текущие.
  static Future<void> restoreFromArchive(int archiveIndex) async {
    final archived = getArchivedMessages();
    if (archiveIndex >= 0 && archiveIndex < archived.length) {
      final message = archived[archiveIndex];
      final current = getCurrentMessages();
      // Check if message already exists (by senderName and isInternal)
      final exists = current.any((m) => m['senderName'] == message['senderName'] && m['isInternal'] == message['isInternal']);
      if (!exists) {
        current.add(message);
        await saveCurrentMessages(current);
      }
      archived.removeAt(archiveIndex);
      await saveArchivedMessages(archived);
    }
  }
}
