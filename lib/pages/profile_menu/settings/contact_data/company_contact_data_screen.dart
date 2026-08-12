// ============================================================
// "Виджет: Экран контактных данных КОМПАНИИ"
// ============================================================
// Отдельный от пользователя экран. Скалярные поля компании
// (название/описание/email/телефон/адрес) сохраняются на
// /me/settings/company/*, множественные контакты — на
// /me/settings/company/{phones|emails|telegrams|maxes}. Загрузка текущих
// значений: GET /companies/{userId} (скаляры + адрес с названиями) плюс
// index-эндпоинты контактов (для id, нужных при обновлении).
// У компании НЕТ поля «Фамилия» — это личное поле пользователя.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart'; // 🧨 Импорт для skeleton loader
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';
import 'package:lidle/services/company_contact_service.dart';
import 'package:lidle/services/user_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/services/address_service.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/core/cache/cache_service.dart';
import 'package:lidle/core/cache/cache_keys.dart';
import 'package:lidle/core/cache/screen_cache_manager.dart';
import 'package:lidle/core/logger.dart';

/// Регулярка для обнаружения ссылок (http/https/ftp, www., t.me/, домены с
/// популярными TLD). Используется для запрета ссылок в поле «Описание компании».
final RegExp _linkRegExp = RegExp(
  r'(https?:\/\/|ftp:\/\/|www\.|t\.me\/|[a-zA-Zа-яА-Я0-9\-]+\.(ru|рф|com|net|org|io|me|info|biz|ua|su|co|app|site|online|shop|store|link|xyz|top|club|dev|tech))',
  caseSensitive: false,
);

bool _hasLink(String text) => _linkRegExp.hasMatch(text);

/// Форматтер, запрещающий ввод/вставку ссылок в реальном времени.
class _NoLinksInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return _hasLink(newValue.text) ? oldValue : newValue;
  }
}

class CompanyContactDataScreen extends StatefulWidget {
  static const routeName = '/company_contact_data';

  const CompanyContactDataScreen({super.key});

  @override
  State<CompanyContactDataScreen> createState() =>
      _CompanyContactDataScreenState();
}

class _CompanyContactDataScreenState extends State<CompanyContactDataScreen> {
  late TextEditingController _nameController;
  late TextEditingController _aboutController;
  late TextEditingController _emailController;
  late TextEditingController _phone1Controller;
  late TextEditingController _phone2Controller;
  late TextEditingController _telegramController;
  late TextEditingController _maxController;

  bool _isLoading = false;
  String? _errorMessage;

  // Длина «Описание компании» для счётчика (лимит бэкенда max:250).
  static const int _aboutMaxLength = 250;
  int _aboutLength = 0;

  int? _userId;

  int? _phone1Id;
  int? _phone2Id;
  int? _emailId;
  int? _telegramId;
  int? _maxId;

  // Область / город.
  Set<String> _selectedRegion = {};
  Set<String> _selectedCity = {};
  int? _selectedRegionId;
  int? _selectedCityId;
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _cities = [];
  final Map<String, int> _lastCitiesSearchResults = {};

  // Улица / дом (необязательный точный адрес).
  Set<String> _selectedStreet = {};
  Set<String> _selectedBuilding = {};
  int? _selectedStreetId;
  int? _selectedBuildingId;
  List<Map<String, dynamic>> _streets = [];
  List<Map<String, dynamic>> _buildings = [];
  final Map<String, int> _lastStreetsSearchResults = {};

  static const bgColor = Color(0xFF243241);
  static const fieldColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const hintColor = Colors.white54;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _aboutController = TextEditingController();
    _emailController = TextEditingController();
    _phone1Controller = TextEditingController();
    _phone2Controller = TextEditingController();
    _telegramController = TextEditingController();
    _maxController = TextEditingController();
    _aboutController.addListener(() {
      if (_aboutLength != _aboutController.text.length) {
        setState(() => _aboutLength = _aboutController.text.length);
      }
    });
    _loadRegions();

    // 💾 Кеширование как на экране пользователя (contact_data):
    // если кеш свежий — мгновенно восстанавливаем поля из локального хранилища
    // (без скелетона) и тихо обновляем данные с бэка в фоне; иначе — обычная
    // загрузка со скелетоном.
    if (!_shouldRefreshCompanyData() && _restoreCompanyFromCache()) {
      _loadCompanyData(silent: true);
    } else {
      _loadCompanyData();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    _emailController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    _telegramController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  int? _asId(dynamic v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse('$v'));

  /// Возвращает id текущего пользователя (компания 1 к 1 с пользователем).
  Future<int?> _resolveUserId(String token) async {
    if (_userId != null) return _userId;
    // Сначала из локального хранилища (быстро), иначе с бэка (/me).
    final localId = _asId(UserService.getLocal('userId'));
    if (localId != null) {
      _userId = localId;
      return _userId;
    }
    try {
      final profile = await UserService.getProfile(token: token);
      _userId = profile.id;
    } catch (e) {
      log.d('❌ Не удалось получить id пользователя: $e');
    }
    return _userId;
  }

  /// Загружает регионы (для отображения/выбора области).
  Future<void> _loadRegions() async {
    try {
      final token = TokenService.currentToken;
      final regions = await ApiService.getRegions(token: token);
      if (mounted) setState(() => _regions = regions);
      log.d('✅ Загружено регионов: ${regions.length}');
    } catch (e) {
      log.d('❌ Ошибка загрузки регионов: $e');
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _loadRegions();
      });
    }
  }

  /// Извлекает список {id, value} из ответа index-эндпоинта контактов.
  List<Map<String, dynamic>> _extractList(
    Map<String, dynamic> resp,
    String valueKey,
  ) {
    final data = resp['data'];
    final out = <Map<String, dynamic>>[];
    if (data is List) {
      for (final item in data) {
        if (item is Map) {
          out.add({
            'id': _asId(item['id']),
            'value': (item[valueKey] ?? '').toString(),
          });
        }
      }
    }
    return out;
  }

  /// Загружает данные компании с бэка.
  /// [silent] = true — фоновое обновление: НЕ показываем скелетон (данные уже
  /// восстановлены из кеша), просто тихо обновляем поля и id контактов.
  Future<void> _loadCompanyData({int retryCount = 0, bool silent = false}) async {
    setState(() {
      if (!silent) _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = TokenService.currentToken;
      if (token == null) {
        setState(() {
          _errorMessage = 'Токен не найден';
          _isLoading = false;
        });
        return;
      }

      final userId = await _resolveUserId(token);
      if (userId == null) {
        setState(() {
          _errorMessage = 'Не удалось определить пользователя';
          _isLoading = false;
        });
        return;
      }

      // Скаляры + адрес (id и названия) компании.
      final profile =
          await CompanyContactService.getCompanyProfile(userId: userId, token: token);
      final data = (profile['data'] is Map)
          ? Map<String, dynamic>.from(profile['data'] as Map)
          : <String, dynamic>{};
      final address = (data['address'] is Map)
          ? Map<String, dynamic>.from(data['address'] as Map)
          : <String, dynamic>{};

      // Множественные контакты (для id, нужных при обновлении).
      final phones =
          _extractList(await CompanyContactService.getPhones(token: token), 'phone');
      final emails =
          _extractList(await CompanyContactService.getEmails(token: token), 'email');
      final telegrams = _extractList(
          await CompanyContactService.getTelegrams(token: token), 'username');
      final maxes =
          _extractList(await CompanyContactService.getMaxes(token: token), 'username');

      if (!mounted) return;

      // Название / описание.
      final name = (data['name'] ?? '').toString();
      final about = (data['about'] ?? '').toString();

      // Email: приоритет коллекции, иначе скаляр company_contacts.
      String email = (data['email'] ?? '').toString();
      if (emails.isNotEmpty) {
        _emailId = emails.first['id'] as int?;
        if ((emails.first['value'] as String).isNotEmpty) {
          email = emails.first['value'] as String;
        }
      }

      // Телефон 1: приоритет коллекции, иначе скаляр.
      String phone1 = (data['phone'] ?? '').toString();
      if (phones.isNotEmpty) {
        _phone1Id = phones.first['id'] as int?;
        if ((phones.first['value'] as String).isNotEmpty) {
          phone1 = phones.first['value'] as String;
        }
      }
      if (phone1.isNotEmpty && !phone1.startsWith('+')) phone1 = '+$phone1';

      // Телефон 2: второй элемент коллекции.
      String phone2 = '';
      if (phones.length > 1) {
        _phone2Id = phones[1]['id'] as int?;
        phone2 = phones[1]['value'] as String;
        if (phone2.isNotEmpty && !phone2.startsWith('+')) phone2 = '+$phone2';
      }

      // Telegram / MAX.
      String telegram = '';
      if (telegrams.isNotEmpty) {
        _telegramId = telegrams.first['id'] as int?;
        telegram = telegrams.first['value'] as String;
      }
      String max = '';
      if (maxes.isNotEmpty) {
        _maxId = maxes.first['id'] as int?;
        max = maxes.first['value'] as String;
      }

      // Адрес: id и названия прямо из ответа.
      final regionName = (address['main_region_name'] ?? '').toString();
      final cityName = (address['city_name'] ?? '').toString();
      final streetName = (address['street_name'] ?? '').toString();
      final buildingName = (address['building_name'] ?? '').toString();
      final regionId = _asId(address['main_region_id']);
      final cityId = _asId(address['city_id']);
      final streetId = _asId(address['street_id']);
      final buildingId = _asId(address['building_id']);

      setState(() {
        _nameController.text = name;
        _aboutController.text = about;
        _aboutLength = about.length;
        _emailController.text = email;
        _phone1Controller.text = phone1;
        _phone2Controller.text = phone2;
        _telegramController.text = telegram;
        _maxController.text = max;

        if (regionName.isNotEmpty) {
          _selectedRegion = {regionName};
          _selectedRegionId = regionId;
        }
        if (cityName.isNotEmpty) {
          _selectedCity = {cityName};
          _selectedCityId = cityId;
          if (cityId != null) _lastCitiesSearchResults[cityName] = cityId;
        }
        if (streetName.isNotEmpty && streetId != null) {
          _selectedStreet = {streetName};
          _selectedStreetId = streetId;
          _streets = [
            {'name': streetName, 'id': streetId},
          ];
          _lastStreetsSearchResults[streetName] = streetId;
          if (buildingName.isNotEmpty && buildingId != null) {
            _selectedBuilding = {buildingName};
            _selectedBuildingId = buildingId;
            _buildings = [
              {'name': buildingName, 'id': buildingId},
            ];
          }
        }

        _isLoading = false;
      });

      // Успешная загрузка с бэка — отмечаем время для кеша экрана.
      ScreenCacheManager.companyContactDataLastLoadTime = DateTime.now();

      // Кэшируем адрес/телефон компании для подстановки при создании объявления.
      await _cacheCompanyDefaults();

      // Предзагружаем города для выбранной области, чтобы диалог не был пустым.
      if (_selectedRegionId != null && _cities.isEmpty) {
        await _loadCitiesForSelectedRegion();
      }
    } catch (e) {
      const maxRetries = 2;
      const retryDelayMs = 2000;
      if (retryCount < maxRetries) {
        log.d('⚠️ Сбой загрузки компании (попытка ${retryCount + 1}), повтор...');
        await Future.delayed(const Duration(milliseconds: retryDelayMs));
        await _loadCompanyData(retryCount: retryCount + 1, silent: silent);
      } else {
        setState(() {
          _errorMessage = 'Ошибка загрузки: ${e.toString()}';
          _isLoading = false;
        });
        log.d('❌ Сбой загрузки данных компании: $e');
      }
    }
  }

  /// Сохранить/обновить одиночный контакт (телефон/почта/мессенджер) компании.
  /// Возвращает текст ошибки или null при успехе.
  Future<String?> _saveSingle({
    required String value,
    required int? existingId,
    required Future<Map<String, dynamic>> Function() create,
    required Future<Map<String, dynamic>> Function(int) update,
    required String label,
    void Function(int?)? onId,
  }) async {
    final v = value.trim();
    if (v.isEmpty) return null;
    try {
      final resp = existingId != null ? await update(existingId) : await create();
      if (resp['success'] == false) {
        return resp['message']?.toString() ?? '$label: ошибка сохранения';
      }
      // После создания подхватываем новый id (для последующих обновлений).
      if (existingId == null && onId != null) {
        final data = resp['data'];
        if (data is List && data.isNotEmpty && data.first is Map) {
          onId(_asId((data.first as Map)['id']));
        } else if (data is Map && data['data'] is List) {
          final inner = data['data'] as List;
          if (inner.isNotEmpty && inner.first is Map) {
            onId(_asId((inner.first as Map)['id']));
          }
        }
      }
      log.d('✅ $label компании сохранён');
      return null;
    } catch (e) {
      log.d('❌ Ошибка сохранения $label компании: $e');
      return '$label: не удалось сохранить';
    }
  }

  /// Кэширует адрес и телефон КОМПАНИИ в локальное хранилище под company-ключами.
  /// Эти значения подставляются при создании объявления (dynamic_filter),
  /// поскольку объявление выставляет компания. Ключи отдельные от пользовательских
  /// ('region'/'city'/'phone2'), чтобы не пересекаться с личными контактами.
  Future<void> _cacheCompanyDefaults() async {
    final regionName = _selectedRegion.isNotEmpty ? _selectedRegion.first : '';
    final cityName = _selectedCity.isNotEmpty ? _selectedCity.first : '';
    await UserService.saveLocal('companyRegion', regionName);
    await UserService.saveLocal('companyCity', cityName);
    await UserService.saveLocal('companyRegionId', _selectedRegionId?.toString() ?? '');
    await UserService.saveLocal('companyCityId', _selectedCityId?.toString() ?? '');
    await UserService.saveLocal('companyPhone2', _phone2Controller.text.trim());

    // Улица и номер дома компании (для подстановки в форму объявления).
    final streetName = _selectedStreet.isNotEmpty ? _selectedStreet.first : '';
    final buildingName = _selectedBuilding.isNotEmpty ? _selectedBuilding.first : '';
    await UserService.saveLocal('companyStreet', streetName);
    await UserService.saveLocal('companyStreetId', _selectedStreetId?.toString() ?? '');
    await UserService.saveLocal('companyBuilding', buildingName);
    await UserService.saveLocal('companyBuildingId', _selectedBuildingId?.toString() ?? '');

    // Остальные поля формы компании — для мгновенного восстановления экрана
    // из кеша (без скелетона) при повторном открытии.
    await UserService.saveLocal('companyName', _nameController.text.trim());
    await UserService.saveLocal('companyAbout', _aboutController.text);
    await UserService.saveLocal('companyEmail', _emailController.text.trim());
    await UserService.saveLocal('companyPhone1', _phone1Controller.text.trim());
    await UserService.saveLocal('companyTelegram', _telegramController.text.trim());
    await UserService.saveLocal('companyMax', _maxController.text.trim());
  }

  /// Кеш экрана компании считается устаревшим, если прошло больше 10 минут
  /// с последней загрузки с бэка (или её ещё не было).
  static const Duration _companyDataCacheDuration = Duration(minutes: 10);

  bool _shouldRefreshCompanyData() {
    final last = ScreenCacheManager.companyContactDataLastLoadTime;
    if (last == null) return true;
    return DateTime.now().difference(last).inMinutes >=
        _companyDataCacheDuration.inMinutes;
  }

  /// Мгновенно восстанавливает поля формы из локального кеша (без скелетона).
  /// Возвращает true, если в кеше были какие-то данные компании.
  bool _restoreCompanyFromCache() {
    final name = UserService.getLocal('companyName') as String? ?? '';
    final about = UserService.getLocal('companyAbout') as String? ?? '';
    final email = UserService.getLocal('companyEmail') as String? ?? '';
    final phone1 = UserService.getLocal('companyPhone1') as String? ?? '';
    final phone2 = UserService.getLocal('companyPhone2') as String? ?? '';
    final telegram = UserService.getLocal('companyTelegram') as String? ?? '';
    final max = UserService.getLocal('companyMax') as String? ?? '';

    final regionName = UserService.getLocal('companyRegion') as String? ?? '';
    final cityName = UserService.getLocal('companyCity') as String? ?? '';
    final regionIdStr = UserService.getLocal('companyRegionId') as String? ?? '';
    final cityIdStr = UserService.getLocal('companyCityId') as String? ?? '';
    final streetName = UserService.getLocal('companyStreet') as String? ?? '';
    final streetIdStr = UserService.getLocal('companyStreetId') as String? ?? '';
    final buildingName = UserService.getLocal('companyBuilding') as String? ?? '';
    final buildingIdStr = UserService.getLocal('companyBuildingId') as String? ?? '';

    // Если кеш пуст (первый вход) — сообщаем, что восстанавливать нечего.
    final hasAnything = [
      name, about, email, phone1, phone2, telegram, max, regionName, cityName,
    ].any((s) => s.isNotEmpty);
    if (!hasAnything) return false;

    setState(() {
      _nameController.text = name;
      _aboutController.text = about;
      _aboutLength = about.length;
      _emailController.text = email;
      _phone1Controller.text = phone1;
      _phone2Controller.text = phone2;
      _telegramController.text = telegram;
      _maxController.text = max;

      if (regionName.isNotEmpty) {
        _selectedRegion = {regionName};
        _selectedRegionId =
            regionIdStr.isNotEmpty ? int.tryParse(regionIdStr) : null;
      }
      if (cityName.isNotEmpty) {
        _selectedCity = {cityName};
        _selectedCityId = cityIdStr.isNotEmpty ? int.tryParse(cityIdStr) : null;
      }
      if (streetName.isNotEmpty) {
        final sid = streetIdStr.isNotEmpty ? int.tryParse(streetIdStr) : null;
        _selectedStreet = {streetName};
        _selectedStreetId = sid;
        if (sid != null) {
          _streets = [
            {'name': streetName, 'id': sid},
          ];
        }
        if (buildingName.isNotEmpty) {
          final bid =
              buildingIdStr.isNotEmpty ? int.tryParse(buildingIdStr) : null;
          _selectedBuilding = {buildingName};
          _selectedBuildingId = bid;
          if (bid != null) {
            _buildings = [
              {'name': buildingName, 'id': bid},
            ];
          }
        }
      }

      _isLoading = false;
    });
    return true;
  }

  Future<void> _saveCompanyData() async {
    if (_hasLink(_aboutController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('В поле «Описание компании» нельзя добавлять ссылки'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_aboutController.text.length > _aboutMaxLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('«Описание компании»: не более 250 символов'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = TokenService.currentToken;
      if (token == null) {
        setState(() {
          _errorMessage = 'Токен не найден';
          _isLoading = false;
        });
        return;
      }

      final name = _nameController.text.trim();
      final about = _aboutController.text;
      final email = _emailController.text.trim();
      final phone1 = _phone1Controller.text.trim();
      final phone2 = _phone2Controller.text.trim();

      final errors = <String>[];

      // Название компании (скаляр).
      try {
        await CompanyContactService.changeName(name: name, token: token);
      } catch (e) {
        log.d('❌ Ошибка сохранения названия компании: $e');
      }

      // Описание компании (скаляр). Шлём всегда, в т.ч. пустое (очистка).
      try {
        final resp =
            await CompanyContactService.changeAbout(about: about, token: token);
        if (resp['success'] == false) {
          errors.add(resp['message']?.toString() ?? 'Описание: ошибка');
        }
      } catch (e) {
        log.d('❌ Ошибка сохранения описания компании: $e');
      }

      // Email: скаляр company_contacts + коллекция (для витрины компании).
      if (email.isNotEmpty) {
        try {
          await CompanyContactService.changeEmail(email: email, token: token);
        } catch (e) {
          log.d('❌ Ошибка сохранения email компании (скаляр): $e');
        }
        final err = await _saveSingle(
          value: email,
          existingId: _emailId,
          create: () => CompanyContactService.addEmail(email: email, token: token),
          update: (id) =>
              CompanyContactService.updateEmail(id: id, email: email, token: token),
          label: 'Email',
          onId: (id) => _emailId = id,
        );
        if (err != null) errors.add(err);
      }

      // Телефон 1: скаляр + коллекция (первый элемент).
      if (phone1.isNotEmpty) {
        try {
          await CompanyContactService.changePhone(phone: phone1, token: token);
        } catch (e) {
          log.d('❌ Ошибка сохранения телефона компании (скаляр): $e');
        }
        final err = await _saveSingle(
          value: phone1,
          existingId: _phone1Id,
          create: () => CompanyContactService.addPhone(phone: phone1, token: token),
          update: (id) =>
              CompanyContactService.updatePhone(id: id, phone: phone1, token: token),
          label: 'Телефон 1',
          onId: (id) => _phone1Id = id,
        );
        if (err != null) errors.add(err);
      }

      // Телефон 2: коллекция (второй элемент).
      if (phone2.isNotEmpty) {
        final err = await _saveSingle(
          value: phone2,
          existingId: _phone2Id,
          create: () => CompanyContactService.addPhone(phone: phone2, token: token),
          update: (id) =>
              CompanyContactService.updatePhone(id: id, phone: phone2, token: token),
          label: 'Телефон 2',
          onId: (id) => _phone2Id = id,
        );
        if (err != null) errors.add(err);
      }

      // Адрес: шлём выбранный город, бэк выведет подрегион и область.
      if (_selectedCityId != null) {
        try {
          final resp = await CompanyContactService.changeAddress(
            cityId: _selectedCityId!,
            streetId: _selectedStreetId,
            buildingId: _selectedBuildingId,
            token: token,
          );
          if (resp['success'] == false) {
            log.d('⚠️ Адрес компании не сохранён: ${resp['message']}');
          }
        } catch (e) {
          log.d('❌ Ошибка сохранения адреса компании: $e');
        }
      }

      // Telegram.
      final tgErr = await _saveSingle(
        value: _telegramController.text,
        existingId: _telegramId,
        create: () => CompanyContactService.addTelegram(
            username: _telegramController.text.trim(), token: token),
        update: (id) => CompanyContactService.updateTelegram(
            id: id, username: _telegramController.text.trim(), token: token),
        label: 'Telegram',
        onId: (id) => _telegramId = id,
      );
      if (tgErr != null) errors.add(tgErr);

      // MAX.
      final maxErr = await _saveSingle(
        value: _maxController.text,
        existingId: _maxId,
        create: () => CompanyContactService.addMax(
            username: _maxController.text.trim(), token: token),
        update: (id) => CompanyContactService.updateMax(
            id: id, username: _maxController.text.trim(), token: token),
        label: 'MAX',
        onId: (id) => _maxId = id,
      );
      if (maxErr != null) errors.add(maxErr);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });

      // Обновляем кэш адреса/телефона компании для создания объявления.
      await _cacheCompanyDefaults();

      // Данные компании изменились — сбрасываем кэш карточки продавца, чтобы
      // на экране профиля продавца при следующем открытии подтянулись новые
      // название/описание/адрес/контакты (а не старые из кэша).
      final ownId = await _resolveUserId(token);
      if (ownId != null) {
        AppCacheService().invalidate(CacheKeys.sellerInfoKey(ownId.toString()));
      }

      if (errors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Контактные данные компании сохранены'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Сохранено, но: ${errors.join('; ')}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка сохранения: ${e.toString()}';
        _isLoading = false;
      });
      log.d('❌ Ошибка в _saveCompanyData: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Адресные дропдауны (регион → город → улица → дом)
  // ─────────────────────────────────────────────

  Future<void> _loadCitiesForSelectedRegion() async {
    if (_selectedRegionId == null) return;
    String? searchQuery;
    if (_selectedRegion.isNotEmpty) {
      final regionName = _selectedRegion.first.trim();
      if (regionName.length >= 3) {
        searchQuery =
            regionName.length > 50 ? regionName.substring(0, 50) : regionName;
      }
    }
    if (searchQuery == null) return;
    try {
      final token = TokenService.currentToken;
      final response = await AddressService.searchAddresses(
        query: searchQuery,
        token: token,
        types: ['city'],
        filters: {'main_region_id': _selectedRegionId},
      );
      final uniqueCities = <String, int>{};
      for (final result in response.data) {
        if (result.main_region?.id == _selectedRegionId && result.city != null) {
          uniqueCities[result.city!.name] = result.city!.id;
          _lastCitiesSearchResults[result.city!.name] = result.city!.id;
        }
      }
      if (mounted) {
        setState(() {
          _cities = uniqueCities.entries
              .map((e) => {'name': e.key, 'id': e.value})
              .toList();
          _cities.sort(
              (a, b) => (a['name'] as String).compareTo(b['name'] as String));
        });
      }
    } catch (e) {
      log.d('❌ Ошибка предзагрузки городов: $e');
    }
  }

  Future<List<String>> _searchStreetsAPI(String query) async {
    if (_selectedCityId == null) return [];
    if (query.trim().length < 3) return [];
    try {
      final token = TokenService.currentToken;
      final response = await AddressService.searchAddresses(
        query: query.trim(),
        token: token,
        types: ['street'],
        filters: {'city_id': _selectedCityId},
      );
      final streets = <String>[];
      for (final result in response.data) {
        if (result.city?.id == _selectedCityId && result.street != null) {
          streets.add(result.street!.name);
          _lastStreetsSearchResults[result.street!.name] = result.street!.id;
        }
      }
      return streets;
    } catch (e) {
      log.d('❌ Ошибка поиска улиц: $e');
      return [];
    }
  }

  Future<void> _loadStreetsForSelectedCity() async {
    if (_selectedCityId == null) return;
    String? searchQuery;
    if (_selectedCity.isNotEmpty) {
      final cleaned = _selectedCity.first.trim();
      if (cleaned.length >= 3) {
        searchQuery = cleaned.length > 50 ? cleaned.substring(0, 50) : cleaned;
      }
    }
    if (searchQuery == null) return;
    try {
      final token = TokenService.currentToken;
      final response = await AddressService.searchAddresses(
        query: searchQuery,
        token: token,
        types: ['street'],
        filters: {'city_id': _selectedCityId},
      );
      final uniqueStreets = <String, int>{};
      for (final result in response.data) {
        if (result.city?.id == _selectedCityId && result.street != null) {
          uniqueStreets[result.street!.name] = result.street!.id;
          _lastStreetsSearchResults[result.street!.name] = result.street!.id;
        }
      }
      if (mounted) {
        setState(() {
          _streets = uniqueStreets.entries
              .map((e) => {'name': e.key, 'id': e.value})
              .toList();
        });
      }
    } catch (e) {
      log.d('❌ Ошибка загрузки улиц: $e');
    }
  }

  Future<void> _loadBuildingsForSelectedStreet() async {
    if (_selectedStreetId == null) return;
    String? searchQuery;
    if (_selectedStreet.isNotEmpty) {
      final cleaned = _selectedStreet.first.trim();
      if (cleaned.length >= 3) {
        searchQuery = cleaned.length > 50 ? cleaned.substring(0, 50) : cleaned;
      }
    }
    if (searchQuery == null) return;
    try {
      final token = TokenService.currentToken;
      final response = await AddressService.searchAddresses(
        query: searchQuery,
        token: token,
        types: ['building'],
        filters: {'street_id': _selectedStreetId},
      );
      final uniqueBuildings = <String, int>{};
      for (final result in response.data) {
        if (result.street?.id == _selectedStreetId && result.building != null) {
          uniqueBuildings[result.building!.name] = result.building!.id;
        }
      }
      if (mounted) {
        setState(() {
          _buildings = uniqueBuildings.entries
              .map((e) => {'name': e.key, 'id': e.value})
              .toList();
        });
      }
    } catch (e) {
      log.d('❌ Ошибка загрузки домов: $e');
    }
  }

  // ─────────────────────────────────────────────
  // UI helpers
  // ─────────────────────────────────────────────

  /// 🧨 Skeleton loader для экрана контактных данных компании.
  /// Показывает структуру формы во время загрузки (как на contact_data).
  Widget _buildSkeletonFields() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2F4456),
      highlightColor: const Color(0xFF3F5567),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Описание компании
          _skeletonLabel(),
          _skeletonField(),
          const SizedBox(height: 8),

          // Название компании
          _skeletonLabel(),
          _skeletonField(),
          const SizedBox(height: 8),

          // Область
          _skeletonLabel(),
          _skeletonField(),
          const SizedBox(height: 8),

          // Город
          _skeletonLabel(),
          _skeletonField(),
          const SizedBox(height: 8),

          // Улица
          _skeletonLabel(),
          _skeletonField(),
          const SizedBox(height: 8),

          // Номер дома
          _skeletonLabel(),
          _skeletonField(),
          const SizedBox(height: 8),

          // Email
          _skeletonLabel(),
          _skeletonField(),
          const SizedBox(height: 8),

          // Телефон 1
          _skeletonLabel(),
          _skeletonField(),
          const SizedBox(height: 8),

          // Телефон 2
          _skeletonLabel(),
          _skeletonField(),
          const SizedBox(height: 8),

          // Telegram
          _skeletonLabel(),
          _skeletonField(),
          const SizedBox(height: 8),

          // Max
          _skeletonLabel(),
          _skeletonField(),
          const SizedBox(height: 24),

          // Кнопка сохранения
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Container(
              height: 47,
              decoration: BoxDecoration(
                color: const Color(0xFF2F4456),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Skeleton для лейбла (подпись поля).
  Widget _skeletonLabel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 14, 25, 6),
      child: Container(
        height: 14,
        width: 120,
        decoration: BoxDecoration(
          color: const Color(0xFF2F4456),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  /// Skeleton для поля ввода.
  Widget _skeletonField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF2F4456),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  Widget _label(String text, {String? note}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 14, 25, 6),
      child: Text.rich(
        TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          children: note == null
              ? null
              : [
                  TextSpan(
                    text: '  $note',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: fieldColor,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller: controller,
          inputFormatters: inputFormatters,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: hint.isEmpty ? null : hint,
            hintStyle: const TextStyle(color: hintColor),
          ),
        ),
      ),
    );
  }

  /// Поле «Описание компании» с ограничением 250 символов и счётчиком.
  Widget _aboutField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Container(
        decoration: BoxDecoration(
          color: fieldColor,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              controller: _aboutController,
              maxLines: 3,
              minLines: 1,
              inputFormatters: [
                _NoLinksInputFormatter(),
                LengthLimitingTextInputFormatter(_aboutMaxLength),
              ],
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Опишите вашу компанию',
                hintStyle: TextStyle(color: hintColor),
              ),
            ),
            Text(
              '$_aboutLength/$_aboutMaxLength',
              style: TextStyle(
                color: _aboutLength >= _aboutMaxLength
                    ? Colors.orangeAccent
                    : Colors.white38,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: GestureDetector(
        onTap: () {
          if (_regions.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Области загружаются...')),
            );
            return;
          }
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return SelectionDialog(
                title: 'Выберите область',
                options: _regions.map((r) => r['name'] as String).toList(),
                selectedOptions: _selectedRegion,
                allowMultipleSelection: false,
                onSelectionChanged: (Set<String> selected) {
                  if (selected.isNotEmpty) {
                    final selectedRegionName = selected.first;
                    final regionIndex = _regions
                        .indexWhere((r) => r['name'] == selectedRegionName);
                    int? regionId;
                    if (regionIndex >= 0) {
                      regionId = _regions[regionIndex]['id'] as int?;
                    }
                    setState(() {
                      _selectedRegion = selected;
                      _selectedRegionId = regionId;
                      _selectedCity.clear();
                      _selectedCityId = null;
                      _cities.clear();
                      _selectedStreet.clear();
                      _selectedStreetId = null;
                      _streets.clear();
                      _selectedBuilding.clear();
                      _selectedBuildingId = null;
                      _buildings.clear();
                    });
                    if (regionId != null) _loadCitiesForSelectedRegion();
                  }
                },
              );
            },
          );
        },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: fieldColor,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _selectedRegion.isEmpty
                      ? 'Выберите область'
                      : _selectedRegion.first,
                  style: TextStyle(
                    color:
                        _selectedRegion.isEmpty ? Colors.white54 : Colors.white,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCityDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: GestureDetector(
        onTap: _selectedRegionId == null
            ? null
            : () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SelectionDialog(
                      title: 'Выберите город',
                      showSearchField: true,
                      options: _cities.map((c) => c['name'] as String).toList(),
                      selectedOptions: _selectedCity,
                      allowMultipleSelection: false,
                      onSearchQuery: (query) async {
                        try {
                          final token = TokenService.currentToken;
                          if (token == null) return [];
                          final response = await AddressService.searchAddresses(
                            query: query,
                            token: token,
                            types: ['city'],
                            filters: _selectedRegionId != null
                                ? {'main_region_id': _selectedRegionId}
                                : null,
                          );
                          final cities = <String>{};
                          for (final result in response.data) {
                            if (result.city != null) {
                              cities.add(result.city!.name);
                              _lastCitiesSearchResults[result.city!.name] =
                                  result.city!.id;
                            }
                          }
                          return cities.toList();
                        } catch (e) {
                          log.d('❌ Ошибка поиска городов: $e');
                          return [];
                        }
                      },
                      onSelectionChanged: (Set<String> selected) {
                        if (selected.isNotEmpty) {
                          final selectedCityName = selected.first;
                          int? cityId =
                              _lastCitiesSearchResults[selectedCityName];
                          if (cityId == null) {
                            final cityIndex = _cities.indexWhere(
                                (c) => c['name'] == selectedCityName);
                            if (cityIndex >= 0) {
                              cityId = _cities[cityIndex]['id'] as int?;
                            }
                          }
                          setState(() {
                            _selectedCity = selected;
                            _selectedCityId = cityId;
                            _selectedStreet.clear();
                            _selectedStreetId = null;
                            _streets.clear();
                            _selectedBuilding.clear();
                            _selectedBuildingId = null;
                            _buildings.clear();
                          });
                          if (cityId != null) _loadStreetsForSelectedCity();
                        }
                      },
                    );
                  },
                );
              },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: _selectedRegionId == null
                ? const Color(0xFF2F4456)
                : fieldColor,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _selectedCity.isEmpty ? 'Выберите город' : _selectedCity.first,
                  style: TextStyle(
                    color: _selectedCity.isEmpty
                        ? Colors.white54
                        : (_selectedRegionId == null
                            ? Colors.white38
                            : Colors.white),
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: _selectedRegionId == null
                      ? Colors.white24
                      : Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreetDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: GestureDetector(
        onTap: _selectedCityId == null
            ? null
            : () async {
                if (_streets.isEmpty) {
                  await _loadStreetsForSelectedCity();
                }
                if (!mounted) return;
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SelectionDialog(
                      title: 'Выберите улицу',
                      showSearchField: true,
                      options: _streets.map((s) => s['name'] as String).toList(),
                      selectedOptions: _selectedStreet,
                      allowMultipleSelection: false,
                      onSearchQuery: _searchStreetsAPI,
                      onSelectionChanged: (Set<String> selected) {
                        if (selected.isNotEmpty) {
                          final selectedStreetName = selected.first;
                          int? streetId =
                              _lastStreetsSearchResults[selectedStreetName];
                          if (streetId == null) {
                            final idx = _streets.indexWhere(
                                (s) => s['name'] == selectedStreetName);
                            if (idx >= 0) {
                              streetId = _streets[idx]['id'] as int?;
                            }
                          }
                          setState(() {
                            _selectedStreet = selected;
                            _selectedStreetId = streetId;
                            _selectedBuilding.clear();
                            _selectedBuildingId = null;
                            _buildings.clear();
                          });
                          if (streetId != null) {
                            _loadBuildingsForSelectedStreet();
                          }
                        }
                      },
                    );
                  },
                );
              },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color:
                _selectedCityId == null ? const Color(0xFF2F4456) : fieldColor,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _selectedStreet.isEmpty
                      ? 'Выберите улицу'
                      : _selectedStreet.first,
                  style: TextStyle(
                    color: _selectedStreet.isEmpty
                        ? Colors.white54
                        : (_selectedCityId == null
                            ? Colors.white38
                            : Colors.white),
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: _selectedCityId == null
                      ? Colors.white24
                      : Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBuildingDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: GestureDetector(
        onTap: _selectedStreetId == null
            ? null
            : () async {
                if (_buildings.isEmpty) {
                  await _loadBuildingsForSelectedStreet();
                }
                if (!mounted) return;
                if (_buildings.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Дома по этой улице не найдены')),
                  );
                  return;
                }
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SelectionDialog(
                      title: 'Выберите номер дома',
                      showSearchField: true,
                      options:
                          _buildings.map((b) => b['name'] as String).toList(),
                      selectedOptions: _selectedBuilding,
                      allowMultipleSelection: false,
                      onSelectionChanged: (Set<String> selected) {
                        if (selected.isNotEmpty) {
                          final selectedBuildingName = selected.first;
                          final idx = _buildings.indexWhere(
                              (b) => b['name'] == selectedBuildingName);
                          int? buildingId;
                          if (idx >= 0) {
                            buildingId = _buildings[idx]['id'] as int?;
                          }
                          setState(() {
                            _selectedBuilding = selected;
                            _selectedBuildingId = buildingId;
                          });
                        }
                      },
                    );
                  },
                );
              },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color:
                _selectedStreetId == null ? const Color(0xFF2F4456) : fieldColor,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _selectedBuilding.isEmpty
                      ? 'Выберите номер дома'
                      : _selectedBuilding.first,
                  style: TextStyle(
                    color: _selectedBuilding.isEmpty
                        ? Colors.white54
                        : (_selectedStreetId == null
                            ? Colors.white38
                            : Colors.white),
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: _selectedStreetId == null
                      ? Colors.white24
                      : Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ───── Header ─────
              Padding(
                padding: const EdgeInsets.only(bottom: 20, right: 23),
                child: Row(children: const [Header()]),
              ),

              // ───── Back row (адаптивный заголовок) ─────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Контактные данные компании',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Назад',
                        style: TextStyle(color: accentColor, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 25),
                child: Text(
                  'Здесь вы указываете контактные данные вашей компании. Они '
                  'будут видны в объявлениях и в вашем магазине.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),
                ),

              if (_isLoading)
                // 🧨 Skeleton loader вместо простого индикатора загрузки —
                // заранее показываем структуру формы (как на contact_data).
                _buildSkeletonFields()
              else ...[
                _label('Описание компании'),
                _aboutField(),

                _label('Название компании'),
                _field(_nameController, 'Введите название компании'),

                _label('Ваша область'),
                _buildRegionDropdown(),

                _label('Ваш город'),
                _buildCityDropdown(),

                _label('Улица', note: '(Виден в вашем магазине)'),
                _buildStreetDropdown(),

                _label('Номер дома', note: '(Физический адрес компании)'),
                _buildBuildingDropdown(),

                _label('Электронная почта', note: '(Скрыта от пользователей)'),
                _field(_emailController, 'Введите почту компании'),

                _label('Номер телефона 1'),
                _field(_phone1Controller, 'Введите номер телефона'),

                _label('Номер телефона 2'),
                _field(_phone2Controller, 'Введите'),

                _label('Ссылка на ваш чат в Telegram'),
                _field(_telegramController, '@username или t.me/username'),

                _label('Ссылка на ваш чат в Max'),
                _field(_maxController, '@username или max.ru/username'),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: SizedBox(
                    width: double.infinity,
                    height: 47,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      onPressed: _isLoading ? null : _saveCompanyData,
                      child: const Text(
                        'Сохранить',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
