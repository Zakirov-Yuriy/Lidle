// ============================================================
//  "Точка выдачи на карте"
// ============================================================

/// Одно объявление или товар на карте выдачи (задача 71, 27.11.2026).
///
/// НАРОЧНО КОРОТКАЯ. На карте одновременно бывают сотни точек, и от каждой
/// нужны только координаты, цена и название: всё остальное человек увидит,
/// когда нажмёт на метку и провалится в карточку. Полная модель карточки
/// здесь означала бы мегабайты на каждое движение пальца.
class MapItem {
  const MapItem({
    required this.type,
    required this.id,
    required this.lat,
    required this.lon,
    required this.name,
    required this.price,
  });

  /// `advert` или `product`: по нему экран решает, куда вести по нажатию.
  final String type;

  final int id;
  final double lat;
  final double lon;
  final String name;
  final String price;

  bool get isProduct => type == 'product';

  static MapItem? fromJson(dynamic raw) {
    if (raw is! Map) return null;

    final lat = (raw['lat'] as num?)?.toDouble();
    final lon = (raw['lon'] as num?)?.toDouble();

    if (lat == null || lon == null) return null;

    return MapItem(
      type: (raw['type'] as String?) ?? 'advert',
      id: (raw['id'] as num?)?.toInt() ?? 0,
      lat: lat,
      lon: lon,
      name: (raw['name'] ?? '').toString(),
      price: (raw['price'] ?? '').toString(),
    );
  }
}
