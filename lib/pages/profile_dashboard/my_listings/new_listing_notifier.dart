import 'dart:async';
import 'package:lidle/models/main_content_model.dart';

/// Синглтон-стрим для уведомления о появлении нового объявления.
/// Любой экран может вызвать notify() → AppWrapper перехватит и откроет PublishedScreen.
/// 
/// **ЛОГИКА**:
/// 1. После публикации объявления сохраняется его ID (_lastCreatedAdvertId)
/// 2. На my_listings_screen при загрузке активных объявлений проверяется наличие этого ID
/// 3. Если объявление найдено в активных - отправляется notify() один раз
/// 4. После уведомления ID очищается
class NewListingNotifier {
  NewListingNotifier._();
  static final NewListingNotifier instance = NewListingNotifier._();

  final _controller = StreamController<UserAdvert?>.broadcast();
  
  /// ID недавно созданного объявления (которое еще на модерации)
  int? _lastCreatedAdvertId;
  
  /// ID последнего объявления, для которого было отправлено уведомление
  /// Используется для предотвращения повторного отправления того же уведомления
  int? _lastNotifiedAdvertId;

  Stream<UserAdvert?> get onNewListing => _controller.stream;

  /// Сохранить ID только что созданного объявления (которое еще на модерации)
  /// Вызывается из dynamic_filter.dart после успешного создания
  void setLastCreatedAdvertId(int advertId) {
    _lastCreatedAdvertId = advertId;
  }

  /// Проверить - это ли ID только что созданного объявления?
  /// Используется на my_listings_screen при загрузке активных объявлений
  bool isLastCreatedAdvert(int advertId) {
    return _lastCreatedAdvertId != null && _lastCreatedAdvertId == advertId;
  }

  /// Вызвать когда только что созданное объявление появилось в активных
  /// (т.е. когда оно прошло модерацию и стало активным)
  /// 
  /// Уведомление будет отправлено только если это объявление еще не было уведомлено
  void notify(UserAdvert? advert) {
    if (!_controller.isClosed && advert != null) {
      // Отправляем уведомление только если это новое объявление (не отправляли для него раньше)
      if (_lastNotifiedAdvertId != advert.id) {
        _lastNotifiedAdvertId = advert.id;
        _controller.add(advert);
        
        // Очищаем ID созданного объявления после отправки уведомления
        _lastCreatedAdvertId = null;
      }
    }
  }

  /// Очистить последнее уведомление (используется после показа PublishedScreen)
  void clearLastNotification() {
    _lastNotifiedAdvertId = null;
    _lastCreatedAdvertId = null;
  }

  void dispose() => _controller.close();
}