import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/widgets/header.dart';
import 'package:lidle/widgets/listing_card.dart';
import 'package:lidle/widgets/complaint_dialog.dart';


class SellerProfileScreen extends StatefulWidget {
  static const String routeName = "/seller-profile";

  final String sellerName;
  final ImageProvider sellerAvatar; // Changed to ImageProvider
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
  int selectedStars = 1; // оценка по умолчанию
  int _selectedIndex = 0;
  Set<String> _selectedSortOptions = {};
  List<String> _availableSortOptions = const [
    'Сначала новые',
    'Сначала старые',
    'Сначала дорогие',
    'Сначала дешевые',
  ];

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
              Row(
                children: [
                  _buildListingsTitle(),
                ],
              ),
              const SizedBox(height: 16),
              // const SizedBox(height: 10), // Removed as _buildListingsGrid handles its own spacing
              _buildListingsGrid(),

              const SizedBox(height: 36),
              _buildComplaintBlock(),

              const SizedBox(height: 40),
            ],),
            ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- HEADER -------------------

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.lightBlue, size: 22),
        ),
        // const SizedBox(width: 12),

        const Text(
          "Назад",
          style: TextStyle(
            color: Colors.lightBlue,
            fontSize: 16,
          ),
        ),
        const Spacer(),

        GestureDetector(
          onTap: () {
            // share logic
          },
          child: const Icon(Icons.share, color: Colors.white, size: 23),
        ),
      ],
    );
  }

  // ---------------- SELLER INFO -------------------

  Widget _buildSellerInfo() {
    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 38,
              backgroundImage: widget.sellerAvatar, // Use ImageProvider directly
            ),
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
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                      ),
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
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 15),

        // Подписаться
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

  // ---------------- RATE SELLER BLOCK -------------------

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
            style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
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

  // ---------------- TITLE "LISTINGS" -------------------

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

  // ---------------- GRID OF LISTINGS -------------------

  Widget _buildListingsGrid() {
    return GridView.builder(
      // padding: const EdgeInsets.symmetric(horizontal: 25),
      itemCount: widget.sellerListings.length, // Using widget.sellerListings
      shrinkWrap: true, // Added to allow GridView inside SingleChildScrollView
      physics: const NeverScrollableScrollPhysics(), // Added to prevent nested scrolling issues
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 15,
        crossAxisSpacing: 8,
        childAspectRatio: 0.70,
      ),
      itemBuilder: (_, i) => ListingCard(listing: Listing.fromJson(widget.sellerListings[i])), // Using Listing.fromJson
    );
  }

  // ---------------- COMPLAINT BLOCK -------------------

  Widget _buildComplaintBlock() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
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
              text: "Вы можете оставить жалобу на продавца в случае нарушения им ",
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
          const SizedBox(height: 23),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return const ComplaintDialog();
                  },
                );
              },
              child: const Text(
                "Пожаловаться",
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          )
        ],
      ),
    );
  }

  // ---------------- BOTTOM NAVIGATION -------------------

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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(25, 0, 25, bottomNavPaddingBottom),
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
              _buildNavItem(messageIconAsset, 3, _selectedIndex),
              _buildNavItem(userIconAsset, 4, _selectedIndex),
            ],
          ),
        ),
      ),
    );
  }
}
