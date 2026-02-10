import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';

class IndoorAdvertisingScreen extends StatefulWidget {
  static const routeName = '/indoor-advertising';

  const IndoorAdvertisingScreen({super.key});

  @override
  State<IndoorAdvertisingScreen> createState() =>
      _IndoorAdvertisingScreenState();
}

class _IndoorAdvertisingScreenState extends State<IndoorAdvertisingScreen> {
  static const accentColor = Color(0xFF00B7FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            // ───── Header ─────
            Padding(
              padding: const EdgeInsets.only(bottom: 21, right: 23),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Header(),
                  Padding(
                    padding: const EdgeInsets.only(top: 19.0),
                    child: SvgPicture.asset(
                      'assets/home_page/share_outlined.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                ],
              ),
            ),

            // ───── Title ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 0),
                  const Text(
                    'Внутренняя реклама',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Назад',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ───── Content ─────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ───── Section 1: Raise to Top ─────
                    _advertisingSection(
                      title: 'Поднять предложение в топ',
                      items: [
                        'Публикация в топ',
                        'Помощь в ведении публикации',
                      ],
                      price: '400₽',
                      onPublish: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Опубликовано в топ')),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // ───── Section 2: Position Type ─────
                    _advertisingSection(
                      title: 'Вид позиции',
                      items: [
                        'Публикация в топ',
                        'Помощь в ведении публикации',
                        'Вид позиции',
                      ],
                      price: '700₽',
                      onPublish: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Опубликовано вид позиции'),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _advertisingSection({
    required String title,
    required List<String> items,
    required String price,
    required VoidCallback onPublish,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/publication_tariff/check.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF00D084),
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Цена: $price',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 42,
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: accentColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onPublish,
              child: const Text(
                'Опубликовать',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
