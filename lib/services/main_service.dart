import 'package:lidle/models/main_content_model.dart';
import 'package:lidle/services/api_service.dart';

/// Сервис для главной страницы и объявлений
class MainService {
  /// Получить содержание главной страницы (каталоги и избранные объявления)
  static Future<MainContent> getMainContent({String? token}) async {
    try {
      final response = await ApiService.getMainContent(token: token);
      return MainContent.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load main content: $e');
    }
  }

  /// Сохранить просмотр объявления (инкрементирует счётчик)
  static Future<void> saveAdvertView(int advertId, {String? token}) async {
    try {
      await ApiService.saveAdvertView(advertId, token: token);
    } catch (e) {
      throw Exception('Failed to save advert view: $e');
    }
  }

  /// Сохранить поделиться объявлением (инкрементирует счётчик)
  static Future<void> shareAdvert(int advertId, {String? token}) async {
    try {
      await ApiService.shareAdvert(advertId, token: token);
    } catch (e) {
      throw Exception('Failed to share advert: $e');
    }
  }
}
