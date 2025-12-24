import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/offer_model.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/pages/offers/incoming_price_offer_page.dart';

class PriceOffersListPage extends StatefulWidget {
  final Offer offer;

  const PriceOffersListPage({super.key, required this.offer});

  static const routeName = '/price-offers-list';

  static const backgroundColor = Color(0xFF243241);
  static const cardColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const yellowColor = Color(0xFFE8FF00);
  static const dangerColor = Color(0xFFFF3B30);

  @override
  State<PriceOffersListPage> createState() => _PriceOffersListPageState();
}

class _PriceOffersListPageState extends State<PriceOffersListPage> {
  late List<PriceOfferItem> items;

  @override
  void initState() {
    super.initState();
    items = [
      PriceOfferItem(
        name: 'Виталий Покрышкин',
        subtitle: 'был(а) сегодня',
        price: '41 000 000₽',
        badgeCount: '1',
        avatar: 'assets/property_details_screen/Andrey.png',
      ),
      PriceOfferItem(
        name: 'Кирилл Кириллов',
        subtitle: 'был(а) сегодня',
        price: '40 700 000₽',
        badgeCount: '1',
        avatar: 'assets/profile_dashboard/Ellipse.png',
      ),
    ];
  }

  List<bool> itemChecked = [false, false];
  bool selectAllChecked = false;

  void _toggleSelectAll() {
    setState(() {
      selectAllChecked = !selectAllChecked;
      for (int i = 0; i < itemChecked.length; i++) {
        itemChecked[i] = selectAllChecked;
      }
    });
  }

  void _toggleItem(int index) {
    setState(() {
      itemChecked[index] = !itemChecked[index];
      selectAllChecked = itemChecked.every((checked) => checked);
    });
  }

  void _deleteSelected() {
    setState(() {
      for (int i = itemChecked.length - 1; i >= 0; i--) {
        if (itemChecked[i]) {
          items.removeAt(i);
          itemChecked.removeAt(i);
        }
      }
      selectAllChecked = false; // Reset select all after deletion
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PriceOffersListPage.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ───── Header ─────
            Padding(
              padding: const EdgeInsets.only(bottom: 5, right: 23),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [const Header(), const Spacer()],
              ),
            ),

            // ───── Back / Cancel ─────
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
                    'Предложения цен',
                    style: TextStyle(
                      color: Color.fromARGB(255, 255, 255, 255),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Отмена',
                      style: TextStyle(color: activeIconColor, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ───── Select all / Delete ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                children: [
                  _Checkbox(
                    isChecked: selectAllChecked,
                    onTap: _toggleSelectAll,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Выбрать все',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: itemChecked.contains(true) ? _deleteSelected : null,
                    child: Text(
                      'Удалить',
                      style: TextStyle(
                        color: itemChecked.contains(true) ? PriceOffersListPage.dangerColor : Colors.white38,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(color: Colors.white24, height: 0),

            // ───── List ─────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Column(
                    children: [
                      _OfferItem(
                        offerItem: item,
                        isChecked: itemChecked[index],
                        onChanged: () => _toggleItem(index),
                        onTap: () => Navigator.pushNamed(
                          context,
                          IncomingPriceOfferPage.routeName,
                          arguments: item,
                        ),
                      ),
                      if (index < items.length - 1) const SizedBox(height: 12),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 80), // под bottom nav
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────

class _OfferItem extends StatelessWidget {
  final PriceOfferItem offerItem;
  final bool isChecked;
  final VoidCallback onChanged;
  final VoidCallback onTap;

  const _OfferItem({
    required this.offerItem,
    required this.isChecked,
    required this.onChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _Checkbox(
                    isChecked: isChecked,
                    onTap: onChanged,
                  ),
                  const SizedBox(width: 12),

                  // avatar
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.black26,
                    backgroundImage: AssetImage(offerItem.avatar),
                  ),

                  const SizedBox(width: 12),

                  // name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offerItem.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          offerItem.subtitle,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // badge
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: PriceOffersListPage.yellowColor),
                    ),
                    child: Center(
                      child: Text(
                        offerItem.badgeCount,
                        style: const TextStyle(
                          color: PriceOffersListPage.yellowColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Text(
                    'Предложил цену:',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    offerItem.price,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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

class _Checkbox extends StatelessWidget {
  final bool isChecked;
  final VoidCallback onTap;

  const _Checkbox({
    required this.isChecked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white38),
          color: isChecked ? PriceOffersListPage.accentColor : Colors.transparent,
        ),
        child: isChecked
            ? const Icon(
                Icons.check,
                color: Colors.white,
                size: 16,
              )
            : null,
      ),
    );
  }
}
