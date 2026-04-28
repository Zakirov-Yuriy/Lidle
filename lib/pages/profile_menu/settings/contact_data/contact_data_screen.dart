// ============================================================
// "Виджет: Экран контактных данных"
// ============================================================

import 'package:flutter/material.dart';
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

  bool _isLoading = false;
  String? _errorMessage;

  int? _phone1Id;
  int? _phone2Id;
  int? _emailId;

  // Переменные для выбора области и города
  Set<String> _selectedRegion = {};
  Set<String> _selectedCity = {};
  int? _selectedRegionId;
  int? _selectedCityId;
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _cities = [];
  Map<String, int> _lastCitiesSearchResults = {};

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
    // Загружаем регионы при инициализации
    _loadRegions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ignore: avoid_print
    // log.d('🔵 ContactDataScreen: didChangeDependencies() called');

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
  }

  /// ✅ Восстанавливает данные контактов из локального хранилища и ProfileBloc
  /// Вызывается когда кеш ещё актуален (чтобы не показывать skeleton loader)
  void _restoreDataFromCache() {
    try {
      // Получаем профиль из ProfileBloc (уже загружен)
      final profileState = context.read<ProfileBloc>().state;
      
      // ✅ ПРАВИЛЬНО: Используем отдельные поля name и lastName из ProfileLoaded
      // API уже возвращает их отдельно, не нужно парсить
      final firstName = profileState is ProfileLoaded ? profileState.name : '';
      final lastName = profileState is ProfileLoaded ? profileState.lastName : '';
      final email = profileState is ProfileLoaded ? profileState.email : '';
      final phone = profileState is ProfileLoaded ? profileState.phone : '';

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
        _phone1Controller.text = phone.isEmpty
            ? (phone1Cache.isEmpty ? '' : (phone1Cache.startsWith('+') ? phone1Cache : '+$phone1Cache'))
            : (phone.startsWith('+') ? phone : '+$phone');
        _phone2Controller.text = phone2Cache.isEmpty ? '' : (phone2Cache.startsWith('+') ? phone2Cache : '+$phone2Cache');
        _telegramController.text = telegram;
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

      // ✅ ПРАВИЛЬНО: Используем отдельные поля name и lastName из ProfileLoaded
      // API уже возвращает их отдельно в UserProfile с помощью @JsonKey(name: 'last_name')
      final profileState = context.read<ProfileBloc>().state;
      final firstName = profileState is ProfileLoaded ? profileState.name : '';
      var lastName = profileState is ProfileLoaded ? profileState.lastName : '';
      final email = profileState is ProfileLoaded ? profileState.email : '';
      final phone = profileState is ProfileLoaded ? profileState.phone : '';

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
        _phone1Controller.text = phone1;
        _phone2Controller.text = phone2;
        _telegramController.text = telegram;
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
        
        _isLoading = false;
      });

      // 🆕 Загружаем города для выбранного региона если регион выбран
      if (_selectedRegionId != null && _cities.isEmpty) {
        await _loadCitiesForSelectedRegion();
      }

      // 💾 Сохраняем данные в локальное хранилище для кеширования
      await UserService.saveLocal('name', firstName);
      await UserService.saveLocal('lastName', lastName);
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

      // Сохраняем в локальное хранилище
      await UserService.saveLocal('name', updatedName);
      await UserService.saveLocal('lastName', updatedLastName);
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
          await UserService.saveLocal('email', freshProfile.email);
          await UserService.saveLocal('phone', freshProfile.phone);

          // Обновляем текстовые поля с САМЫМИ СВЕЖИМИ данными
          setState(() {
            _nameController.text = freshProfile.name;
            _lastNameController.text = freshProfile.lastName;
            
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
            _telegramController.text = telegram;
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Контактные данные сохранены и обновлены'),
            duration: Duration(seconds: 2),
          ),
        );
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

    try {
      final token = TokenService.currentToken;
      String searchQuery = 'по'; // Default search term

      if (_selectedRegion.isNotEmpty) {
        final regionName = _selectedRegion.first;
        if (regionName.length >= 3) {
          searchQuery = regionName.length > 50
              ? regionName.substring(0, 50)
              : regionName;
        } else {
          searchQuery = regionName + '   '; // Pad to at least 3
        }
      }

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: BlocListener<ConnectivityBloc, ConnectivityState>(
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
                          const Text(
                            'Контактные данные',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
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
                      _label('Контактное лицо'),
                      _field(_nameController, 'Введите имя контактного лица'),

                      _label('Фамилия'),
                      _field(_lastNameController, 'Введите фамилию'),

                      _label('Ваша область'),
                      _buildRegionDropdown(),

                      _label('Ваш город'),
                      _buildCityDropdown(),

                      _label('Электронная почта'),
                      _field(_emailController, 'Введите вашу почту'),

                      _label('Номер телефона 1'),
                      _field(_phone1Controller, 'Введите номер телефона'),

                      _label('Номер телефона 2'),
                      _field(_phone2Controller, 'Введите'),

                      _label('Ссылка на ваш чат в Max'),
                      _field(_telegramController, 'Введите ссылку на чат'),

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
      
    );
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 14, 25, 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String hint) {
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
            // Контактное лицо
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
                            // 🆕 Сохраняем город и его ID в локальное хранилище сразу при выборе
                            UserService.saveLocal('city', selectedCityName);
                            if (cityId != null) {
                              UserService.saveLocal('cityId', cityId.toString());
                              log.d('💾 Saved to Hive - city: "$selectedCityName", cityId: $cityId');
                            } else {
                              log.d('⚠️ NOT saving cityId to Hive - it is null!');
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
}
