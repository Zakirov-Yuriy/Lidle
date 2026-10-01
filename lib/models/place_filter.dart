// Выбранное место для ВЫДАЧИ: город, регион или «все регионы»
// (01.10.2026, задача 24).
//
// Зачем отдельная модель. До этого выбранный город жил в приложении одной
// строкой с названием, и фильтрация делалась сравнением этой строки с адресом
// объявления: `listing.location.startsWith('г Мариуполь')`. Это не фильтр, а
// совпадение текста. Объявление, у которого адрес записан иначе, из выдачи
// выпадало, человек видел «в вашем городе ничего нет», и починить это на
// клиенте нельзя: правильный отбор знает только сервер, у него есть номер
// города в адресе объявления.
//
// Теперь место это номер: `cityId` для населённого пункта, `regionId` для
// области и для городов-регионов (Москва, Санкт-Петербург, Севастополь), у
// которых записи города в справочнике нет вовсе. Название остаётся, но только
// чтобы показать человеку, в запрос оно не идёт.
//
// Третье состояние, которого раньше не было совсем: «все регионы». Это не
// пустая строка и не «город не выбран», а осознанный выбор человека смотреть
// выдачу по всей стране, и он сохраняется между запусками.

/// Место, по которому сейчас отбирается выдача.
class PlaceFilter {
  const PlaceFilter({
    this.cityId,
    this.regionId,
    this.name = '',
    this.isAll = false,
  });

  /// Все регионы: выдача по всей стране, место в запрос не уходит.
  const PlaceFilter.all() : this(isAll: true, name: 'Все регионы');

  /// Номер города в справочнике адресов.
  final int? cityId;

  /// Номер региона. Заполнен у области и у городов-регионов.
  final int? regionId;

  /// Название для показа человеку: «г Мариуполь», «Московская область».
  final String name;

  /// Человек выбрал «Все регионы».
  final bool isAll;

  /// Есть ли вообще выбор. Пустой объект означает «человек ещё не выбирал»,
  /// и это не то же самое, что «все регионы».
  bool get isEmpty => !isAll && cityId == null && regionId == null;

  bool get isNotEmpty => !isEmpty;

  /// Надпись для шапки выдачи.
  String get title {
    if (isAll) return 'Все регионы';
    if (name.trim().isNotEmpty) return name.trim();

    return 'Выберите город';
  }

  /// Что уходит на сервер в блоке `filters[address]`.
  ///
  /// У «всех регионов» и у пустого выбора это пустая карта: место в запросе
  /// не участвует, и выдача идёт по всей стране. Пустые значения внутрь не
  /// кладём намеренно: сервер по непустому блоку адреса раньше выбрасывал
  /// объявления без адресной записи.
  Map<String, int> toQuery() {
    if (isAll) return const {};

    if (cityId != null && cityId! > 0) {
      return {'city_id': cityId!};
    }

    if (regionId != null && regionId! > 0) {
      return {'region_id': regionId!};
    }

    return const {};
  }

  /// Для Hive: простая карта без вложенности.
  Map<String, dynamic> toMap() => {
        'city_id': cityId,
        'region_id': regionId,
        'name': name,
        'is_all': isAll,
      };

  static PlaceFilter? fromMap(Map? raw) {
    if (raw == null) return null;

    final isAll = raw['is_all'] == true;
    final cityId = _toInt(raw['city_id']);
    final regionId = _toInt(raw['region_id']);
    final name = (raw['name'] ?? '').toString();

    if (!isAll && cityId == null && regionId == null) return null;

    return PlaceFilter(
      cityId: cityId,
      regionId: regionId,
      name: name,
      isAll: isAll,
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value > 0 ? value : null;
    if (value is String) {
      final parsed = int.tryParse(value);

      return (parsed != null && parsed > 0) ? parsed : null;
    }

    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is PlaceFilter &&
      other.cityId == cityId &&
      other.regionId == regionId &&
      other.isAll == isAll;

  @override
  int get hashCode => Object.hash(cityId, regionId, isAll);

  @override
  String toString() => isAll
      ? 'PlaceFilter(все регионы)'
      : 'PlaceFilter(city=$cityId, region=$regionId, name=$name)';
}
