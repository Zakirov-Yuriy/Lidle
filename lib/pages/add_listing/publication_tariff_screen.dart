import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/widgets/dialogs/moderation_dialog.dart';
import '../../constants.dart';
import '../../widgets/components/header.dart';
import '../profile_dashboard/my_listings/my_listings_screen.dart';


// ============================================================
// "Виджет: Экран выбора тарифа публикации"
// ============================================================
class PublicationTariffScreen extends StatefulWidget {
  static const String routeName = '/publication-tariff';

  final bool isEditMode;
  final int? categoryId;

  const PublicationTariffScreen({
    super.key,
    this.isEditMode = false,
    this.categoryId,
  });

  @override
  State<PublicationTariffScreen> createState() =>
      _PublicationTariffScreenState();
}

class _PublicationTariffScreenState extends State<PublicationTariffScreen> {
  @override
  void initState() {
    super.initState();
    // Если переданы arguments через Route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        // Аргументы успешно переданы
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Header(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 19,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back_ios,
                        color: textPrimary,
                        size: 16,
                      ),
                    ),

                    const Text(
                      'Тариф публикации',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Отмена',
                        style: TextStyle(
                          color: activeIconColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
                child: Column(
                  children: [
                    _buildTariffCard(
                      context,
                      tariffName: 'Бесплатный',
                      features: ['Бесплатная публикация в ленте'],
                      price: 'Бесплатно',
                      isPrimary: true,
                    ),
                    // const SizedBox(height: 10),
                    // _buildTariffCard(
                    //   context,
                    //   tariffName: 'Стандарт',
                    //   features: [
                    //     'Публикация в топ',
                    //     'Помощь в ведении публикации',
                    //   ],
                    //   price: '400р',
                    // ),
                    // const SizedBox(height: 10),
                    // _buildTariffCard(
                    //   context,
                    //   tariffName: 'Премиум',
                    //   features: [
                    //     'Публикация в топ',
                    //     'Помощь в ведении публикации',
                    //     'Вип позиции',
                    //   ],
                    //   price: '700р',
                    // ),
                    const SizedBox(height: 79),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // "Виджет: Построение карточки тарифа публикации"
  // ============================================================
  Widget _buildTariffCard(
    BuildContext context, {
    required String tariffName,
    required List<String> features,
    required String price,
    bool isPrimary = false,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 14, bottom: 20, top: 19),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              children: [
                const TextSpan(
                  text: 'Тариф: ',
                  style: TextStyle(color: textSecondary),
                ),
                TextSpan(
                  text: tariffName,
                  style: const TextStyle(color: textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...features
              .map(
                (feature) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5.0),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/publication_tariff/check.svg',
                        width: 20,
                        height: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        feature,
                        style: const TextStyle(
                          color: textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5.0),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/publication_tariff/icon.svg',
                  width: 20,
                  height: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Для более быстрой модерации используйте платную модерации.',
                    style: const TextStyle(color: textPrimary, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          const Divider(color: textMuted),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Цена: ',
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                TextSpan(
                  text: price,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 17),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: formBackground,
                side: const BorderSide(color: Color(0xFF009EE2)),
                minimumSize: const Size.fromHeight(43),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                if (isPrimary) {
                  final categoryId = widget.categoryId;

                  // Показываем диалог модерации
                  await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => ModerationDialog(
                      onContinue: () {
                        Navigator.of(context).pop(); // закрыть диалог
                        if (categoryId != null) {
                          Navigator.of(context).pushReplacementNamed(
                            MyListingsScreen.routeName,
                            arguments: {
                              'categoryId': categoryId,
                              'tabIndex': 3,
                            },
                          );
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  );
                } else {
                  Navigator.pushNamed(
                    context,
                    '/payment',
                    arguments: <String, String>{
                      'tariffName': tariffName,
                      'price': price,
                    },
                  );
                }
              },
              child: Text(
                'Опубликовать',
                style: const TextStyle(color: Color(0xFF009EE2), fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
