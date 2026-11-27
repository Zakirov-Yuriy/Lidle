// ============================================================
//  "Точка на карте"
// ============================================================

/// Где находится объявление, товар или магазин (задача 71, 26.11.2026).
///
/// РЯДОМ С КООРДИНАТАМИ ИДЁТ РАДИУС, и он тут главное. Точный дом по адресу
/// находится не всегда: бывает, что известна только улица, а бывает, что
/// только населённый пункт. Метка в таком случае врёт: человек читает её как
/// «вот этот подъезд». Поэтому сервер отдаёт вместе с точкой радиус области,
/// которую мы на самом деле знаем, и карта рисует метку только при нуле, а
/// иначе круг.
class MapPoint {
  const MapPoint({
    required this.lat,
    required this.lon,
    required this.precision,
    required this.radius,
    this.source = 'directory',
  });

  final double lat;
  final double lon;

  /// Чем мы на самом деле располагаем: building, street или city.
  final String precision;

  /// Радиус области в метрах. Ноль значит «знаем дом».
  final int radius;

  /// Откуда точка: `directory` посчитана по адресу, `pin` поставлена
  /// человеком. Форме правки это нужно, чтобы не предлагать уточнить то,
  /// что человек уже уточнил.
  final String source;

  /// Метку ставил человек.
  bool get isPin => source == 'pin';

  /// Точка известна до дома, можно ставить метку.
  bool get isExact => radius <= 0;

  /// Разбор ответа сервера. Пусто означает, что координат нет и карту
  /// показывать нечем.
  static MapPoint? fromJson(dynamic raw) {
    if (raw is! Map) return null;

    final lat = (raw['lat'] as num?)?.toDouble();
    final lon = (raw['lon'] as num?)?.toDouble();

    if (lat == null || lon == null) return null;

    return MapPoint(
      lat: lat,
      lon: lon,
      precision: (raw['precision'] as String?) ?? 'city',
      radius: (raw['radius'] as num?)?.toInt() ?? 0,
      source: (raw['source'] as String?) ?? 'directory',
    );
  }

  /// Для кэша карточек: блок хранит их в своём хранилище как обычный JSON.
  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lon': lon,
        'precision': precision,
        'radius': radius,
        'source': source,
      };

  /// Насколько близко подводить камеру.
  ///
  /// Зум подобран так, чтобы в кадр попадала ровно та область, которую мы
  /// знаем: дом с соседними домами, улица целиком, город целиком. Иначе
  /// карта у неточного адреса показывала бы двор, которого мы не знаем.
  double get zoom {
    if (radius <= 0) return 16.5;
    if (radius <= 500) return 15.0;

    return 12.0;
  }
}
