/// Откуда покупатель написал (09.10.2026, задача 15).
///
/// Сервер отдаёт одну и ту же структуру для пяти видов: объявление, товар,
/// предложение цены, отклик и бронь. Поэтому в приложении одна модель и
/// одна вёрстка, а не пять.
///
/// Приходит в трёх местах: в списке чатов, в самой переписке и в каждом
/// сообщении, поле называется `source`. Пусто это нормально: из списка
/// чатов пишут просто так, без привязки.
class ChatSource {
  /// Вид источника: advert, product, offer, response, booking.
  final String type;

  /// Номер самого источника. У предложения цены это номер предложения.
  final int id;

  /// Куда ведёт кнопка «Перейти»: advert или product.
  final String? targetType;

  /// Номер того, куда вести. У предложения цены это номер объявления,
  /// а не предложения, поэтому поле отдельное.
  final int? targetId;

  final String? title;
  final String? image;

  /// Цена строкой, уже с рублём. Собирается на сервере, чтобы приложение и
  /// сайт писали одинаково.
  final String? price;

  /// Жёлтая строка снизу. Сейчас только у предложения цены.
  final String? note;

  /// Дата и время. Только у брони.
  final String? startsAt;

  const ChatSource({
    required this.type,
    required this.id,
    this.targetType,
    this.targetId,
    this.title,
    this.image,
    this.price,
    this.note,
    this.startsAt,
  });

  static ChatSource? fromJson(dynamic json) {
    if (json is! Map) return null;

    final type = json['type'];
    final id = json['id'];

    if (type is! String || type.isEmpty) return null;

    final parsedId = id is int ? id : int.tryParse('$id');
    if (parsedId == null) return null;

    String? text(dynamic value) {
      if (value == null) return null;
      final s = '$value'.trim();
      return s.isEmpty ? null : s;
    }

    final targetId = json['target_id'];

    return ChatSource(
      type: type,
      id: parsedId,
      targetType: text(json['target_type']),
      targetId: targetId is int ? targetId : int.tryParse('${targetId ?? ''}'),
      title: text(json['title']),
      image: text(json['image']),
      price: text(json['price']),
      note: text(json['note']),
      startsAt: text(json['starts_at']),
    );
  }

  /// Подпись над плашкой, чтобы продавец сразу понимал, откуда письмо.
  String get caption {
    switch (type) {
      case 'product':
        return 'Со страницы товара';
      case 'offer':
        return 'Предложил цену';
      case 'response':
        return 'Отклик';
      case 'booking':
        return 'Бронирование';
      default:
        return 'Со страницы объявления';
    }
  }

  bool get leadsToProduct => targetType == 'product';
}
