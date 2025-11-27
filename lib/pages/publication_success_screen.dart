import 'package:flutter/material.dart';
import '../constants.dart'; // Import for primaryBackground
import '../widgets/header.dart'; // Import the Header widget

class PublicationSuccessScreen extends StatelessWidget {
  const PublicationSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Header(), // Add the Header widget
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
                        color: activeIconColor, // Changed color to activeIconColor
                        size: 16, // Reduced size
                      ),
                    ),
                    const Text(
                      'Назад', // Changed title as per the image
                      style: TextStyle(
                        color: activeIconColor, // Consistent color with the icon
                        fontSize: 16,
                        fontWeight: FontWeight.w400, // Consistent font weight
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Отмена',
                        style: TextStyle(color: activeIconColor, fontSize: 16, fontWeight: FontWeight.w400,),
                      ),
                    ),
                  ],
                ),
              ),
              Padding( // Wrap existing content in a padding to align with the header structure
                padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SuccessInfoCard(),
                    const SizedBox(height: 9),
                    const _ListingCard(),
                    const SizedBox(height: 24),
                    const _ShareBlock(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessInfoCard extends StatelessWidget {
  const _SuccessInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16, top: 21, bottom: 30, right: 18),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Отлично, вы подали товар!",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Вы можете поделиться ссылкой на товар со своими друзьями, "
            "удобным для вас способом. Так быстрее произойдет сделка.",
            style: TextStyle(
              color: textSecondary,
              fontSize: 15,
              height: 1.4,
              
            ),
          )
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E2A38),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 11.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5), // Apply border radius
                child: Image.asset(
                  "assets/publication_success/PublicationSuccessScreen.png", // Corrected asset path
                  fit: BoxFit.cover,
                  height: 260,
                  width: double.infinity,
                ),
              ),
            ),
            Container( // Added Container to apply background and border radius
              decoration: BoxDecoration(
                color: formBackground, // Set background color
                borderRadius: BorderRadius.circular(5), // Apply border radius
              ),
              padding: const EdgeInsets.only(top: 11, left: 16, right: 14, bottom: 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Text(
                        "29.08.2024",
                        style: TextStyle(color:textMuted, fontSize: 12),
                      ),
                      Spacer(),
                      Text(
                        "№ 343 232 34",
                        style: TextStyle(color:textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    "3-к. квартира, 125,5 м², 5/17 эт.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    "44 500 000 ₽",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
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

class _ShareBlock extends StatelessWidget {
  const _ShareBlock();

  @override
  Widget build(BuildContext context) {
    final items = [
      _ShareItem(imageAssetPath: "assets/publication_success/email_10401109.png", label: "Быстрая отправка"),
      _ShareItem(imageAssetPath: "assets/publication_success/icons8-instagram-100.png", label: "Chats"),
      _ShareItem(imageAssetPath: "assets/publication_success/icons8-telegram-100.png", label: "Telegram"),
      _ShareItem(imageAssetPath: "assets/publication_success/free-icon-yandex-6124986.png", label: "Открыть в браузере"),
      _ShareItem(imageAssetPath: "assets/publication_success/icons8-электронное-обучение-2-100.png", label: "Читалка"),
      _ShareItem(imageAssetPath: "assets/publication_success/icons8-whatsapp-100.png", label: "WhatsApp"),
      _ShareItem(imageAssetPath: "assets/publication_success/icons8-чат-100.png", label: "Сообщения"),
      _ShareItem(imageAssetPath: "assets/publication_success/icons8-gmail-100.png", label: "Gmail"),
    ];

    return Container( // Added Container to apply background and border radius
      decoration: BoxDecoration(
        color: formBackground, // Set background color
        borderRadius: BorderRadius.circular(5), // Apply border radius
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // Centered title as per the image
        children: [
          const Text(
            "Поделиться",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, // Changed to 3 to provide more space for text
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.8, // Reset to 1.0
            ),
            itemBuilder: (context, i) => items[i],
          ),
        ],
      ),
    );
  }
}

class _ShareItem extends StatelessWidget {
  final String imageAssetPath;
  final String label;

  const _ShareItem({required this.imageAssetPath, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
  children: [
    Image.asset(imageAssetPath, width: 48, height: 48),
    const SizedBox(height: 4),
    Flexible(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ],
); 

  }
}
