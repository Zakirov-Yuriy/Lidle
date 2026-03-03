// ============================================================
// "Виджет: Экран контактных данных"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/services/contact_service.dart';
import 'package:lidle/services/user_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/blocs/profile/profile_bloc.dart';
import 'package:lidle/blocs/profile/profile_event.dart';
import 'package:lidle/blocs/profile/profile_state.dart';

class ContactDataScreen extends StatefulWidget {
  static const routeName = '/contact_data';

  const ContactDataScreen({super.key});

  @override
  State<ContactDataScreen> createState() => _ContactDataScreenState();
}

class _ContactDataScreenState extends State<ContactDataScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phone1Controller;
  late TextEditingController _phone2Controller;
  late TextEditingController _telegramController;
  late TextEditingController _whatsappController;

  bool _isLoading = false;
  String? _errorMessage;

  // Храним ID контактов для обновления
  int? _phone1Id;
  int? _phone2Id;
  int? _emailId;

  static const bgColor = Color(0xFF243241);
  static const fieldColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const hintColor = Colors.white54;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phone1Controller = TextEditingController();
    _phone2Controller = TextEditingController();
    _telegramController = TextEditingController();
    _whatsappController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Загружаем профиль пользователя с принудительным обновлением
    context.read<ProfileBloc>().add(LoadProfileEvent(forceRefresh: true));
    _loadContactData();
  }

  Future<void> _loadContactData() async {
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

      // print('🔐 Token from Hive: ${token.substring(0, 20)}...');
      // print('🔐 Token length: ${token.length}');
      // print(
      //   '🔐 Token starts with: ${token.startsWith('eyJ') ? 'JWT (valid format)' : 'Unknown format'}',
      // );

      // Загружаем телефоны и почты
      final phonesResponse = await ContactService.getPhones(token: token);
      final emailsResponse = await ContactService.getEmails(token: token);

      // print();

      // Получаем имя пользователя из ProfileBloc (из API)
      final profileState = context.read<ProfileBloc>().state;
      final name = profileState is ProfileLoaded ? profileState.name : '';
      final email = profileState is ProfileLoaded ? profileState.email : '';
      final phone = profileState is ProfileLoaded ? profileState.phone : '';

      // print('🔍 DEBUG contact_data_screen._loadContactData():');
      // print('   - profileState.name = "$name"');
      // print('   - profileState.email = "$email"');
      // print('   - profileState.phone = "$phone"');

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
        _nameController.text = name;
        _emailController.text = emailValue;
        _phone1Controller.text = phone1;
        _phone2Controller.text = phone2;
        _telegramController.text = telegram;
        _whatsappController.text = whatsapp;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка загрузки: ${e.toString()}';
        _isLoading = false;
      });
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

      // print('💾 Saving contact data...');
      // print('Token: ${token.substring(0, 20)}...');
      // print();

      // Обновляем имя на API (если оно изменилось)
      if (_nameController.text.isNotEmpty) {
        try {
          // print('👤 Updating user name: ${_nameController.text}');
          // Получаем фамилию из Hive или используем пустую строку
          final lastName = UserService.getLocal('lastName') as String? ?? '';

          // print('🔍 DEBUG contact_data_screen._saveContactData():');
          // print();
          // print();

          await UserService.updateName(
            name: _nameController.text,
            lastName: lastName,
            token: token,
          );
          // print('✅ User name updated successfully');
        } catch (e) {
          // print('❌ Name update error: $e');
        }
      }

      // Сохраняем в локальное хранилище
      await UserService.saveLocal('name', _nameController.text);
      await UserService.saveLocal('telegram', _telegramController.text);
      await UserService.saveLocal('whatsapp', _whatsappController.text);

      // Обновляем или добавляем email
      if (_emailController.text.isNotEmpty) {
        try {
          if (_emailId != null) {
            // print('📧 Updating email (ID: $_emailId)');
            // Обновляем существующий email
            await ContactService.updateEmail(
              id: _emailId!,
              email: _emailController.text,
              token: token,
            );
            // print('✅ Email updated successfully');
          } else {
            // print('📧 Adding new email');
            // Добавляем новый email
            await ContactService.addEmail(
              email: _emailController.text,
              token: token,
            );
            // print('✅ Email added successfully');
          }
        } catch (e) {
          // print('❌ Email update error: $e');
        }
      }

      // Обновляем или добавляем первый телефон
      if (_phone1Controller.text.isNotEmpty) {
        try {
          if (_phone1Id != null) {
            // print('☎️ Updating phone1 (ID: $_phone1Id)');
            // Обновляем существующий телефон
            await ContactService.updatePhone(
              id: _phone1Id!,
              phone: _phone1Controller.text,
              token: token,
            );
            // print('✅ Phone1 updated successfully');
          } else {
            // print('☎️ Adding new phone1');
            // Добавляем новый телефон
            await ContactService.addPhone(
              phone: _phone1Controller.text,
              token: token,
            );
            // print('✅ Phone1 added successfully');
          }
        } catch (e) {
          // print('❌ Phone 1 update error: $e');
        }
      }

      // Обновляем или добавляем второй телефон
      if (_phone2Controller.text.isNotEmpty) {
        try {
          if (_phone2Id != null) {
            // print('☎️ Updating phone2 (ID: $_phone2Id)');
            // Обновляем существующий телефон
            await ContactService.updatePhone(
              id: _phone2Id!,
              phone: _phone2Controller.text,
              token: token,
            );
            // print('✅ Phone2 updated successfully');
          } else {
            // print('☎️ Adding new phone2');
            // Добавляем новый телефон
            await ContactService.addPhone(
              phone: _phone2Controller.text,
              token: token,
            );
            // print('✅ Phone2 added successfully');
          }
        } catch (e) {
          // print('Phone 2 update error: $e');
        }
      }

      // После успешных изменений — проверяем данные на сервере
      // print('🔎 Verifying saved contact data by fetching from server...');
      try {
        await _loadContactData();
        // print('✅ Verification GET complete');
      } catch (e) {
        // print('❗ Reload after save failed: $e');
      }

      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });

      // Перезагружаем профиль для обновления на других экранах
      if (mounted) {
        context.read<ProfileBloc>().add(LoadProfileEvent());

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
      body: SafeArea(
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
                        style: TextStyle(color: accentColor, fontSize: 16),
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
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),
                ),

              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.all(25),
                  child: SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: accentColor),
                    ),
                  ),
                )
              else ...[
                // ───── Fields ─────
                _label('Контактное лицо'),
                _field(_nameController, ''),

                _label('Электронная почта'),
                _field(_emailController, ''),

                _label('Номер телефона 1'),
                _field(_phone1Controller, ''),

                _label('Номер телефона 2'),
                _field(_phone2Controller, 'Введите'),

                _label('Ссылка на ваш чат в Max'),
                _field(_telegramController, ''),

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
}
