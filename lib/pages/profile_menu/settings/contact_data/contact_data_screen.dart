// ============================================================
// "Виджет: Экран контактных данных"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart'; // 🧨 Импорт для skeleton loader
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/services/contact_service.dart';
import 'package:lidle/services/user_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/services/my_adverts_service.dart';
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
  late TextEditingController _regionController;
  late TextEditingController _cityController;

  bool _isLoading = false;
  String? _errorMessage;

  int? _phone1Id;
  int? _phone2Id;
  int? _emailId;

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
    _regionController = TextEditingController();
    _cityController = TextEditingController();
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
        _regionController.text = region;
        _cityController.text = city;
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

            // Парсим область и город из адреса (формат может быть "область, город, улица")
            // Например: "Донецкая область, Мариуполь, ул. Артёма"
            if (advertAddress.isNotEmpty) {
              final addressParts = advertAddress
                  .split(',')
                  .map((s) => s.trim())
                  .toList();
              // ignore: avoid_print
              // log.d('   Address parts: $addressParts');

              if (addressParts.length >= 2) {
                region = addressParts[0]; // Первая часть - область
                city = addressParts[1]; // Вторая часть - город
                // ignore: avoid_print
                // log.d('   ✅ Extracted - region: "$region", city: "$city"');
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
        _regionController.text = region;
        _cityController.text = city;
        _isLoading = false;
      });

      // 💾 Сохраняем данные в локальное хранилище для кеширования
      await UserService.saveLocal('name', firstName);
      await UserService.saveLocal('lastName', lastName);
      await UserService.saveLocal('phone1', phone1);
      await UserService.saveLocal('phone2', phone2);
      await UserService.saveLocal('region', region);
      await UserService.saveLocal('city', city);
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

      // log.d('💾 Saving contact data...');
      // log.d('Token: ${token.substring(0, 20)}...');
      // log.d();

      // Обновляем имя на API (если оно изменилось)
      if (_nameController.text.isNotEmpty || _lastNameController.text.isNotEmpty) {
        try {
          // log.d('👤 Updating user name: ${_nameController.text} ${_lastNameController.text}');
          final firstName = _nameController.text;
          final lastName = _lastNameController.text;

          // log.d('🔍 DEBUG contact_data_screen._saveContactData():');
          // log.d();
          // log.d();

          await UserService.updateName(
            name: firstName,
            lastName: lastName,
            token: token,
          );
          // log.d('✅ User name updated successfully');
        } catch (e) {
          // log.d('❌ Name update error: $e');
        }
      }

      // Сохраняем в локальное хранилище
      await UserService.saveLocal('name', _nameController.text);
      await UserService.saveLocal('lastName', _lastNameController.text);
      await UserService.saveLocal('phone1', _phone1Controller.text);
      await UserService.saveLocal('phone2', _phone2Controller.text);
      await UserService.saveLocal('telegram', _telegramController.text);
      await UserService.saveLocal('whatsapp', _whatsappController.text);
      await UserService.saveLocal('region', _regionController.text);
      await UserService.saveLocal('city', _cityController.text);

      // Обновляем или добавляем email
      if (_emailController.text.isNotEmpty) {
        try {
          if (_emailId != null) {
            // log.d('📧 Updating email (ID: $_emailId)');
            // Обновляем существующий email
            await ContactService.updateEmail(
              id: _emailId!,
              email: _emailController.text,
              token: token,
            );
            // log.d('✅ Email updated successfully');
          } else {
            // log.d('📧 Adding new email');
            // Добавляем новый email
            await ContactService.addEmail(
              email: _emailController.text,
              token: token,
            );
            // log.d('✅ Email added successfully');
          }
        } catch (e) {
          // log.d('❌ Email update error: $e');
        }
      }

      // Обновляем или добавляем первый телефон
      if (_phone1Controller.text.isNotEmpty) {
        try {
          if (_phone1Id != null) {
            // log.d('☎️ Updating phone1 (ID: $_phone1Id)');
            // Обновляем существующий телефон
            await ContactService.updatePhone(
              id: _phone1Id!,
              phone: _phone1Controller.text,
              token: token,
            );
            // log.d('✅ Phone1 updated successfully');
          } else {
            // log.d('☎️ Adding new phone1');
            // Добавляем новый телефон
            await ContactService.addPhone(
              phone: _phone1Controller.text,
              token: token,
            );
            // log.d('✅ Phone1 added successfully');
          }
        } catch (e) {
          // log.d('❌ Phone 1 update error: $e');
        }
      }

      // Обновляем или добавляем второй телефон
      if (_phone2Controller.text.isNotEmpty) {
        try {
          if (_phone2Id != null) {
            // log.d('☎️ Updating phone2 (ID: $_phone2Id)');
            // Обновляем существующий телефон
            await ContactService.updatePhone(
              id: _phone2Id!,
              phone: _phone2Controller.text,
              token: token,
            );
            // log.d('✅ Phone2 updated successfully');
          } else {
            // log.d('☎️ Adding new phone2');
            // Добавляем новый телефон
            await ContactService.addPhone(
              phone: _phone2Controller.text,
              token: token,
            );
            // log.d('✅ Phone2 added successfully');
          }
        } catch (e) {
          // log.d('Phone 2 update error: $e');
        }
      }

      // После успешных изменений — проверяем данные на сервере
      // log.d('🔎 Verifying saved contact data by fetching from server...');
      try {
        await _loadContactData();
        // log.d('✅ Verification GET complete');
      } catch (e) {
        // log.d('❗ Reload after save failed: $e');
      }

      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });

      // Перезагружаем профиль для обновления на других экранах
      if (mounted) {
        // 🔄 ВАЖНО: Инвалидируем кеш объявлений перед загрузкой профиля
        // Это гарантирует, что объявления будут перезагружены после изменения контактных данных
        final cacheService = AppCacheService();
        cacheService.invalidate(CacheKeys.listingsData);
        log.d('✅ Кеш объявлений инвалидирован после сохранения контактных данных');

        // ✅ Обновляем профиль
        context.read<ProfileBloc>().add(LoadProfileEvent());

        // 🔄 КРИТИЧНО: Явно перезагружаем объявления с forceRefresh=true
        // Это гарантирует что ListingsBloc не будет использовать старый кеш
        context.read<ListingsBloc>().add(LoadListingsEvent(forceRefresh: true));
        log.d('🔄 Явно запущена перезагрузка объявлений (LoadListingsEvent с forceRefresh=true)');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Контактные данные сохранены')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка сохранения: ${e.toString()}';
        _isLoading = false;
      });
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
    _regionController.dispose();
    _cityController.dispose();
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
                      _field(_regionController, 'Введите вашу область'),

                      _label('Ваш город'),
                      _field(_cityController, 'Введите ваш город'),

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
}
