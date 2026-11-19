// Доставка покупателю: расчёт, города, пункты выдачи (задача 53, этап 5,
// 19.11.2026).
//
// ЭТО РУЧКИ ДЛЯ ТОГО, КТО ПОКУПАЕТ, а не для того, кто подключает службу.
// Поэтому они без входа: цену доставки человек хочет знать до того, как
// заведёт аккаунт.
//
// СПРАШИВАЕМ ПО МАГАЗИНУ, а не по продавцу. В корзине лежит точка, а кто ею
// владеет, покупателя не касается, и сервер находит владельца сам.
//
// ЦЕНА ОТСЮДА ТОЛЬКО ДЛЯ ПОКАЗА. При оформлении сервер спрашивает службу
// заново и присланной цене не верит: иначе доставку можно было бы назначить
// себе рублём прямо в запросе.
//
// Ручки: /v1/meta/delivery/{quote,cities,points}.

import 'package:lidle/core/logger.dart';
import 'package:lidle/services/api_service.dart';

/// Вариант доставки: служба, тариф, цена, срок.
class DeliveryQuote {
  const DeliveryQuote({
    required this.provider,
    required this.providerTitle,
    required this.code,
    required this.title,
    required this.price,
    this.daysMin = 0,
    this.daysMax = 0,
    this.toDoor = false,
  });

  factory DeliveryQuote.fromJson(Map<String, dynamic> json) {
    return DeliveryQuote(
      provider: (json['provider'] as String?) ?? '',
      providerTitle: (json['provider_title'] as String?) ?? '',
      code: '${json['code'] ?? ''}',
      title: (json['title'] as String?) ?? 'Доставка',
      price: _double(json['price']),
      daysMin: _int(json['days_min']),
      daysMax: _int(json['days_max']),
      toDoor: json['to_door'] == true,
    );
  }

  final String provider;
  final String providerTitle;

  /// Код тарифа службы. Строкой: у служб они разные по формату, и свой
  /// смысл мы в них не вкладываем, а передаём обратно как есть.
  final String code;

  final String title;
  final double price;
  final int daysMin;
  final int daysMax;

  /// Везут по адресу, а не в пункт выдачи.
  final bool toDoor;

  /// Срок словами. Пусто, если служба срок не назвала: врать про дни нельзя.
  String get daysTitle {
    if (daysMax <= 0 && daysMin <= 0) return '';

    if (daysMin > 0 && daysMax > 0 && daysMin != daysMax) {
      return 'от $daysMin до $daysMax дней';
    }

    final dney = daysMax > 0 ? daysMax : daysMin;

    return dney == 1 ? 'за день' : 'за $dney дней';
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse('$value') ?? 0;
  }

  static int _int(dynamic value) {
    if (value is num) return value.toInt();

    return int.tryParse('$value') ?? 0;
  }
}

/// Город службы: её собственный код плюс название.
class DeliveryCity {
  const DeliveryCity({
    required this.code,
    required this.name,
    this.region = '',
    this.provider = '',
  });

  factory DeliveryCity.fromJson(Map<String, dynamic> json) {
    return DeliveryCity(
      // Сервер называет это полем title: у службы это «город», а не «имя».
      code: '${json['code'] ?? ''}',
      name: (json['title'] as String?) ?? (json['name'] as String?) ?? '',
      region: (json['region'] as String?) ?? '',
      provider: (json['provider'] as String?) ?? '',
    );
  }

  final String code;
  final String name;
  final String region;
  final String provider;

  /// Название с областью: «Красный Яр» есть в десятке регионов.
  String get full => region.isEmpty ? name : '$name, $region';
}

/// Пункт выдачи службы.
class DeliveryPoint {
  const DeliveryPoint({
    required this.code,
    required this.address,
    this.city = '',
    this.provider = '',
    this.providerTitle = '',
    this.workTime = '',
    this.cash = false,
    this.card = false,
  });

  factory DeliveryPoint.fromJson(Map<String, dynamic> json) {
    return DeliveryPoint(
      code: '${json['code'] ?? ''}',
      address: (json['address'] as String?) ?? '',
      city: (json['city'] as String?) ?? '',
      provider: (json['provider'] as String?) ?? '',
      providerTitle: (json['provider_title'] as String?) ?? '',
      workTime: (json['work_time'] as String?) ?? '',
      cash: json['cash'] == true,
      card: json['card'] == true,
    );
  }

  final String code;
  final String address;
  final String city;
  final String provider;
  final String providerTitle;
  final String workTime;

  /// Можно ли там доплатить наличными и картой. Показываем подписью: людям
  /// это важнее часов работы.
  final bool cash;
  final bool card;
}

/// Ответ расчёта: варианты плюс объяснение, когда их нет.
class DeliveryQuotesAnswer {
  const DeliveryQuotesAnswer({this.quotes = const [], this.message});

  final List<DeliveryQuote> quotes;

  /// Почему пусто. Сервер объясняет словами, и экран показывает это, а не
  /// молчаливую пустоту.
  final String? message;

  bool get isEmpty => quotes.isEmpty;
}

class DeliveryQuotesService {
  static const String _path = '/meta/delivery';

  /// Сколько стоит довезти и за сколько дней.
  static Future<DeliveryQuotesAnswer> quote({
    required int shopId,
    String? cityCode,
    String? city,
    String? pointCode,
    int weight = 1000,
  }) async {
    final params = <String, String>{
      'shop_id': '$shopId',
      'weight': '$weight',
      if (cityCode != null && cityCode.isNotEmpty) 'city_code': cityCode,
      if (city != null && city.isNotEmpty) 'city': city,
      if (pointCode != null && pointCode.isNotEmpty) 'point_code': pointCode,
    };

    try {
      final response = await ApiService.get('$_path/quote?${_query(params)}');

      final data = response['data'];
      final meta = response['meta'];

      return DeliveryQuotesAnswer(
        quotes: data is List
            ? data
                .whereType<Map<String, dynamic>>()
                .map(DeliveryQuote.fromJson)
                .toList()
            : const [],
        message: meta is Map ? meta['message'] as String? : null,
      );
    } catch (e) {
      log.e('Расчёт доставки не удался: $e');

      // Пустой ответ, а не исключение наружу: расчёт доставки не должен
      // ломать оформление заказа. Человек выберет самовывоз или курьера.
      return const DeliveryQuotesAnswer(
        message: 'Не удалось рассчитать доставку. Попробуйте ещё раз.',
      );
    }
  }

  /// Города службы по началу названия.
  static Future<List<DeliveryCity>> cities({
    required int shopId,
    required String query,
  }) async {
    if (query.trim().length < 2) return const [];

    try {
      final response = await ApiService.get(
        '$_path/cities?${_query({'shop_id': '$shopId', 'query': query.trim()})}',
      );

      final data = response['data'];

      if (data is! List) return const [];

      return data
          .whereType<Map<String, dynamic>>()
          .map(DeliveryCity.fromJson)
          .toList();
    } catch (e) {
      log.e('Города доставки не загрузились: $e');

      return const [];
    }
  }

  /// Пункты выдачи в городе.
  static Future<List<DeliveryPoint>> points({
    required int shopId,
    String? cityCode,
    String? city,
    String? provider,
  }) async {
    final params = <String, String>{
      'shop_id': '$shopId',
      if (cityCode != null && cityCode.isNotEmpty) 'city_code': cityCode,
      if (city != null && city.isNotEmpty) 'city': city,
      if (provider != null && provider.isNotEmpty) 'provider': provider,
    };

    try {
      final response = await ApiService.get('$_path/points?${_query(params)}');

      final data = response['data'];

      if (data is! List) return const [];

      return data
          .whereType<Map<String, dynamic>>()
          .map(DeliveryPoint.fromJson)
          .toList();
    } catch (e) {
      log.e('Пункты выдачи не загрузились: $e');

      return const [];
    }
  }

  static String _query(Map<String, String> params) {
    return params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
  }
}
