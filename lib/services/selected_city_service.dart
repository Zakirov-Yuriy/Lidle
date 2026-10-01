// ============================================================
// Выбранное место для выдачи: город, регион или «все регионы»
// ============================================================
//
// Переписано 01.10.2026 (задача 24).
//
// Как было. Сервис хранил ОДНУ СТРОКУ с названием города, и этого названия
// хватало только на показ. Отбор по городу делался в самих экранах выдачи
// сравнением названия с адресом объявления, причём в двух экранах по-разному:
// один сравнивал началом строки, другой вхождением в нижнем регистре. Одна и
// та же выборка давала разные результаты, а объявления с иначе записанным
// адресом терялись совсем.
//
// Как стало. Сервис хранит выбор целиком: номер города или региона, название
// для показа и признак «все регионы». Номер уходит на сервер, и отбор делает
// он. Диалоги выбора города кладут выбор ЗДЕСЬ, поэтому экранам, которые их
// открывают, ничего менять не нужно: их около двадцати пяти, и трогать каждый
// значило бы растянуть правку на недели.
//
// Выбор сохраняется между запусками: человек, выбравший «все регионы», не
// должен снова получать свой город после перезапуска приложения.

import 'package:lidle/core/logger.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/models/place_filter.dart';

class SelectedCityService {
  static final SelectedCityService _instance = SelectedCityService._internal();

  SelectedCityService._internal();

  factory SelectedCityService() => _instance;

  /// Ключ в настройках Hive.
  static const String _storageKey = 'selectedPlaceFilter';

  /// Текущий выбор. Пустой объект означает «человек ещё не выбирал».
  PlaceFilter _place = const PlaceFilter();

  /// Загружен ли выбор из хранилища: читаем один раз за запуск.
  bool _restored = false;

  /// Пришли ли мы с экрана общих фильтров. Поведение экранов выдачи от этого
  /// зависит, поле осталось с прежней версии сервиса.
  bool _isFromFiltersScreen = false;

  /// Выбранное место.
  PlaceFilter get place {
    _restore();

    return _place;
  }

  /// Название выбранного места. Оставлено для экранов, которые показывают
  /// город подписью и ничего не знают про номера.
  String? get selectedCity {
    final current = place;

    if (current.isAll) return null;

    return current.name.trim().isEmpty ? null : current.name.trim();
  }

  bool get isFromFiltersScreen => _isFromFiltersScreen;

  /// Выбраны все регионы.
  bool get isAllRegions => place.isAll;

  /// Номер города для запроса выдачи, если выбран именно город.
  int? get cityId => place.cityId;

  /// Номер региона для запроса выдачи.
  int? get regionId => place.regionId;

  /// Что положить в `filters[address]`. Пустая карта значит «все регионы».
  Map<String, int> get query => place.toQuery();

  /// Сохранить выбор места.
  void setPlace(PlaceFilter value, {bool isFromFiltersScreen = false}) {
    _restored = true;
    _place = value;
    _isFromFiltersScreen = isFromFiltersScreen;

    _persist();
  }

  /// Выбрать все регионы.
  void setAllRegions({bool isFromFiltersScreen = false}) {
    setPlace(const PlaceFilter.all(), isFromFiltersScreen: isFromFiltersScreen);
  }

  /// Лента главной: свой выключатель городского приоритета.
  ///
  /// Отдельно от места выдачи намеренно. На главной город не фильтр, а
  /// приоритет: свой город идёт сверху, остальное ниже, и сервер берёт его из
  /// профиля. Кнопка «Сбросить» просит ленту без приоритета. Если мешать это
  /// с местом выдачи, нажатие «Мой город» на главной стирало бы город,
  /// выбранный в фильтрах категории.
  static const String _feedKey = 'feedAllRegions';

  bool? _feedAll;

  bool get feedAllRegions {
    if (_feedAll != null) return _feedAll!;

    try {
      _feedAll = HiveService.settingsBox.get(_feedKey) == true;
    } catch (e) {
      log.w('Не смог прочитать выбор ленты: $e');
      _feedAll = false;
    }

    return _feedAll!;
  }

  void setFeedAllRegions(bool value) {
    _feedAll = value;

    try {
      HiveService.settingsBox.put(_feedKey, value);
    } catch (e) {
      log.w('Не смог сохранить выбор ленты: $e');
    }
  }

  /// Старый способ: только название.
  ///
  /// Оставлен, чтобы экраны, которые ещё не научились отдавать номер города,
  /// продолжали работать. Номера у такого выбора нет, поэтому сервер отберёт
  /// по всей стране, а не по городу: это честнее прежнего поведения, когда
  /// выдача молча теряла объявления с иначе записанным адресом.
  void setSelectedCity(String city, {bool isFromFiltersScreen = false}) {
    _restore();

    final name = city.trim();

    if (name.isEmpty) {
      clear();

      return;
    }

    setPlace(
      PlaceFilter(name: name, cityId: _place.name == name ? _place.cityId : null),
      isFromFiltersScreen: isFromFiltersScreen,
    );
  }

  /// Сбросить выбор в «человек не выбирал». Не то же самое, что все регионы.
  void clear() {
    _restored = true;
    _place = const PlaceFilter();
    _isFromFiltersScreen = false;

    _persist();
  }

  void _restore() {
    if (_restored) return;

    _restored = true;

    try {
      final raw = HiveService.settingsBox.get(_storageKey);

      if (raw is Map) {
        final restored = PlaceFilter.fromMap(Map<String, dynamic>.from(raw));

        if (restored != null) {
          _place = restored;
        }
      }
    } catch (e) {
      // Хранилище может быть не открыто (первый запуск, тесты): выбор просто
      // останется пустым, это рабочее состояние.
      log.w('Не смог прочитать выбранное место: $e');
    }
  }

  void _persist() {
    try {
      if (_place.isEmpty) {
        HiveService.settingsBox.delete(_storageKey);

        return;
      }

      HiveService.settingsBox.put(_storageKey, _place.toMap());
    } catch (e) {
      log.w('Не смог сохранить выбранное место: $e');
    }
  }
}
