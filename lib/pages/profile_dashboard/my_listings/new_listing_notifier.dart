import 'dart:async';
import 'package:lidle/models/main_content_model.dart';

/// Синглтон-стрим для уведомления о появлении нового объявления.
/// Любой экран может вызвать notify() → AppWrapper перехватит и откроет PublishedScreen.
class NewListingNotifier {
  NewListingNotifier._();
  static final NewListingNotifier instance = NewListingNotifier._();

  final _controller = StreamController<UserAdvert?>.broadcast();

  Stream<UserAdvert?> get onNewListing => _controller.stream;

  /// Вызвать когда появилось новое активное объявление
  void notify(UserAdvert? advert) {
    if (!_controller.isClosed) {
      _controller.add(advert);
    }
  }

  void dispose() => _controller.close();
}