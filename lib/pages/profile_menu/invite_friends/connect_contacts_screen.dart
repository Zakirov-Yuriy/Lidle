import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/pages/profile_menu/invite_friends/user_account_screen.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/services/contacts_check_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/core/logger.dart';

class ConnectContactsScreen extends StatefulWidget {
  static const routeName = '/connect-contacts';

  const ConnectContactsScreen({super.key});

  @override
  State<ConnectContactsScreen> createState() => _ConnectContactsScreenState();
}

class _ConnectContactsScreenState extends State<ConnectContactsScreen> {
  int _currentTab = 0;
  List<Contact> _myContacts = [];
  List<Contact> _lidleContacts = [];
  bool _isLoading = false;
  String? _errorMessage;

  static const bgColor = Color(0xFF243241);
  static const accentColor = Color(0xFF00B7FF);

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  /// Создает демо-контакты для тестирования
  // List<Contact> _getDemoContacts() {
  //   final demoContact = Contact(
  //     id: 'demo_001',
  //     displayName: 'Егор Вирикин',
  //     phones: [
  //       Phone('+7 949 622 44 31'),
  //     ],
  //   );
  //   return [demoContact];
  // }

  /// Загружает контакты из телефона и проверяет, кто уже в LIDLE
  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Проверяем и запрашиваем разрешение на доступ к контактам
      final PermissionStatus status = await Permission.contacts.request();

      if (status.isDenied) {
        setState(() {
          _errorMessage = 'Доступ к контактам отклонен';
          _isLoading = false;
        });
        return;
      }

      if (status.isPermanentlyDenied) {
        openAppSettings();
        setState(() {
          _errorMessage = 'Требуется включить доступ к контактам в настройках';
          _isLoading = false;
        });
        return;
      }

      // Получаем контакты с номерами телефонов
      List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      // Фильтруем контакты с номерами телефонов
      List<Contact> contactsWithPhones = contacts
          .where((c) => c.phones.isNotEmpty)
          .toList();

      // Если нет реальных контактов, добавляем демо-контакт для тестирования
      // if (contactsWithPhones.isEmpty) {
      //   contactsWithPhones = _getDemoContacts();
      // }

      // Получаем токен для API запроса
      final token = TokenService.currentToken;

      // Извлекаем номера телефонов для проверки
      final phoneNumbers = contactsWithPhones
          .map((c) => c.phones.first.number)
          .toList();

      // Проверяем, какие номера уже в LIDLE
      final usersInLidle =
          await ContactsCheckService.checkPhoneNumbers(phoneNumbers, token: token);

      // Разбиваем контакты на две группы
      final myContactsList = <Contact>[];
      final lidleContactsList = <Contact>[];

      for (final contact in contactsWithPhones) {
        final phone = contact.phones.first.number;
        final isInLidle = usersInLidle[phone] != null;

        if (isInLidle) {
          lidleContactsList.add(contact);
        } else {
          myContactsList.add(contact);
        }
      }

      setState(() {
        _myContacts = myContactsList;
        _lidleContacts = lidleContactsList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка при загрузке контактов: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
           // ───── Header ─────
            Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 23),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [const Header()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      color: Color.fromARGB(255, 255, 255, 255),
                      size: 16,
                    ),
                  ),
                  const Text(
                    'Подключить контакты',
                    style: TextStyle(
                      color: Color.fromARGB(255, 255, 255, 255),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Назад',
                      style: TextStyle(color: activeIconColor, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ───── Tabs ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _currentTab = 0),
                        child: Text(
                          'Мои контакты',
                          style: TextStyle(
                            color: _currentTab == 0 ? accentColor : Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: () => setState(() => _currentTab = 1),
                        child: Text(
                          'В LIDLE',
                          style: TextStyle(
                            color: _currentTab == 1 ? accentColor : Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Stack(
                    children: [
                      Container(
                        height: 1,
                        width: double.infinity,
                        color: Colors.white24,
                      ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        left: _currentTab == 0 ? 0 : 125,
                        child: Container(
                          height: 2,
                          width: _currentTab == 0 ? 105 : 50,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            // ───── Content ─────
            Expanded(
              child: _currentTab == 0 ? _contactsTab() : _lidleTab(),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // CONTACTS TAB
  // ─────────────────────────────────────────────

  Widget _contactsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadContacts,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_myContacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.contacts_outlined,
                color: Colors.white38, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Контакты не найдены',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadContacts,
              child: const Text('Загрузить контакты'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      itemCount: _myContacts.length,
      itemBuilder: (context, index) {
        final contact = _myContacts[index];
        final phone = contact.phones.isNotEmpty 
            ? contact.phones.first.number 
            : 'Нет номера';
        
        return _ContactItem(
          name: contact.displayName,
          phone: phone,
          isInvite: true,
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // LIDLE TAB (Users in LIDLE)
  // ─────────────────────────────────────────────

  Widget _lidleTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadContacts,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_lidleContacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, color: Colors.white38, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Ваши друзья не в LIDLE',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Пригласите их в приложение!',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      itemCount: _lidleContacts.length,
      itemBuilder: (context, index) {
        final contact = _lidleContacts[index];
        final phone = contact.phones.isNotEmpty 
            ? contact.phones.first.number 
            : 'Нет номера';
        
        // На практике здесь нужно хранить информацию о статусе подписки от API
        // Для демо: чередуем статус
        return _ContactItem(
          name: contact.displayName,
          phone: phone,
          isFollowed: index.isEven,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// CONTACT ITEM
// ─────────────────────────────────────────────

class _ContactItem extends StatefulWidget {
  final String name;
  final String phone;
  final bool isInvite;
  final bool isFollowed;

  const _ContactItem({
    required this.name,
    required this.phone,
    this.isInvite = false,
    this.isFollowed = false,
  });

  @override
  State<_ContactItem> createState() => _ContactItemState();
}

class _ContactItemState extends State<_ContactItem> {
  bool _isInviteSent = false;
  static const String _cacheBoxName = 'sent_invitations';

  @override
  void initState() {
    super.initState();
    _loadInviteState();
  }

  /// Загружает состояние приглашения из кеша
  Future<void> _loadInviteState() async {
    try {
      final box = await Hive.openBox(_cacheBoxName);
      final sentPhones = List<String>.from(box.get('sent_phones', defaultValue: <String>[]) ?? <String>[]);
      
      if (sentPhones.contains(widget.phone)) {
        setState(() {
          _isInviteSent = true;
        });
      }
    } catch (e) {
      log.e('❌ Ошибка при загрузке состояния приглашений: $e');
    }
  }

  /// Сохраняет информацию о отправленном приглашении в кеш
  Future<void> _saveSentInvitation() async {
    try {
      final box = await Hive.openBox(_cacheBoxName);
      final sentPhones = List<String>.from(box.get('sent_phones', defaultValue: <String>[]) ?? <String>[]);
      
      if (!sentPhones.contains(widget.phone)) {
        sentPhones.add(widget.phone);
        await box.put('sent_phones', sentPhones);
        log.i('💾 Приглашение для ${widget.phone} сохранено в кеш');
      }
    } catch (e) {
      log.e('❌ Ошибка при сохранении в кеш: $e');
    }
  }

  /// Сообщение приглашения с ссылкой на приложение
  static const String _invitationMessage =
      'Привет! Присоединяйся ко мне на LIDLE - маркетплейс для покупки и продажи автомобилей, недвижимости и товаров. Скачай приложение: https://www.rustore.ru/catalog/app/io.lidle.app';

  /// Отправляет приглашение через системное меню Share
  Future<void> _shareInvite() async {
    try {
      await Share.share(
        _invitationMessage,
        subject: 'Приглашение в LIDLE',
      );
      log.i('📤 Приглашение поделено для ${widget.name}');
      
      // Сохраняем в кеш
      await _saveSentInvitation();
      
      // Обновляем состояние после успешного поделения
      setState(() {
        _isInviteSent = true;
      });
    } catch (e) {
      log.e('❌ Ошибка при отправке приглашения: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // avatar
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: formBackground,
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white24,
              size: 28,
            ),
          ),

          const SizedBox(width: 14),

          // name + phone
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.phone,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Action Button
          _buildActionButton(context),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    // Если приглашение уже отправлено
    if (widget.isInvite && _isInviteSent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.green, width: 1),
        ),
        child: TextButton(
          onPressed: null,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Уже приглашён',
            style: TextStyle(
              color: Colors.green,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    if (widget.isInvite) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onPressed: () => _shareInvite(),
        child: const Text(
          'Пригласить',
          style: TextStyle(
            color: activeIconColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    // "В LIDLE" buttons
    if (widget.isFollowed) {
      return Container(
        width: 125,
        height: 37,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white38),
        ),
        child: TextButton(
          onPressed: () {},
          child: const Text(
            'Подписаны',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      );
    } else {
      return Container(
        width: 125,
        height: 37,
        decoration: BoxDecoration(
          color: activeIconColor,
          borderRadius: BorderRadius.circular(13),
        ),
        child: TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserAccountScreen(
                  name: widget.name,
                  phone: widget.phone,
                ),
              ),
            );
          },
          child: const Text(
            'Подписаться',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
  }
}
