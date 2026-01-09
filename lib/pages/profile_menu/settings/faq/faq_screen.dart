// ============================================================
// "Виджет: Экран часто задаваемых вопросов"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/widgets/components/header.dart';

class FaqScreen extends StatefulWidget {
  static const routeName = '/faq';

  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  static const bgColor = Color(0xFF243241);
  static const cardColor = Color(0xFF1F2C3A);
  static const textSecondary = Colors.white70;

  int? _openedIndex;

  final List<_FaqItem> _items = [
    _FaqItem(
      title: 'Что такое LIDLE',
      content:
          'VSETUT это площадка для публикации и поиска услуг, товаров, '
          'профессионалов, недвижимости, машин и всего что вам необходимо.',
    ),
    _FaqItem(title: 'Что может LIDLE'),
    _FaqItem(title: 'Как подать объявление на LIDLE'),
    _FaqItem(title: 'Как убрать объявление на LIDLE'),
    _FaqItem(title: 'Как убрать объявление на LIDLE'),
    _FaqItem(title: 'Как подать жалобу на продавца в LIDLE'),
  ];

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
                    'Вопросы о LIDLE',
                    style: TextStyle(
                      color: Color.fromARGB(255, 255, 255, 255),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ───── FAQ list ─────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final isOpen = _openedIndex == index;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _openedIndex = isOpen ? null : index;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  isOpen ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_left,
                                  key: ValueKey(isOpen),
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          if (isOpen && item.content != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              item.content!,
                              style: const TextStyle(
                                color: textSecondary,
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────

class _FaqItem {
  final String title;
  final String? content;

  _FaqItem({required this.title, this.content});
}
