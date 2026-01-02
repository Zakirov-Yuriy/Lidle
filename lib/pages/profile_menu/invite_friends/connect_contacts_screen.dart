import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/pages/profile_menu/invite_friends/user_account_screen.dart';
import 'package:lidle/widgets/components/header.dart';

class ConnectContactsScreen extends StatefulWidget {
  static const routeName = '/connect-contacts';

  const ConnectContactsScreen({super.key});

  @override
  State<ConnectContactsScreen> createState() => _ConnectContactsScreenState();
}

class _ConnectContactsScreenState extends State<ConnectContactsScreen> {
  int _currentTab = 0;

  static const bgColor = Color(0xFF243241);
  static const accentColor = Color(0xFF00B7FF);

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
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      children: const [
        _ContactItem(
          name: 'Егор Вирикин',
          phone: '+7 949 622 44 31',
          isInvite: true,
        ),
        _ContactItem(
          name: 'Валера',
          phone: '+7 949 622 44 31',
          isInvite: true,
        ),
        _ContactItem(
          name: 'Елена',
          phone: '+7 949 622 44 31',
          isInvite: true,
        ),
        _ContactItem(
          name: 'Егор Егоров',
          phone: '+7 949 622 44 31',
          isInvite: true,
        ),
        _ContactItem(
          name: 'Стас Петров',
          phone: '+7 949 622 44 31',
          isInvite: true,
        ),
        _ContactItem(
          name: 'Оксана',
          phone: '+7 949 622 44 31',
          isInvite: true,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // LIDLE TAB (Users in LIDLE)
  // ─────────────────────────────────────────────

  Widget _lidleTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      children: const [
        _ContactItem(
          name: 'Данил Данилов',
          phone: '+7 949 622 44 31',
          isFollowed: false,
        ),
        _ContactItem(
          name: 'Егор Егоров',
          phone: '+7 949 622 44 31',
          isFollowed: true,
        ),
        _ContactItem(
          name: 'Ольга Якина',
          phone: '+7 949 622 44 31',
          isFollowed: false,
        ),
        _ContactItem(
          name: 'Андрей Андреев',
          phone: '+7 949 622 44 31',
          isFollowed: false,
        ),
        _ContactItem(
          name: 'Стас Петров',
          phone: '+7 949 622 44 31',
          isFollowed: false,
        ),
        _ContactItem(
          name: 'Женя Евген',
          phone: '+7 949 622 44 31',
          isFollowed: true,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// CONTACT ITEM
// ─────────────────────────────────────────────

class _ContactItem extends StatelessWidget {
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
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phone,
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
    if (isInvite) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onPressed: () {},
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
    if (isFollowed) {
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
                  name: name,
                  phone: phone,
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
