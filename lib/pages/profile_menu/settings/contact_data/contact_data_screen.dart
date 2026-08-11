// ============================================================
// "Виджет: Экран контактных данных"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart'; // 🧨 Импорт для skeleton loader
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/dialogs/selection_dialog.dart';
import 'package:lidle/services/contact_service.dart';
import 'package:lidle/services/user_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/services/my_adverts_service.dart';
import 'package:lidle/services/address_service.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/blocs/profile/profile_bloc.dart';
import 'package:lidle/blocs/profile/profile_event.dart';
import 'package:lidle/blocs/profile/profile_state.dart';
import 'package:lidle/blocs/listings/listings_bloc.dart';
import 'package:lidle/blocs/listings/listings_event.dart';
import 'package:lidle/blocs/connectivity/connectivity_bloc.dart';
import 'package:lidle/blocs/connectivity/connectivity_state.dart';
import 'package:lidle/blocs/connectivity/connectivity_event.dart';
import 'package:lidle/widgets/no_internet_screen.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/core/cache/screen_cache_manager.dart';
import 'package:lidle/core/cache/cache_service.dart';
import 'package:lidle/core/cache/cache_keys.dart';

/// Регулярка для обнаружения ссылок (http/https/ftp, www., t.me/, домены с
/// популярными TLD). Используется для запрета ссылок в поле «Описание компании».
final RegExp _linkRegExp = RegExp(
  r'(https?:\/\/|ftp:\/\/|www\.|t\.me\/|[a-zA-Zа-яА-Я0-9\-]+\.(ru|рф|com|net|org|io|me|info|biz|ua|su|co|app|site|online|shop|store|link|xyz|top|club|dev|tech))',
  caseSensitive: false,
);

/// true, если в тексте есть ссылка.
bool _hasLink(String text) => _linkRegExp.hasMatch(text);

/// Форматтер, запрещающий ввод/вставку ссылок в поле ввода (в реальном времени).
class _NoLinksInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Если новое значение содержит ссылку — откатываем к предыдущему.
    return _hasLink(newValue.text) ? oldValue : newValue;
  }
}

class ContactDataScreen extends StatefulWidget {
  static const routeName = '/contact_data';

  const ContactDataScreen({super.key});

  @override
  State<ContactDataScreen> createState() => _ContactDataScreenState();
}

class _ContactDataScreenState extends State<ContactDataScreen> {
  late TextEditingController _nameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phone1Controller;
  late TextEditingController _phone2Controller;
  late TextEditingController _telegramController;
  late TextEditingController _whatsappController;
  late TextEditingController _maxController;
  late TextEditingController _aboutController;

  bool _isLoading = false;
  String? _errorMessage;
  // Однократно запрашиваем профиль с бэка при входе на экран
  bool _profileRequested = false;

  int? _phone1Id;
  int? _phone2Id;
  int? _emailId;
  int? _telegramId; // id записи телеграма (для update)
  int? _maxId; // id записи MAX (для update)

  // Переменные для выбора области и города
  Set<String> _selectedRegion = {};
  Set<String> _selectedCity = {};
  int? _selectedRegionId;
  int? _selectedCityId;
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _cities = [];
  Map<String, int> _lastCitiesSearchResults = {};

  // Переменные для выбора улицы и дома (точный адрес, необязательный).
  // Улица зависит от выбранного города, дом — от выбранной улицы.
  Set<String> _selectedStreet = {};
  Set<String> _selectedBuilding = {};
  int? _selectedStreetId;
  int? _selectedBuildingId;
  List<Map<String, dynamic>> _streets = [];
  List<Map<String, dynamic>> _buildings = [];
  Map<String, int> _lastStreetsSearchResults = {};

  static const Duration _contactDataCacheDuration = Duration(minutes: 10);

  static const bgColor = Color(0xFF243241);
  static const fieldColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const hintColor = Colors.white54;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();
    _phone1Controller = TextEditingController();
    _phone2Controller = TextEditingController();
    _telegramController = TextEditingController();
    _whatsappController = TextEditingController();
    _maxController = TextEditingController();
    _aboutController = TextEditingController();
    // Загружаем регионы при инициализации
    _loadRegions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ignore: avoid_print
    // log.d('🔵 ContactDataScreen: didChangeDependencies() called');

    // 📲 Один раз запрашиваем профиль с бэка (GET /me), чтобы имя и фамилия
    // гарантированно пришли и заполнили поля через BlocListener ниже.
    if (!_profileRequested) {
      _profileRequested = true;
      context.read<ProfileBloc>().add(LoadProfileEvent());
    }

    // 💾 КЕШИРОВАНИЕ: Проверяем нужно ли обновлять данные
    if (_shouldRefreshContactData()) {
      // ignore: avoid_print
      log.d(
        '🔄 ContactDataScreen: Cache expired или первый вход, загружаем свежие данные',
      );
      _loadContactData();
      ScreenCacheManager.contactDataLastLoadTime = DateTime.now();
    } else {
      // Кеш ещё актуален - восстанавливаем данные из локального хранилища
      // ignore: avoid_print
      log.d('✅ ContactDataScreen: Кеш актуален, восстанавливаем данные');
      _restoreDataFromCache();
    }

    // Телеграм и MAX всегда подтягиваем с бэка (они не в общем профиле, а в
    // /me/settings/telegrams и /me/settings/maxes). Backend-значения главнее.
    _loadMessengers();
  }

  /// Загружает телеграм и MAX с бэка, заполняет поля и id (для update).
  Future<void> _loadMessengers() async {
    final token = TokenService.currentToken;
    if (token == null || token.isEmpty) return;
    try {
      final tg = await ContactService.getTelegrams(token: token);
      final tgData = tg['data'];
      String tgValue = '';
      int? tgId;
      if (tgData is List && tgData.isNotEmpty && tgData.first is Map) {
        final m = tgData.first as Map;
        tgId = _msgId(m['id']);
        tgValue = (m['username'] ?? '').toString();
      }

      final mx = await ContactService.getMaxes(token: token);
      final mxData = mx['data'];
      String mxValue = '';
      int? mxId;
      if (mxData is List && mxData.isNotEmpty && mxData.first is Map) {
        final m = mxData.first as Map;
        mxId = _msgId(m['id']);
        mxValue = (m['username'] ?? '').toString();
      }

      if (!mounted) return;
      setState(() {
        _telegramId = tgId;
        _telegramController.text = tgValue;
        _maxId = mxId;
        _maxController.text = mxValue;
      });
    } catch (e) {
      log.d('❌ Ошибка загрузки мессенджеров: $e');
    }
  }

  int? _msgId(dynamic v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse('$v'));

  /// Создать или обновить мессенджер (телеграм/MAX). Возвращает текст ошибки
  /// (или null при успехе). Если id неизвестен — уточняет через список.
  Future<String?> _saveMessenger({
    required String value,
    required int? existingId,
    required Future<Map<String, dynamic>> Function() fetchList,
    required Future<Map<String, dynamic>> Function(String) create,
    required Future<Map<String, dynamic>> Function(int, String) update,
    required String label,
  }) async {
    final v = value.trim();
    if (v.isEmpty) return null;
    try {
      int? id = existingId;
      if (id == null) {
        final list = await fetchList();
        final data = list['data'];
        if (data is List && data.isNotEmpty && data.first is Map) {
          id = _msgId((data.first as Map)['id']);
        }
      }
      final resp = id != null ? await update(id, v) : await create(v);
      // 422 возвращается телом без исключения — проверяем success.
      if (resp['success'] == false) {
        return resp['message']?.toString() ?? '$label: ошибка сохранения';
      }
      log.d('✅ $label сохранён на сервере');
      return null;
    } catch (e) {
      log.d('❌ Ошибка сохранения $label: $e');
      return '$label: не удалось сохранить';
    }
  }

  /// ✅ Восстанавливает данные контактов из локального хранилища и ProfileBloc
  /// Вызывается когда кеш ещё актуален (чтобы не показывать skeleton loader)
  void _restoreDataFromCache() {
    try {
      // Получаем профиль из ProfileBloc (уже загружен)
      final profileState = context.read<ProfileBloc>().state;
      
      // ✅ name → «Контактное лицо», lastName → «Фамилия».
      // Приоритет: ProfileBloc (данные с бэка /me) → сохранённые в Hive значения.
      final firstName = profileState is ProfileLoaded
          ? profileState.name
          : (UserService.getLocal('name') as String? ?? '');
      final lastName = profileState is ProfileLoaded
          ? profileState.lastName
          : (UserService.getLocal('lastName') as String? ?? '');
      final email = profileState is ProfileLoaded ? profileState.email : '';
      final phone = profileState is ProfileLoaded ? profileState.phone : '';
      final about = profileState is ProfileLoaded
          ? (profileState.about ?? '')
          : (UserService.getLocal('about') as String? ?? '');

      // Загружаем сохраненные данные из Hive
      final region = UserService.getLocal('region') as String? ?? '';
      final city = UserService.getLocal('city') as String? ?? '';
      final telegram = UserService.getLocal('telegram') as String? ?? '';
      final whatsapp = UserService.getLocal('whatsapp') as String? ?? '';
      final phone1Cache = UserService.getLocal('phone1') as String? ?? '';
      final phone2Cache = UserService.getLocal('phone2') as String? ?? '';

      setState(() {
        _nameController.text = firstName;
        _lastNameController.text = lastName;
        _emailController.text = email;
        _aboutController.text = about;
        _phone1Controller.text = phone.isEmpty
            ? (phone1Cache.isEmpty ? '' : (phone1Cache.startsWith('+') ? phone1Cache : '+$phone1Cache'))
            : (phone.startsWith('+') ? phone : '+$phone');
        _phone2Controller.text = phone2Cache.isEmpty ? '' : (phone2Cache.startsWith('+') ? phone2Cache : '+$phone2Cache');
        // Телеграм/MAX грузятся с бэка в _loadMessengers() — не из Hive.
        // ignore: unnecessary_statements
        telegram;
        _whatsappController.text = whatsapp;
        
        // Восстанавливаем выбранные область и город
        if (region.isNotEmpty) {
          _selectedRegion = {region};
          // Находим ID выбранного региона
          final regionIndex = _regions.indexWhere((r) => r['name'] == region);
          if (regionIndex >= 0) {
            _selectedRegionId = _regions[regionIndex]['id'] as int?;
          }
        }
        if (city.isNotEmpty) {
          _selectedCity = {city};
          // Находим ID выбранного города
          final cityIndex = _lastCitiesSearchResults.keys.toList().indexOf(city);
          if (cityIndex >= 0) {
            _selectedCityId = _lastCitiesSearchResults[city];
          }
        }
        
        _isLoading = false;
      });
    } catch (e) {
      // Если восстановление не удалось, загружаем свежие данные
      // ignore: avoid_print
      // log.d('❌ Error restoring from cache: $e');
      _loadContactData();
      ScreenCacheManager.contactDataLastLoadTime = DateTime.now();
    }
  }

  /// 💾 Проверяет нужно ли обновлять кеш контактных данных
  bool _shouldRefreshContactData() {
    if (ScreenCacheManager.contactDataLastLoadTime == null) return true;
    return DateTime.now().difference(ScreenCacheManager.contactDataLastLoadTime!).inMinutes >=
        _contactDataCacheDuration.inMinutes;
  }

  Future<void> _loadContactData({int retryCount = 0}) async {
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

      // Загружаем телефоны и почты
      final phonesResponse = await ContactService.getPhones(token: token);
      final emailsResponse = await ContactService.getEmails(token: token);

      // ✅ Проверяем что widget еще mounted перед использованием Context
      if (!mounted) return;

      // ✅ Берём имя и фамилию НАПРЯМУЮ С БЭКА (GET /me → MeResource).
      // Бэкенд хранит их отдельными полями (RegisterController: name / last_name),
      // а UserProfile маппит их как name (@JsonKey 'name') и lastName (@JsonKey 'last_name'):
      //   profile.name     → поле «Контактное лицо» (имя при регистрации)
      //   profile.lastName → поле «Фамилия»        (фамилия при регистрации)
      // Так значения не зависят от того, загружен ли ProfileBloc.
      String firstName = '';
      var lastName = '';
      String email = '';
      String phone = '';
      String about = '';
      try {
        final profile = await UserService.getProfile(token: token);
        firstName = profile.name;
        lastName = profile.lastName;
        email = profile.email;
        phone = profile.phone ?? '';
        about = profile.about ?? '';
      } catch (e) {
        // Фолбэк: если /me недоступен — берём из ProfileBloc, затем из Hive.
        log.d('⚠️ Не удалось получить профиль с бэка, берём из кеша: $e');
        if (!mounted) return;
        final profileState = context.read<ProfileBloc>().state;
        firstName = profileState is ProfileLoaded
            ? profileState.name
            : (UserService.getLocal('name') as String? ?? '');
        lastName = profileState is ProfileLoaded
            ? profileState.lastName
            : (UserService.getLocal('lastName') as String? ?? '');
        email = profileState is ProfileLoaded ? profileState.email : '';
        phone = profileState is ProfileLoaded ? profileState.phone : '';
        about = profileState is ProfileLoaded
            ? (profileState.about ?? '')
            : (UserService.getLocal('about') as String? ?? '');
      }

      // Получаем область и город из локального хранилища
      var region = UserService.getLocal('region') as String? ?? '';
      var city = UserService.getLocal('city') as String? ?? '';

      // Если данные не найдены в хранилище, пытаемся получить из первого объявления пользователя
      if (region.isEmpty || city.isEmpty) {
        try {
          // Получаем список объявлений пользователя через API endpoint /me/adverts
          // statusId: 1 = активные объявления
          final myAdvertsResponse = await MyAdvertsService.getMyAdverts(
            statusId: 1,
            limit: 1,
            token: token,
          );

          // ignore: avoid_print
          // log.d('📢 MyAdvertsResponse:');
          // ignore: avoid_print
          // log.d('   Data count: ${myAdvertsResponse.data.length}');

          if (myAdvertsResponse.data.isNotEmpty) {
            final firstAdvert = myAdvertsResponse.data.first;
            // ignore: avoid_print
            log.d(
              '   First advert: name="${firstAdvert.name}", address="${firstAdvert.address}"',
            );

            // Извлекаем адрес из объявления
            final advertAddress = firstAdvert.address ?? '';

            // Парсим адрес в формате: "г. Мариуполь, ул. Артёма, 96"
            // или "г. Мариуполь, пр. Красный Азовец, 120"
            if (advertAddress.isNotEmpty) {
              final addressParts = advertAddress
                  .split(',')
                  .map((s) => s.trim())
                  .toList();
              // ignore: avoid_print
              // log.d('   Address parts: $addressParts');

              if (addressParts.isNotEmpty) {
                // Первая часть содержит префикс "г." (город) и название города
                // Пример: "г. Мариуполь" → нужно извлечь "Мариуполь"
                final firstPart = addressParts[0];
                // Убираем префиксы типа "г. ", "р. ", "м. " и т.д.
                final cityName = firstPart.replaceAll(RegExp(r'^[а-яё]\.\s+'), '');
                city = cityName;
                
                // Для области, нужно использовать AddressService для поиска города
                // чтобы получить main_region (область)
                try {
                  // Ищем город через AddressService для получения основного региона
                  final addressResponse = await AddressService.searchAddresses(
                    query: city,
                    types: ['city'],
                    token: token,
                  );
                  
                  if (addressResponse.data.isNotEmpty) {
                    // Находим точное совпадение по названию города
                    final cityAddress = addressResponse.data.firstWhere(
                      (addr) => addr.city?.name?.toLowerCase() == city.toLowerCase(),
                      orElse: () => addressResponse.data.first,
                    );
                    
                    // Берём основной регион (область)
                    if (cityAddress.main_region != null) {
                      region = cityAddress.main_region!.name;
                      // ignore: avoid_print
                      log.d('   ✅ Extracted - region: "$region" (main_region), city: "$city"');
                    } else if (cityAddress.region != null) {
                      // Если main_region не доступен, используем region
                      region = cityAddress.region!.name;
                      // ignore: avoid_print
                      log.d('   ✅ Extracted - region: "$region" (region), city: "$city"');
                    } else {
                      // ignore: avoid_print
                      log.d('   ⚠️ No region found for city: "$city"');
                    }
                  }
                } catch (e) {
                  // Если поиск через AddressService не удался, оставляем пустую область
                  // ignore: avoid_print
                  log.d('   ⚠️ Failed to search region for city "$city": $e');
                }
              }
            } else {
              // ignore: avoid_print
              // log.d('   ❌ Address is empty or null');
            }
          } else {
            // ignore: avoid_print
            // log.d('   ❌ No adverts found for user');
          }
        } catch (e) {
          // Если не удаётся получить из объявления, используем сохранённые или пустые значения
          // ignore: avoid_print
          log.d('❌ Error loading address from user advert: $e');
        }
      }

      // log.d('🔍 DEBUG contact_data_screen._loadContactData():');
      // log.d('   - profileState.name = "$name"');
      // log.d('   - profileState.email = "$email"');
      // log.d('   - profileState.phone = "$phone"');

      // Загружаем сохраненные данные из Hive
      final telegram = UserService.getLocal('telegram') as String? ?? '';
      final whatsapp = UserService.getLocal('whatsapp') as String? ?? '';
      
      // 🆕 Восстанавливаем ID региона и города из Hive
      final savedRegionIdStr = UserService.getLocal('regionId') as String? ?? '';
      final savedCityIdStr = UserService.getLocal('cityId') as String? ?? '';
      final savedRegionId = savedRegionIdStr.isNotEmpty ? int.tryParse(savedRegionIdStr) : null;
      final savedCityId = savedCityIdStr.isNotEmpty ? int.tryParse(savedCityIdStr) : null;

      // Точный адрес (улица/дом) — восстанавливаем из локального хранилища.
      final savedStreet = UserService.getLocal('street') as String? ?? '';
      final savedStreetIdStr = UserService.getLocal('streetId') as String? ?? '';
      final savedStreetId = savedStreetIdStr.isNotEmpty ? int.tryParse(savedStreetIdStr) : null;
      final savedBuilding = UserService.getLocal('building') as String? ?? '';
      final savedBuildingIdStr = UserService.getLocal('buildingId') as String? ?? '';
      final savedBuildingId = savedBuildingIdStr.isNotEmpty ? int.tryParse(savedBuildingIdStr) : null;

      // Извлекаем ID и значения контактов
      String emailValue = email;
      if (emailsResponse.data.isNotEmpty) {
        _emailId = emailsResponse.data.first.id;
        if (emailsResponse.data.first.email.isNotEmpty) {
          emailValue = emailsResponse.data.first.email;
        }
      }

      String phone1 = phone;
      if (phonesResponse.data.isNotEmpty) {
        _phone1Id = phonesResponse.data.first.id;
        if (phonesResponse.data.first.phone.isNotEmpty) {
          phone1 = phonesResponse.data.first.phone;
        }
        // Ensure phone is in correct format with +
        if (!phone1.startsWith('+')) {
          phone1 = '+$phone1';
        }
      }

      String phone2 = '';
      if (phonesResponse.data.length > 1) {
        _phone2Id = phonesResponse.data[1].id;
        phone2 = phonesResponse.data[1].phone;
        // Ensure phone is in correct format with +
        if (!phone2.startsWith('+')) {
          phone2 = '+$phone2';
        }
      }

      setState(() {
        _nameController.text = firstName;
        _lastNameController.text = lastName;
        _emailController.text = emailValue;
        _aboutController.text = about;
        _phone1Controller.text = phone1;
        _phone2Controller.text = phone2;
        // Телеграм/MAX грузятся с бэка в _loadMessengers() — не из Hive.
        // ignore: unnecessary_statements
        telegram;
        _whatsappController.text = whatsapp;
        
        // Восстанавливаем выбранные область и город
        if (region.isNotEmpty) {
          _selectedRegion = {region};
          // 🆕 Используем сохраненный ID если доступен, иначе ищем
          if (savedRegionId != null) {
            _selectedRegionId = savedRegionId;
          } else {
            final regionIndex = _regions.indexWhere((r) => r['name'] == region);
            if (regionIndex >= 0) {
              _selectedRegionId = _regions[regionIndex]['id'] as int?;
            }
          }
        }
        if (city.isNotEmpty) {
          _selectedCity = {city};
          // 🆕 Используем сохраненный ID если доступен, иначе ищем
          if (savedCityId != null) {
            _selectedCityId = savedCityId;
          } else {
            final cityIndex = _lastCitiesSearchResults.keys.toList().indexOf(city);
            if (cityIndex >= 0) {
              _selectedCityId = _lastCitiesSearchResults[city];
            }
          }
        }

        // Восстанавливаем улицу и дом (необязательный точный адрес). Кладём
        // выбранное значение и по одной записи в списки, чтобы поле показывало
        // сохранённый выбор без повторной загрузки.
        if (savedStreet.isNotEmpty && savedStreetId != null) {
          _selectedStreet = {savedStreet};
          _selectedStreetId = savedStreetId;
          _streets = [
            {'name': savedStreet, 'id': savedStreetId},
          ];
          _lastStreetsSearchResults[savedStreet] = savedStreetId;
          if (savedBuilding.isNotEmpty && savedBuildingId != null) {
            _selectedBuilding = {savedBuilding};
            _selectedBuildingId = savedBuildingId;
            _buildings = [
              {'name': savedBuilding, 'id': savedBuildingId},
            ];
          }
        }

        _isLoading = false;
      });

      // 🆕 Загружаем города для выбранного региона если регион выбран
      if (_selectedRegionId != null && _cities.isEmpty) {
        await _loadCitiesForSelectedRegion();
      }

      // 💾 Сохраняем данные в локальное хранилище для кеширования
      await UserService.saveLocal('name', firstName);
      await UserService.saveLocal('lastName', lastName);
      await UserService.saveLocal('about', about);
      await UserService.saveLocal('phone1', phone1);
      await UserService.saveLocal('phone2', phone2);
      await UserService.saveLocal('region', region);
      await UserService.saveLocal('city', city);
      
      // ✅ ВАЖНО: Сохраняем также ID региона и города для dynamic_filter
      // Это нужно чтобы при создании объявления не было ошибки валидации
      if (region.isNotEmpty) {
        final regionIndex = _regions.indexWhere((r) => r['name'] == region);
        if (regionIndex >= 0) {
          final regionId = _regions[regionIndex]['id'] as int?;
          await UserService.saveLocal('regionId', regionId?.toString() ?? '');
        }
      }
      
      if (city.isNotEmpty) {
        final cityIndex = _lastCitiesSearchResults.keys.toList().indexOf(city);
        if (cityIndex >= 0) {
          final cityId = _lastCitiesSearchResults[city];
          await UserService.saveLocal('cityId', cityId?.toString() ?? '');
        }
      }
      // ignore: avoid_print
      log.d(
        '✅ ContactDataScreen: данные сохранены в локальное хранилище для кеша',
      );
    } catch (e) {
      // ♻️ RETRY ЛОГИКА: Повторяем попытку загрузки при сбое
      const maxRetries = 3;
      const retryDelayMs = 2000; // 2 сек между попытками
      
      if (retryCount < maxRetries) {
        // ignore: avoid_print
        log.d(
          '⚠️ ContactDataScreen: Сбой загрузки (попытка ${retryCount + 1}/$maxRetries), '
          'повторяем через ${retryDelayMs}ms...',
        );
        // Ждем перед повторной попыткой
        await Future.delayed(Duration(milliseconds: retryDelayMs));
        // Повторяем рекурсивно
        await _loadContactData(retryCount: retryCount + 1);
      } else {
        // Исчерпаны попытки - показываем ошибку
        setState(() {
          _errorMessage = 'Ошибка загрузки: ${e.toString()}';
          _isLoading = false;
        });
        // ignore: avoid_print
        log.d('❌ ContactDataScreen: Сбой после $maxRetries попыток: $e');
      }
    }
  }

  Future<void> _saveContactData() async {
    // 🚫 Запрет ссылок в поле «Описание компании» (в т.ч. если ссылка пришла
    // из старых данных: форматтер не ловит программную подстановку текста).
    if (_hasLink(_aboutController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('В поле «Описание компании» нельзя добавлять ссылки'),
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

      // ✅ Сохраняем значения из контроллеров перед сохранением на сервер
      final updatedName = _nameController.text;
      final updatedLastName = _lastNameController.text;
      final updatedEmail = _emailController.text;
      final updatedPhone1 = _phone1Controller.text;
      final updatedPhone2 = _phone2Controller.text;
      final updatedAbout = _aboutController.text;

      // Обновляем имя на API (если оно изменилось)
      if (updatedName.isNotEmpty || updatedLastName.isNotEmpty) {
        try {
          log.d('👤 Updating user name: "$updatedName" "$updatedLastName"');
          await UserService.updateName(
            name: updatedName,
            lastName: updatedLastName,
            token: token,
          );
          log.d('✅ Имя и фамилия обновлены на сервере');
        } catch (e) {
          log.d('❌ Ошибка обновления имени: $e');
        }
      }

      // Обновляем «Описание компании» на API (та же кнопка «Сохранить»).
      // Отправляем ВСЕГДА, в том числе пустую строку: это позволяет очистить
      // описание (бэкенд принимает пустое/NULL). Раньше при пустом значении
      // запрос пропускался, и старый текст возвращался с сервера при перезагрузке.
      try {
        await UserService.updateAbout(about: updatedAbout, token: token);
        log.d('✅ «Описание компании» обновлено на сервере');
      } catch (e) {
        log.d('❌ Ошибка обновления «Описание компании»: $e');
      }

      // Сохраняем в локальное хранилище
      await UserService.saveLocal('name', updatedName);
      await UserService.saveLocal('lastName', updatedLastName);
      await UserService.saveLocal('about', updatedAbout);
      await UserService.saveLocal('phone1', updatedPhone1);
      await UserService.saveLocal('phone2', updatedPhone2);
      await UserService.saveLocal('telegram', _telegramController.text);
      await UserService.saveLocal('whatsapp', _whatsappController.text);
      await UserService.saveLocal('region', _selectedRegion.isEmpty ? '' : _selectedRegion.first);
      await UserService.saveLocal('city', _selectedCity.isEmpty ? '' : _selectedCity.first);
      
      // ✅ ВАЖНО: Сохраняем также ID региона и города для dynamic_filter
      if (_selectedRegionId != null) {
        await UserService.saveLocal('regionId', _selectedRegionId.toString());
      }
      if (_selectedCityId != null) {
        await UserService.saveLocal('cityId', _selectedCityId.toString());
      }
      
      log.d('✅ Локальные данные сохранены в Hive');

      // Обновляем или добавляем email
      if (updatedEmail.isNotEmpty) {
        try {
          if (_emailId != null) {
            await ContactService.updateEmail(
              id: _emailId!,
              email: updatedEmail,
              token: token,
            );
            log.d('✅ Email обновлен');
          } else {
            await ContactService.addEmail(
              email: updatedEmail,
              token: token,
            );
            log.d('✅ Email добавлен');
          }
        } catch (e) {
          log.d('❌ Ошибка обновления email: $e');
        }
      }

      // Обновляем или добавляем первый телефон
      if (updatedPhone1.isNotEmpty) {
        try {
          if (_phone1Id != null) {
            await ContactService.updatePhone(
              id: _phone1Id!,
              phone: updatedPhone1,
              token: token,
            );
            log.d('✅ Телефон 1 обновлен (список сохраненных)');
          } else {
            await ContactService.addPhone(
              phone: updatedPhone1,
              token: token,
            );
            log.d('✅ Телефон 1 добавлен (список сохраненных)');
          }
          
          // ✅ ВАЖНО: Обновляем основной номер телефона профиля
          // Используем эндпоинт PUT /me/settings/phone (отдельно от списка телефонов)
          try {
            await ContactService.updateMainPhone(
              phone: updatedPhone1,
              token: token,
            );
            log.d('✅ Основной телефон профиля обновлен');
          } catch (e) {
            log.d('⚠️ Ошибка обновления основного телефона профиля: $e');
          }
        } catch (e) {
          log.d('❌ Ошибка обновления телефона 1: $e');
        }
      }

      // Обновляем или добавляем второй телефон
      if (updatedPhone2.isNotEmpty) {
        try {
          if (_phone2Id != null) {
            await ContactService.updatePhone(
              id: _phone2Id!,
              phone: updatedPhone2,
              token: token,
            );
            log.d('✅ Телефон 2 обновлен');
          } else {
            await ContactService.addPhone(
              phone: updatedPhone2,
              token: token,
            );
            log.d('✅ Телефон 2 добавлен');
          }
        } catch (e) {
          log.d('❌ Ошибка обновления телефона 2: $e');
        }
      }

      // Адрес: шлём выбранный город, бэк выведет подрегион и область.
      // Улицу и дом (необязательные) передаём, только если они выбраны.
      if (_selectedCityId != null) {
        try {
          final resp = await UserService.updateAddress(
            cityId: _selectedCityId!,
            streetId: _selectedStreetId,
            buildingId: _selectedBuildingId,
            token: token,
          );
          if (resp['success'] == false) {
            log.d('⚠️ Адрес не сохранён: ${resp['message']}');
          } else {
            log.d(
              '✅ Адрес сохранён (city_id=$_selectedCityId, '
              'street_id=$_selectedStreetId, building_id=$_selectedBuildingId)',
            );
          }
        } catch (e) {
          log.d('❌ Ошибка сохранения адреса: $e');
        }
      }

      // Мессенджеры: Телеграм и MAX (create/update на бэке).
      final messengerErrors = <String>[];
      final tgError = await _saveMessenger(
        value: _telegramController.text,
        existingId: _telegramId,
        fetchList: () => ContactService.getTelegrams(token: token),
        create: (v) => ContactService.addTelegram(username: v, token: token),
        update: (id, v) =>
            ContactService.updateTelegram(id: id, username: v, token: token),
        label: 'Telegram',
      );
      if (tgError != null) messengerErrors.add(tgError);

      final maxError = await _saveMessenger(
        value: _maxController.text,
        existingId: _maxId,
        fetchList: () => ContactService.getMaxes(token: token),
        create: (v) => ContactService.addMax(username: v, token: token),
        update: (id, v) =>
            ContactService.updateMax(id: id, username: v, token: token),
        label: 'MAX',
      );
      if (maxError != null) messengerErrors.add(maxError);

      // ✅ КРИТИЧНО: Сначала обновляем ProfileBloc с forceRefresh = true
      // Это инвалидирует кеш и принудительно загружает свежие данные с сервера
      log.d('🔄 Принудительно обновляем ProfileBloc с forceRefresh...');
      if (mounted) {
        context.read<ProfileBloc>().add(LoadProfileEvent(forceRefresh: true));
      }

      // ⏳ Даем время для обновления ProfileBloc
      // forceRefresh требует больше времени (нужно загрузить с сервера)
      await Future.delayed(const Duration(milliseconds: 1500));

      // 🔄 Инвалидируем кеш экрана контактных данных
      ScreenCacheManager.contactDataLastLoadTime = null;
      log.d('🔄 Инвалидирован кеш contactDataLastLoadTime');

      // ✅ ВАЖНО: Явно получаем СВЕЖИЙ профиль с сервера напрямую (без ProfileBloc кеша)
      // Это гарантирует что получим самые актуальные имя/фамилию
      log.d('🔎 Загружаем актуальные данные профиля с сервера...');
      try {
        if (!mounted) return;

        final token = TokenService.currentToken;
        if (token != null) {
          // 📲 Получаем СВЕЖИЙ профиль напрямую с сервера (UserService не использует кеш)
          final freshProfile = await UserService.getProfile(token: token);
          final phonesResponse = await ContactService.getPhones(token: token);
          final emailsResponse = await ContactService.getEmails(token: token);

          // Сохраняем свежий профиль в локальное хранилище для синхронизации
          await UserService.saveLocal('name', freshProfile.name);
          await UserService.saveLocal('lastName', freshProfile.lastName);
          await UserService.saveLocal('about', freshProfile.about ?? '');
          await UserService.saveLocal('email', freshProfile.email);
          await UserService.saveLocal('phone', freshProfile.phone);

          // Обновляем текстовые поля с САМЫМИ СВЕЖИМИ данными
          setState(() {
            _nameController.text = freshProfile.name;
            _lastNameController.text = freshProfile.lastName;
            _aboutController.text = freshProfile.about ?? '';

            // Обновляем остальные поля
            String emailValue = freshProfile.email;
            if (emailsResponse.data.isNotEmpty) {
              _emailId = emailsResponse.data.first.id;
              if (emailsResponse.data.first.email.isNotEmpty) {
                emailValue = emailsResponse.data.first.email;
              }
            }
            _emailController.text = emailValue;

            String phone1 = freshProfile.phone ?? '';
            if (phonesResponse.data.isNotEmpty) {
              _phone1Id = phonesResponse.data.first.id;
              if (phonesResponse.data.first.phone.isNotEmpty) {
                phone1 = phonesResponse.data.first.phone;
              }
              if (!phone1.startsWith('+')) {
                phone1 = '+$phone1';
              }
            }
            _phone1Controller.text = phone1;

            String phone2 = '';
            if (phonesResponse.data.length > 1) {
              _phone2Id = phonesResponse.data[1].id;
              phone2 = phonesResponse.data[1].phone;
              if (!phone2.startsWith('+')) {
                phone2 = '+$phone2';
              }
            }
            _phone2Controller.text = phone2;

            // Обновляем локальные данные из Hive
            final telegram = UserService.getLocal('telegram') as String? ?? '';
            final whatsapp = UserService.getLocal('whatsapp') as String? ?? '';
            // Телеграм/MAX грузятся с бэка в _loadMessengers() — не из Hive.
        // ignore: unnecessary_statements
        telegram;
            _whatsappController.text = whatsapp;
          });

          log.d('✅ Имя: "${freshProfile.name}", Фамилия: "${freshProfile.lastName}" - загружены с сервера');
          log.d('✅ Контактные данные обновлены в UI реал-тайм');
        }
      } catch (e) {
        log.d('❗ Ошибка при загрузке свежих данных: $e');
      }

      // ✅ Убеждаемся что UI обновлен
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
        log.d('✅ UI полностью обновлен');

        // 🔄 Инвалидируем кеш объявлений
        final cacheService = AppCacheService();
        cacheService.invalidate(CacheKeys.listingsData);
        log.d('✅ Кеш объявлений инвалидирован');

        // 📲 С задержкой обновляем ListingsBloc
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            context.read<ListingsBloc>().add(LoadListingsEvent(forceRefresh: true));
            log.d('🔄 ListingsBloc перезагружен');
          }
        });

        // Обновляем id телеграма/MAX (после create id меняется).
        _loadMessengers();

        if (messengerErrors.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Контактные данные сохранены и обновлены'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // Часть данных сохранена, но мессенджеры не прошли валидацию.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Сохранено, но: ${messengerErrors.join('; ')}',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка сохранения: ${e.toString()}';
        _isLoading = false;
      });
      log.d('❌ Ошибка в _saveContactData: $e');
    }
  }

  /// Нагружаем области из API
  Future<void> _loadRegions() async {
    try {
      final token = TokenService.currentToken;
      final regions = await ApiService.getRegions(token: token);
      
      if (mounted) {
        setState(() {
          _regions = regions;
        });
      }
      log.d('✅ Loaded ${regions.length} regions');
    } catch (e) {
      log.d('❌ Error loading regions: $e');
      // Повторяем попытку через 3 секунды
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _loadRegions();
      });
    }
  }

  /// Нагружаем города для выбранной области
  Future<void> _loadCitiesForSelectedRegion() async {
    if (_selectedRegionId == null) return;

    // Используем имя региона как поисковый запрос (если есть и оно >= 3 символов).
    // Если короче, не делаем запрос: пользователь увидит пустой список в диалоге
    // и сам введёт нужный город. Это лучше чем падать на старое 'по' (которое
    // теперь блокируется минимальной длиной q=3 на стороне AddressService).
    String? searchQuery;
    if (_selectedRegion.isNotEmpty) {
      final regionName = _selectedRegion.first.trim();
      if (regionName.length >= 3) {
        searchQuery = regionName.length > 50
            ? regionName.substring(0, 50)
            : regionName;
      }
    }

    if (searchQuery == null) {
      log.d('ℹ️ contact_data: имя региона короткое, пропускаем предзагрузку городов');
      return;
    }

    try {
      final token = TokenService.currentToken;

      final response = await AddressService.searchAddresses(
        query: searchQuery,
        token: token,
        types: ['city'],
        filters: _selectedRegionId != null
            ? {'main_region_id': _selectedRegionId}
            : null,
      );

      final uniqueCities = <String, int>{};
      for (final result in response.data) {
        if (result.main_region?.id == _selectedRegionId &&
            result.city != null) {
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
            (a, b) => (a['name'] as String).compareTo(b['name'] as String),
          );
        });
        log.d('✅ Auto-loaded ${_cities.length} cities');
      }
    } catch (e) {
      log.d('❌ Error auto-loading cities: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    _telegramController.dispose();
    _whatsappController.dispose();
    _maxController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: BlocListener<ProfileBloc, ProfileState>(
        // 👤 Как только профиль загружен с бэка (/me) — заполняем поля.
        //   name     → «Контактное лицо»
        //   lastName → «Фамилия»
        // Заполняем только пустые поля, чтобы не затирать правки пользователя.
        listener: (context, profileState) {
          if (profileState is ProfileLoaded) {
            if (_nameController.text.trim().isEmpty &&
                profileState.name.trim().isNotEmpty) {
              _nameController.text = profileState.name;
            }
            if (_lastNameController.text.trim().isEmpty &&
                profileState.lastName.trim().isNotEmpty) {
              _lastNameController.text = profileState.lastName;
            }
            if (_aboutController.text.trim().isEmpty &&
                (profileState.about ?? '').trim().isNotEmpty) {
              _aboutController.text = profileState.about!;
            }
          }
        },
        child: BlocListener<ConnectivityBloc, ConnectivityState>(
        listener: (context, connectivityState) {
          // Когда интернет восстановлен - перезагружаем контактные данные
          if (connectivityState is ConnectedState) {
            // Очищаем предыдущую ошибку сразу
            setState(() {
              _errorMessage = null;
            });
            
            // ⏳ Добавляем задержку для стабилизации соединения
            // перед попыткой API запросов (обычно достаточно 500ms)
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _loadContactData();
                ScreenCacheManager.contactDataLastLoadTime = DateTime.now();
              }
            });
          }
        },
        child: BlocBuilder<ConnectivityBloc, ConnectivityState>(
          builder: (context, connectivityState) {
            // Показываем экран отсутствия интернета
            if (connectivityState is DisconnectedState) {
              return NoInternetScreen(
                onRetry: () {
                  context.read<ConnectivityBloc>().add(
                    const CheckConnectivityEvent(),
                  );
                },
              );
            }

            // Показываем обычный контент
            return SafeArea(
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

                    // ───── Back row ─────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(
                              Icons.arrow_back_ios,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Адаптивный заголовок: занимает всё доступное место,
                          // если текст помещается — размер 18, если нет —
                          // FittedBox(scaleDown) автоматически уменьшает.
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: const Text(
                                'Контактные данные пользователя',
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
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ───── Description ─────
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 25),
                      child: Text(
                        'На этой странице, вы указываете вашу личную информацию '
                        'которая будет видна в объявлениях',
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
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),

                    if (_isLoading)
                      // 🧨 ОПТИМИЗАЦИЯ: Skeleton loader вместо простого индикатора загрузки
                      // Показывает структуру экрана заранее для лучшего UX
                      _buildSkeletonFields()
                    else ...[
                      // ───── Fields ─────

                      // ───── Описание компании (как поле «Название компании») ─────
                      _label('Описание компании'),
                      _field(
                        _aboutController,
                        'Опишите вашу компанию',
                        inputFormatters: [_NoLinksInputFormatter()],
                      ),

                      _label('Название компании'),
                      _field(_nameController, 'Введите название компании'),

                      _label('Фамилия', note: '(Скрыта от пользователей)'),
                      _field(_lastNameController, 'Введите фамилию'),

                      _label('Ваша область'),
                      _buildRegionDropdown(),

                      _label('Ваш город'),
                      _buildCityDropdown(),

                      _label('Улица', note: '(Виден в вашем магазине)'),
                      _buildStreetDropdown(),

                      _label('Номер дома', note: '(Ваш физический адрес компании)'),
                      _buildBuildingDropdown(),

                      _label('Электронная почта', note: '(Скрыта от пользователей)'),
                      _field(_emailController, 'Введите вашу почту'),

                      _label('Номер телефона 1'),
                      _field(_phone1Controller, 'Введите номер телефона'),

                      _label('Номер телефона 2'),
                      _field(_phone2Controller, 'Введите'),

                      _label('Ссылка на ваш чат в Telegram'),
                      _field(_telegramController, '@username или t.me/username'),

                      _label('Ссылка на ваш чат в Max'),
                      _field(_maxController, '@username или max.ru/username'),

                      // _label('Ссылка на ваш whatsapp'),
                      // _field(_whatsappController, ''),
                      const SizedBox(height: 24),

                      // ───── Save button ─────
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
                            onPressed: _isLoading ? null : _saveContactData,
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
              );
            },
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

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

  /// 🧨 Skeleton loader для экрана контактных данных
  /// Показывает структуру экрана во время загрузки для лучшего UX
  Widget _buildSkeletonFields() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2F4456),
      highlightColor: const Color(0xFF3F5567),
      child: SingleChildScrollView(
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

            // Фамилия
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

            // Whatsapp
            _skeletonLabel(),
            _skeletonField(),
            const SizedBox(height: 24),

            // Кнопка сохранения
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2F4456),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Skeleton для лейбла (текст поля)
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

  /// Skeleton для поля ввода
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

  /// ───── Выпадающий список для выбора области ─────
  Widget _buildRegionDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: GestureDetector(
        onTap: () {
          if (_regions.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Области загружаются...'),
              ),
            );
            return;
          }
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return SelectionDialog(
                title: 'Выберите область',
                options: _regions
                    .map((r) => r['name'] as String)
                    .toList(),
                selectedOptions: _selectedRegion,
                allowMultipleSelection: false,
                onSelectionChanged: (Set<String> selected) {
                  if (selected.isNotEmpty) {
                    final selectedRegionName = selected.first;
                    final regionIndex = _regions.indexWhere(
                      (r) => r['name'] == selectedRegionName,
                    );
                    int? regionId;
                    if (regionIndex >= 0) {
                      regionId = _regions[regionIndex]['id'] as int?;
                    }
                    setState(() {
                      _selectedRegion = selected;
                      _selectedRegionId = regionId;
                      // Очищаем город при смене региона
                      _selectedCity.clear();
                      _selectedCityId = null;
                      _cities.clear();
                      // Точный адрес привязан к городу — сбрасываем улицу и дом.
                      _selectedStreet.clear();
                      _selectedStreetId = null;
                      _streets.clear();
                      _selectedBuilding.clear();
                      _selectedBuildingId = null;
                      _buildings.clear();
                      UserService.saveLocal('street', '');
                      UserService.saveLocal('streetId', '');
                      UserService.saveLocal('building', '');
                      UserService.saveLocal('buildingId', '');
                      // 🆕 Сохраняем регион и его ID в локальное хранилище сразу при выборе
                      UserService.saveLocal('region', selectedRegionName);
                      if (regionId != null) {
                        UserService.saveLocal('regionId', regionId.toString());
                      }
                      // Очищаем сохраненные город/cityId при смене региона
                      UserService.saveLocal('city', '');
                      UserService.saveLocal('cityId', '');
                    });

                    // Загружаем города для выбранного региона
                    if (regionId != null) {
                      _loadCitiesForSelectedRegion();
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
                    color: _selectedRegion.isEmpty ? Colors.white54 : Colors.white,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ───── Выпадающий список для выбора города ─────
  Widget _buildCityDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: GestureDetector(
        onTap: _selectedRegionId == null
            ? null
            : () {
                if (_cities.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Города не найдены'),
                    ),
                  );
                  return;
                }
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SelectionDialog(
                      title: 'Выберите город',
                      showSearchField: true,
                      options: _cities
                          .map((c) => c['name'] as String)
                          .toList(),
                      selectedOptions: _selectedCity,
                      allowMultipleSelection: false,
                      // 🆕 Callback для поиска городов через API
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
                              // 🆕 Кешируем ID города для быстрого доступа
                              _lastCitiesSearchResults[result.city!.name] = result.city!.id;
                            }
                          }
                          return cities.toList();
                        } catch (e) {
                          log.d('❌ Error searching cities: $e');
                          return [];
                        }
                      },
                      onSelectionChanged: (Set<String> selected) {
                        if (selected.isNotEmpty) {
                          final selectedCityName = selected.first;
                          int? cityId;
                          
                          // 🆕 Сначала проверяем кеш результатов поиска (для результатов API поиска)
                          if (_lastCitiesSearchResults.containsKey(selectedCityName)) {
                            cityId = _lastCitiesSearchResults[selectedCityName];
                            log.d('✅ City "$selectedCityName" found in search cache with ID: $cityId');
                          } else {
                            // Fallback: ищем в массиве _cities
                            final cityIndex = _cities.indexWhere(
                              (c) => c['name'] == selectedCityName,
                            );
                            if (cityIndex >= 0) {
                              cityId = _cities[cityIndex]['id'] as int?;
                              log.d('✅ City "$selectedCityName" found in _cities with ID: $cityId');
                            } else {
                              log.d('⚠️ City "$selectedCityName" NOT found - ID will be null!');
                            }
                          }
                          
                          setState(() {
                            _selectedCity = selected;
                            _selectedCityId = cityId;
                            // Смена города сбрасывает улицу и дом (они привязаны
                            // к городу/улице).
                            _selectedStreet.clear();
                            _selectedStreetId = null;
                            _streets.clear();
                            _selectedBuilding.clear();
                            _selectedBuildingId = null;
                            _buildings.clear();
                            UserService.saveLocal('street', '');
                            UserService.saveLocal('streetId', '');
                            UserService.saveLocal('building', '');
                            UserService.saveLocal('buildingId', '');
                            // 🆕 Сохраняем город и его ID в локальное хранилище сразу при выборе
                            UserService.saveLocal('city', selectedCityName);
                            if (cityId != null) {
                              UserService.saveLocal('cityId', cityId.toString());
                              log.d('💾 Saved to Hive - city: "$selectedCityName", cityId: $cityId');
                            } else {
                              log.d('⚠️ NOT saving cityId to Hive - it is null!');
                            }
                          });
                          // Предзагружаем улицы выбранного города, чтобы диалог
                          // "Улица" открывался со списком, а не пустым.
                          if (cityId != null) {
                            _loadStreetsForSelectedCity();
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
                  _selectedCity.isEmpty
                      ? 'Выберите город'
                      : _selectedCity.first,
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
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _selectedRegionId == null
                    ? Colors.white24
                    : Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ───── Выпадающий список для выбора улицы ─────
  /// Доступен только когда выбран город. Улицы ищутся по городу
  /// (types=['street'], filters[city_id]).
  Widget _buildStreetDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: GestureDetector(
        onTap: _selectedCityId == null
            ? null
            : () async {
                // Если улицы ещё не подгружены — тянем первую партию, чтобы
                // диалог не открывался пустым.
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
                      options: _streets
                          .map((s) => s['name'] as String)
                          .toList(),
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
                              (s) => s['name'] == selectedStreetName,
                            );
                            if (idx >= 0) {
                              streetId = _streets[idx]['id'] as int?;
                            }
                          }
                          setState(() {
                            _selectedStreet = selected;
                            _selectedStreetId = streetId;
                            // Смена улицы сбрасывает дом.
                            _selectedBuilding.clear();
                            _selectedBuildingId = null;
                            _buildings.clear();
                            UserService.saveLocal('street', selectedStreetName);
                            if (streetId != null) {
                              UserService.saveLocal(
                                'streetId',
                                streetId.toString(),
                              );
                            }
                            UserService.saveLocal('building', '');
                            UserService.saveLocal('buildingId', '');
                          });
                          // Предзагружаем дома выбранной улицы.
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
            color: _selectedCityId == null
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
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _selectedCityId == null
                    ? Colors.white24
                    : Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ───── Выпадающий список для выбора номера дома ─────
  /// Доступен только когда выбрана улица. Дома ищутся по улице
  /// (types=['building'], filters[street_id]).
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
                      content: Text('Дома по этой улице не найдены'),
                    ),
                  );
                  return;
                }
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SelectionDialog(
                      title: 'Выберите номер дома',
                      showSearchField: true,
                      options: _buildings
                          .map((b) => b['name'] as String)
                          .toList(),
                      selectedOptions: _selectedBuilding,
                      allowMultipleSelection: false,
                      onSelectionChanged: (Set<String> selected) {
                        if (selected.isNotEmpty) {
                          final selectedBuildingName = selected.first;
                          final idx = _buildings.indexWhere(
                            (b) => b['name'] == selectedBuildingName,
                          );
                          int? buildingId;
                          if (idx >= 0) {
                            buildingId = _buildings[idx]['id'] as int?;
                          }
                          setState(() {
                            _selectedBuilding = selected;
                            _selectedBuildingId = buildingId;
                            UserService.saveLocal(
                              'building',
                              selectedBuildingName,
                            );
                            if (buildingId != null) {
                              UserService.saveLocal(
                                'buildingId',
                                buildingId.toString(),
                              );
                            }
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
            color: _selectedStreetId == null
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
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _selectedStreetId == null
                    ? Colors.white24
                    : Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Поиск улиц через API по вводу пользователя (для диалога выбора улицы).
  /// Требует выбранного города и запрос от 3 символов (ограничение API).
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
      log.d('❌ Error searching streets: $e');
      return [];
    }
  }

  /// Предзагрузка списка улиц выбранного города (чтобы диалог не был пустым).
  Future<void> _loadStreetsForSelectedCity() async {
    if (_selectedCityId == null) return;
    // Как поисковый запрос берём имя города (>=3 символов).
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
      log.d('❌ Error loading streets: $e');
    }
  }

  /// Предзагрузка списка домов выбранной улицы.
  Future<void> _loadBuildingsForSelectedStreet() async {
    if (_selectedStreetId == null) return;
    // Номера домов короткие, поэтому как q берём имя улицы (>=3 символов),
    // фильтруя по street_id.
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
      log.d('❌ Error loading buildings: $e');
    }
  }
}