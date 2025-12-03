import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/header.dart';

class ShapePublicationSuccessScreen extends StatelessWidget {
  const ShapePublicationSuccessScreen({super.key});

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
                        color:
                            activeIconColor, // Changed color to activeIconColor
                        size: 16, // Reduced size
                      ),
                    ),
                    const Text(
                      'Назад', // Changed title as per the image
                      style: TextStyle(
                        color:
                            activeIconColor, // Consistent color with the icon
                        fontSize: 16,
                        fontWeight: FontWeight.w400, // Consistent font weight
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.share_outlined, color: textPrimary),
                      onPressed: () {
                        // TODO: Implement share functionality or keep it as a placeholder
                      },
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, // Changed to stretch
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
                    child: const _ListingCard(),
                  ),
                  const _ShareBlock(),
                ],
              ),
            ],
          ),
        ),
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
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 7.0),
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
      _ShareItem(
        imageAssetPath: "assets/publication_success/email_10401109.png",
        label: "Быстрая отправка",
      ),
      _ShareItem(
        imageAssetPath: "assets/publication_success/icons8-instagram-100.png",
        label: "Chats",
      ),
      _ShareItem(
        imageAssetPath: "assets/publication_success/icons8-telegram-100.png",
        label: "Telegram",
      ),
      _ShareItem(
        imageAssetPath:
            "assets/publication_success/free-icon-yandex-6124986.png",
        label: "Открыть в браузере",
      ),
      _ShareItem(
        imageAssetPath:
            "assets/publication_success/icons8-электронное-обучение-2-100.png",
        label: "Читалка",
      ),
      _ShareItem(
        imageAssetPath: "assets/publication_success/icons8-whatsapp-100.png",
        label: "WhatsApp",
      ),
      _ShareItem(
        imageAssetPath: "assets/publication_success/icons8-чат-100.png",
        label: "Сообщения",
      ),
      _ShareItem(
        imageAssetPath: "assets/publication_success/icons8-gmail-100.png",
        label: "Gmail",
      ),
    ];

    return Container(
      // Added Container to apply background and border radius
      decoration: BoxDecoration(
        color: formBackground, // Set background color
        // borderRadius: BorderRadius.circular(5), // Apply border radius
      ),
      padding: const EdgeInsets.only(top: 25.0, bottom: 40),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.center, // Centered title as per the image
        children: [
          const Text(
            "Поделиться",
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 26),
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
          Padding(
            padding: const EdgeInsets.only(left: 25.0, right: 25.0, top: 40.0),
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                height: 47,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: textMuted, // Grey background
                  borderRadius: BorderRadius.circular(50), // Radius 10
                ),
                child: const Center(
                  child: Text(
                    "Отмена",
                    style: TextStyle(
                      color: Colors.white, // White text
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
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
