// ============================================================
// "Виджет: Экран контактов пользователя"
// ============================================================

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/auth_service.dart';
import 'package:lidle/hive_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  static const bgColor = Color(0xFF243241);
  static const fieldColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const textSecondary = Colors.white54;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  static const bgColor = Color(0xFF243241);
  static const fieldColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const textSecondary = Colors.white54;

  List<Map<String, dynamic>> _allContacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];
  TextEditingController _searchController = TextEditingController();

  String _currentUserId =
      '0'; // ID текущего пользователя для привязки контактов

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final token = await HiveService.getUserData('token');
      if (token == null) {
        throw Exception('Токен не найден');
      }

      // Получаем userId из токена
      _currentUserId = AuthService.extractUserIdFromToken(token);
      // print('📱 Загружаем контакты для userId: $_currentUserId');

      final savedContacts = _getSavedContactsFromLocal();
      List<Map<String, dynamic>> allContacts = [];

      for (var savedContact in savedContacts) {
        try {
          final userId = savedContact['user_id'];
          final userResponse = await ApiService.get(
            '/users/$userId',
            token: token,
          );

          if (userResponse != null && userResponse is Map<String, dynamic>) {
            final userData =
                userResponse['data'] != null &&
                    userResponse['data'] is List &&
                    userResponse['data'].isNotEmpty
                ? userResponse['data'][0]
                : userResponse;

            allContacts.add({
              'id': userId,
              'userId': userId,
              'name': userData['name'] ?? 'Без имени',
              'avatar': userData['avatar'],
              'status': userData['status'] ?? 'offline',
              'lastSeen': userData['last_seen'],
              'phone': savedContact['phone'] ?? '',
            });
          }
        } catch (e) {
          // print('❌ Error loading user profile: $e');
        }
      }

      setState(() {
        _allContacts = allContacts;
        _filterContacts();
        _isLoading = false;
      });
    } catch (e) {
      // print('❌ Error loading contacts: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getSavedContactsFromLocal() {
    // Используем ключ с привязкой к userId: 'savedContacts_<userId>'
    final key = 'savedContacts_$_currentUserId';
    final contactsJson = HiveService.getUserData(key);
    if (contactsJson == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(contactsJson);
      return List<Map<String, dynamic>>.from(
        decoded.map((item) => Map<String, dynamic>.from(item)),
      );
    } catch (e) {
      // print('❌ Error parsing saved contacts: $e');
      return [];
    }
  }

  void _saveContactLocally(int userId, String phone) {
    // Используем ключ с привязкой к userId: 'savedContacts_<userId>'
    final key = 'savedContacts_$_currentUserId';
    final savedContacts = _getSavedContactsFromLocal();
    if (!savedContacts.any((c) => c['user_id'] == userId)) {
      savedContacts.add({'user_id': userId, 'phone': phone});
      HiveService.saveUserData(key, jsonEncode(savedContacts));
      // print('💾 Контакт сохранен для userId $_currentUserId: user_id=$userId');
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _allContacts;
      } else {
        _filteredContacts = _allContacts
            .where(
              (contact) =>
                  (contact['name'] as String).toLowerCase().contains(query) ||
                  (contact['phone'] as String).toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  void _showAddContactDialog() {
    final userIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: fieldColor,
        title: const Text(
          'Добавить контакт',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Введите ID пользователя',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: userIdController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'ID пользователя',
                  labelStyle: const TextStyle(color: Colors.white54),
                  hintText: 'Например: 5',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF192635),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              if (userIdController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Введите ID пользователя'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final userId = int.tryParse(userIdController.text) ?? 0;
              if (userId == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Некорректный ID'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              await _addContact(userId);
              if (mounted) {
                Navigator.pop(context);
                userIdController.clear();
              }
            },
            child: const Text('Добавить', style: TextStyle(color: accentColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _addContact(int userId) async {
    try {
      final token = await HiveService.getUserData('token');
      if (token == null) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(accentColor),
          ),
        ),
      );

      final response = await ApiService.get('/users/$userId', token: token);

      if (mounted) Navigator.pop(context);

      if (response != null && response is Map<String, dynamic>) {
        final userData =
            response['data'] != null &&
                response['data'] is List &&
                response['data'].isNotEmpty
            ? response['data'][0] as Map<String, dynamic>
            : response as Map<String, dynamic>;

        final userName = userData['name'] ?? 'Unknown';
        final userAvatar = userData['avatar'];
        final userStatus = userData['status'] ?? 'offline';
        final userPhone = userData['phone'] ?? '';

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: fieldColor,
            title: const Text(
              'Добавить контакт?',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (userAvatar != null && userAvatar.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Image.network(
                      userAvatar,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildAvatarPlaceholder(userName),
                    ),
                  )
                else
                  _buildAvatarPlaceholder(userName),
                const SizedBox(height: 16),
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (userPhone.isNotEmpty)
                  Text(
                    userPhone,
                    style: const TextStyle(color: accentColor, fontSize: 14),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: userStatus == 'online'
                        ? Colors.green.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: userStatus == 'online'
                              ? Colors.green
                              : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        userStatus == 'online'
                            ? 'В сети'
                            : userData['last_seen'] != null
                            ? _formatLastSeen(userData['last_seen'])
                            : 'Не в сети',
                        style: TextStyle(
                          color: userStatus == 'online'
                              ? Colors.green
                              : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Отмена',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Добавить',
                  style: TextStyle(color: accentColor),
                ),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          _saveContactLocally(userId, userPhone);
          await _loadContacts();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Контакт успешно добавлен'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось загрузить профиль пользователя'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // print('Error adding contact: $e');
      if (mounted) {
        try {
          Navigator.pop(context);
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildAvatarPlaceholder(String name) {
    final initials = name
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join()
        .substring(0, 1);

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [accentColor, Color(0xFF0088BB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(50),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatLastSeen(String lastSeen) {
    if (lastSeen.contains('сегодня')) {
      return 'был(а) сегодня';
    } else if (lastSeen.contains('вчера')) {
      return 'был(а) вчера';
    } else if (lastSeen.contains('назад')) {
      return 'был(а) $lastSeen';
    }
    return 'был(а) $lastSeen';
  }

  Future<void> _deleteContact(int userId) async {
    try {
      final key = 'savedContacts_$_currentUserId';
      final savedContacts = _getSavedContactsFromLocal();
      savedContacts.removeWhere((c) => c['user_id'] == userId);

      if (savedContacts.isEmpty) {
        HiveService.deleteUserData(key);
      } else {
        HiveService.saveUserData(key, jsonEncode(savedContacts));
      }

      await _loadContacts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Контакт удален'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // print('❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
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
                    'Контакты',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ───── Search ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: formBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Поиск контактов',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ───── Contacts list ─────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: accentColor),
                    )
                  : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Ошибка загрузки',
                            style: TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loadContacts,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                            ),
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    )
                  : _filteredContacts.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'Нет контактов'
                            : 'Контакты не найдены',
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      itemCount: _filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = _filteredContacts[index];
                        return _ContactUserCard(
                          contact: contact,
                          onDelete: () => _deleteContact(contact['userId']),
                        );
                      },
                    ),
            ),

            // ───── Add contact ─────
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 8, 25, 16),
              child: GestureDetector(
                onTap: _showAddContactDialog,
                child: Row(
                  children: const [
                    Icon(Icons.person_add_alt, color: accentColor),
                    SizedBox(width: 8),
                    Text(
                      'Добавить контакт',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CONTACT USER CARD
// ─────────────────────────────────────────────

class _ContactUserCard extends StatelessWidget {
  final Map<String, dynamic> contact;
  final VoidCallback onDelete;

  const _ContactUserCard({required this.contact, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = contact['name'] ?? 'Unknown';
    final avatar = contact['avatar'];
    final phone = contact['phone'] ?? '';
    final status = contact['status'] ?? 'offline';
    final lastSeen = contact['lastSeen'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Avatar
          if (avatar != null && avatar.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(31),
              child: Image.network(
                avatar,
                width: 62,
                height: 62,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholderAvatar(name),
              ),
            )
          else
            _buildPlaceholderAvatar(name),

          const SizedBox(width: 12),

          // Contact info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (phone.isNotEmpty)
                  Text(
                    phone,
                    style: const TextStyle(
                      color: Color(0xFF00B7FF),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 6),
                // Status badge
                Text(
                  status == 'online'
                      ? 'В сети'
                      : lastSeen != null
                      ? _formatLastSeen(lastSeen)
                      : 'Не в сети',
                  style: TextStyle(
                    color: status == 'online' ? Colors.green : Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          // Delete button
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, color: Colors.grey, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderAvatar(String name) {
    final initials = name
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join()
        .substring(0, 1);

    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00B7FF), Color(0xFF0088BB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(31),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatLastSeen(String lastSeen) {
    if (lastSeen.contains('сегодня')) {
      return 'был(а) сегодня';
    } else if (lastSeen.contains('вчера')) {
      return 'был(а) вчера';
    } else if (lastSeen.contains('назад')) {
      return 'был(а) $lastSeen';
    }
    return 'был(а) $lastSeen';
  }
}

