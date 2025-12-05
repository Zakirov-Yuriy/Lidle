import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/cards/listing_card.dart';
import 'package:lidle/widgets/dialogs/complaint_dialog.dart';

// ============================================================
// "Экран профиля продавца"
// ============================================================

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
              Row(
                children: [
                  _buildListingsTitle(),
                ],
              ),
              const SizedBox(height: 16),
              
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

  

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.lightBlue, size: 22),
        ),
        

        const Text(
          "Назад",
          style: TextStyle(
            color: Colors.lightBlue,
            fontSize: 16,
          ),
        ),
        const Spacer(),

        GestureDetector(
          onTap: () => _showShareBottomSheet(context),
          child: const Icon(Icons.share_outlined, color: Colors.white, size: 23),
        ),
      ],
    );
  }

  

  Widget _buildSellerInfo() {
    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 38,
              backgroundImage: widget.sellerAvatar, 
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
      itemBuilder: (_, i) => ListingCard(listing: Listing.fromJson(widget.sellerListings[i])), 
    );
  }

  

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

  void _showShareBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bc) {
        return Container(
          decoration: const BoxDecoration(
            color: secondaryBackground, 
            borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Text(
                  "Поделиться",
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: <Widget>[
                    _buildShareItem("Быстрая отправка", Icons.send, "assets/publication_success/email_10401109.png"),
                    _buildShareItem("Chats", Icons.chat, "assets/publication_success/icons8-чат-100.png"),
                    _buildShareItem("Telegram", Icons.send, "assets/publication_success/icons8-telegram-100.png"),
                    _buildShareItem("Открыть в Браузере", Icons.open_in_browser, "assets/publication_success/free-icon-yandex-6124986.png"),
                    _buildShareItem("Читалка", Icons.menu_book, null), 
                    _buildShareItem("WhatsApp", Icons.message, "assets/publication_success/icons8-whatsapp-100.png"),
                    _buildShareItem("Сообщения", Icons.message, "assets/publication_success/icons8-чат-100.png"),
                    _buildShareItem("Gmail", Icons.mail, "assets/publication_success/icons8-gmail-100.png"),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800], 
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () => Navigator.pop(bc),
                  child: const Text(
                    "Отмена",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareItem(String title, IconData defaultIcon, String? assetPath) {
    return GestureDetector(
      onTap: () {
        
        Navigator.pop(context); 
        
        print("Share $title tapped");
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (assetPath != null) 
            Image.asset(assetPath, width: 50, height: 50) 
          else 
            Icon(defaultIcon, size: 50, color: Colors.white), 
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: textPrimary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
