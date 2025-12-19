import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/cards/listing_card.dart';
import 'package:lidle/widgets/dialogs/complaint_dialog.dart';

// ============================================================
// "Экран профиля продавца"
// ============================================================

const String shoppingCartAsset = 'assets/BottomNavigation/shopping-cart-01.png';

class SellerProfileScreen extends StatefulWidget {
  static const String routeName = "/seller-profile";

  final String sellerName;
  final ImageProvider sellerAvatar;
  final List<Map<String, dynamic>> sellerListings;

  const SellerProfileScreen({
    super.key,
    required this.sellerName,
    required this.sellerAvatar,
    required this.sellerListings,
  });

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  int selectedStars = 1;
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      bottomNavigationBar: _buildBottomNavigation(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0, left: 8),
                child: const Header(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Column(
                  children: [
                    _buildHeader(),

                    const SizedBox(height: 31),
                    _buildSellerInfo(),

                    const SizedBox(height: 18),
                    _buildRateSeller(),

                    const SizedBox(height: 25),
                    Row(children: [_buildListingsTitle()]),
                    const SizedBox(height: 16),

                    _buildListingsGrid(),

                    const SizedBox(height: 36),
                    _buildComplaintBlock(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.lightBlue,
            size: 22,
          ),
        ),

        const Text(
          "Назад",
          style: TextStyle(color: Colors.lightBlue, fontSize: 16),
        ),
        const Spacer(),

        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white, size: 23),
          onPressed: () {
            Share.share('Поделиться профилем продавца ${widget.sellerName}');
          },
        ),
      ],
    );
  }

  Widget _buildSellerInfo() {
    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(radius: 38, backgroundImage: widget.sellerAvatar),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.sellerName,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: const [
                    Text(
                      "На VSEUT с 2024 г.",
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    SizedBox(width: 10),
                    Text(
                      "Оценка: ",
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    Icon(Icons.star, color: Colors.amber, size: 16),
                    Text(" 4", style: TextStyle(color: textPrimary)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "Проверенный продавец",
                  style: TextStyle(color: Colors.greenAccent, fontSize: 14),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 15),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.lightBlue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () {},
            child: const Text(
              "Подписаться на продавца",
              style: TextStyle(color: Colors.lightBlue, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRateSeller() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Оставить оценку продавцу",
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            "Вы можете оставить оценку продавцу это поднимет его рейтинг.",
            style: TextStyle(color: textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 11),

          const Text(
            "Оценка:",
            style: TextStyle(color: textPrimary, fontSize: 16),
          ),
          const SizedBox(height: 6),

          Row(
            children: List.generate(
              5,
              (index) => GestureDetector(
                onTap: () => setState(() => selectedStars = index + 1),
                child: Icon(
                  Icons.star,
                  color: index < selectedStars ? Colors.amber : Colors.grey,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingsTitle() {
    return const Text(
      "Объявления продавца",
      style: TextStyle(
        color: textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildListingsGrid() {
    return GridView.builder(
      itemCount: widget.sellerListings.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 15,
        crossAxisSpacing: 8,
        childAspectRatio: 0.70,
      ),
      itemBuilder: (_, i) =>
          ListingCard(listing: Listing.fromJson(widget.sellerListings[i])),
    );
  }

  Widget _buildComplaintBlock() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 25, left: 22, bottom: 12, right: 10),
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Оставить жалобу на продавца",
            style: TextStyle(color: textPrimary, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              text:
                  "Вы можете оставить жалобу на продавца в случае нарушения им ",
              style: const TextStyle(color: textSecondary, fontSize: 15),
              children: [
                TextSpan(
                  text: "правил",
                  style: const TextStyle(color: Colors.blue, fontSize: 15),
                ),
                TextSpan(
                  text: ".",
                  style: const TextStyle(color: textSecondary, fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),

          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return const ComplaintDialog();
                },
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Text(
                  "Пожаловаться",
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.red,
                  size: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(String iconPath, int index, int currentSelected) {
    final isSelected = currentSelected == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: () => setState(() => _selectedIndex = index),
        child: Padding(
          padding: const EdgeInsets.all(0),
          child: Image.asset(
            iconPath,
            width: 28,
            height: 28,
            color: isSelected ? activeIconColor : inactiveIconColor,
          ),
        ),
      ),
    );
  }

  Widget _buildCenterAdd(int index, int currentSelected) {
    final isSelected = currentSelected == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: Image.asset(
            plusIconAsset,
            width: 28,
            height: 28,
            color: isSelected ? activeIconColor : inactiveIconColor,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 0, 25, 48),
      child: Container(
        height: bottomNavHeight,
        decoration: BoxDecoration(
          color: bottomNavBackground,
          borderRadius: BorderRadius.circular(37.5),
          boxShadow: const [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(homeIconAsset, 0, _selectedIndex),
            _buildNavItem(gridIconAsset, 1, _selectedIndex),
            _buildCenterAdd(2, _selectedIndex),
            _buildNavItem(shoppingCartAsset, 3, _selectedIndex),
            _buildNavItem(messageIconAsset, 4, _selectedIndex),
            _buildNavItem(userIconAsset, 5, _selectedIndex),
          ],
        ),
      ),
    );
  }
}
