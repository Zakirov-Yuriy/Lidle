import 'package:hive/hive.dart';

class HiveService {
  static const String _userBox = 'userBox';
  static const String _settingsBox = 'settingsBox';

  // Открытие боксов
  static Future<void> init() async {
    await Hive.openBox(_userBox);
    await Hive.openBox(_settingsBox);
  }

  // Пользовательские данные
  static Box get userBox => Hive.box(_userBox);

  // Сохранение данных пользователя
  static Future<void> saveUserData(String key, dynamic value) async {
    await userBox.put(key, value);
  }

  // Получение данных пользователя
  static dynamic getUserData(String key) {
    return userBox.get(key);
  }

  // Удаление данных пользователя
  static Future<void> deleteUserData(String key) async {
    await userBox.delete(key);
  }

  // Настройки
  static Box get settingsBox => Hive.box(_settingsBox);

  // Сохранение настроек
  static Future<void> saveSetting(String key, dynamic value) async {
    await settingsBox.put(key, value);
  }

  // Получение настроек
  static dynamic getSetting(String key, {dynamic defaultValue}) {
    return settingsBox.get(key, defaultValue: defaultValue);
  }

  // Очистка всех данных (при выходе из аккаунта и т.д.)
  static Future<void> clearAllData() async {
    await userBox.clear();
    await settingsBox.clear();
  }

  // Закрытие всех боксов
  static Future<void> close() async {
    await Hive.close();
  }
}
