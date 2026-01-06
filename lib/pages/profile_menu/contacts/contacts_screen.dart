import 'package:flutter/material.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/constants.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  static const bgColor = Color(0xFF243241);
  static const fieldColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const textSecondary = Colors.white54;

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
                children: const [Header()],
              ),
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
                child: const TextField(
                  style: TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
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
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                children: const [
                  _ContactItem(
                    name: 'Vlad',
                    status: 'В сети',
                    online: true,
                    image: 'assets/profile_dashboard/Ellipse.png',
                  ),
                  _ContactItem(
                    name: 'Егор Вирикин',
                    status: 'был(а) сегодня',
                    image: 'assets/profile_dashboard/Ellipse.png',
                  ),
                  _ContactItem(
                    name: 'Валера',
                    status: 'был(а) вчера',
                    image: 'assets/profile_dashboard/Ellipse.png',
                  ),
                  _ContactItem(
                    name: 'Елена',
                    status: 'был(а) вчера',
                    gradient: true,
                  ),
                  _ContactItem(
                    name: 'Vlad',
                    status: 'В сети',
                    online: true,
                    image: 'assets/profile_dashboard/Ellipse.png',
                  ),
                  _ContactItem(
                    name: 'Vlad',
                    status: 'В сети',
                    online: true,
                    image: 'assets/profile_dashboard/Ellipse.png',
                  ),
                  _ContactItem(
                    name: 'Vlad',
                    status: 'В сети',
                    online: true,
                    image: 'assets/profile_dashboard/Ellipse.png',
                  ),
                ],
              ),
            ),

            // ───── Add contact ─────
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 8, 25, 16),
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
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CONTACT ITEM
// ─────────────────────────────────────────────

class _ContactItem extends StatelessWidget {
  final String name;
  final String status;
  final bool online;
  final String? image;
  final bool gradient;

  const _ContactItem({
    required this.name,
    required this.status,
    this.online = false,
    this.image,
    this.gradient = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient
                  ? const LinearGradient(
                      colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                    )
                  : null,
              image: image != null
                  ? DecorationImage(
                      image: AssetImage(image!),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: gradient || image != null
                  ? null
                  : const Color(0xFF1F2C3A),
            ),
          ),

          const SizedBox(width: 12),

          // Name + status
          Column(
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
                status,
                style: TextStyle(
                  color: online ? activeIconColor : textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
