import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/dialogs/offer_price_dialog.dart';
import 'package:lidle/widgets/dialogs/complaint_dialog.dart';
import 'package:lidle/widgets/dialogs/phone_dialog.dart';
import 'package:lidle/pages/full_category_screen/seller_profile_screen.dart';


// ============================================================
// "Мини-экран деталей недвижимости"
// ============================================================

class MiniPropertyDetailsScreen extends StatefulWidget {
  final Listing listing; 

  const MiniPropertyDetailsScreen({
    super.key,
    required this.listing,
  }); 

  @override
  State<MiniPropertyDetailsScreen> createState() =>
      _MiniPropertyDetailsScreenState();
}

class _MiniPropertyDetailsScreenState extends State<MiniPropertyDetailsScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Listing> _similarListings = [
    Listing(
      id: '1',
      imagePath: "assets/property_details_screen/image2.png",
      title: "1-к. квартира, 33 м²",
      price: "44 500 000 ₽",
      location: "Москва, Истринская ул, 8к3",
      date: "09.08.2024",
      isFavorited: false,
    ),
    Listing(
      id: '2',
      imagePath: "assets/property_details_screen/image3.png",
      title: "2-к. квартира, 65,5 м² ",
      price: "21 000 000 ₽",
      location: "Москва, ул. Коминтерна, 4",
      date: "12.04.2024",
      isFavorited: false,
    ),
    Listing(
      id: '3',
      imagePath: "assets/property_details_screen/image4.png",
      title: "5-к. квартира, 111 м²",
      price: "21 000 000 ₽",
      location: "Москва, ул. Коминтерна, 4",
      date: "11.08.2024",
      isFavorited: false,
    ),
    Listing(
      id: '4',
      imagePath: "assets/property_details_screen/image5.png",
      title: "1-к. квартира, 30 м² ...",
      price: "21 000 000 ₽",
      location: "Москва, ул. Коминтерна, 4",
      date: "12.04.2024",
      isFavorited: false,
    ),
    Listing(
      id: '5',
      imagePath: "assets/property_details_screen/image4.png",
      title: "5-к. квартира, 111 м²",
      price: "21 000 000 ₽",
      location: "Москва, ул. Коминтерна, 4",
      date: "11.08.2024",
      isFavorited: false,
    ),
    Listing(
      id: '6',
      imagePath: "assets/property_details_screen/image5.png",
      title: "1-к. квартира, 30 м² ...",
      price: "21 000 000 ₽",
      location: "Москва, ул. Коминтерна, 4",
      date: "12.04.2024",
      isFavorited: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      int next = _pageController.page!.round();
      if (_currentPage != next) {
        setState(() {
          _currentPage = next;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: const Header(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back_ios,
                          color: activeIconColor,
                          size: 16,
                        ),
                      ),
                      const Text(
                        'Назад',
                        style: TextStyle(
                          color: activeIconColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, color: textPrimary),
                        onPressed: () {
                          final textToShare = '''
${widget.listing.title}
Цена: ${widget.listing.price}
Адрес: ${widget.listing.location}
Дата: ${widget.listing.date}
                          ''';

                          Share.share(textToShare);
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(right: 25, left: 25, top: 20),
                    children: [
                      _buildImageCarousel(),
                      const SizedBox(height: 16),
                      _buildMainInfoCard(),
                      const SizedBox(height: 16),
                      const _OfferPriceButton(),
                      const SizedBox(height: 19),
                      _buildLocationCard(),
                      const SizedBox(height: 10),
                      _buildAboutApartmentCard(),
                      const SizedBox(height: 10),
                      _buildDescriptionCard(),
                      const SizedBox(height: 24),
                      _buildSellerCard(),
                      const SizedBox(height: 19),
                      _buildComplaintButton(),
                      const SizedBox(height: 55),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomActionButtons(),
          ),
        ],
      ),
    );
  }

  

  Widget _buildImageCarousel() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Container(
            height: 260,
            color: Colors.grey[300],
            child: PageView(
              controller: _pageController,
              children: [
                Image.asset(widget.listing.imagePath, fit: BoxFit.cover),
              ],
            ),
          ),
        ),
        const SizedBox(
          height: 10,
        ), 
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            1, 
            (index) => _buildPageIndicator(index == _currentPage),
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(
        horizontal: 5.0,
      ), 
      height: 11.0, 
      width: 11.0, 
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Colors.blue : primaryBackground.withOpacity(0.5),
        border: Border.all(
          color: Colors.grey, 
          width: 1.0, 
        ),
      ),
    );
  }

  Widget _buildMainInfoCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.listing.date,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Text(
                widget.listing.id, 
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.listing.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.listing.price,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "354 582 ₽ за м²", 
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Без скидки",
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6.0),
            child: Text(
              "Расположение",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.listing.location,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 3),
        ],
      ),
    );
  }

  Widget _buildAboutApartmentCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Padding(
            padding: EdgeInsets.only(top: 6.0),
            child: Text(
              "О квартире",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 8),
          _InfoRow(title: "Количество комнат: ", value: "3"),
          _InfoRow(title: "Общая площадь: ", value: "125.5 м²"),
          _InfoRow(title: "Площадь кухни: ", value: "14.5 м²"),
          _InfoRow(title: "Жилая площадь: ", value: "64.5 м²"),
          _InfoRow(title: "Этаж: ", value: "5 из 17"),
          _InfoRow(title: "Балкон / лоджия: ", value: "балкон, лоджия"),
          _InfoRow(title: "Дополнительно: ", value: "гардеробная"),
          _InfoRow(title: "Тип комнат: ", value: "изолированные"),
          SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Все характеристики ›",
              style: TextStyle(color: Colors.blue, fontSize: 14),
            ),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return _card(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 6),
          Text(
            "Описание",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Объявление от coбcтвeнника! Предлагaю сoбствeнную пpоcтopную ceмeйную квapтиpу нa тихой улице в престижнoм pайоне Mосквы.Глaвнoe дocтoинcтвo квартиры - cочeтание проcторa и уюта. В квaртире нeт золoтыx унитазов, джакузи c пилонoм ...",
            style: TextStyle(color: Colors.white, fontSize: 14),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 8),
          Text(
            "Все описание ›",
            style: TextStyle(color: Colors.blue, fontSize: 14),
          ),
          SizedBox(height: 2),
        ],
      ),
    );
  }

  Widget _buildSellerCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 6),
          Text(
            "Продавец",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 15),
          Row(
            children: [
              const CircleAvatar(
                radius: 35.5,
                backgroundImage: AssetImage(
                  "assets/property_details_screen/Andrey.png",
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Андрей Коломойский",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "На LIDLE с 2024г.",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Row(
                      children: [
                        Text(
                          "Оценка:   ⭐ ",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        Text(
                          "4",
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 27),
          _AllListingsButton(similarListings: _similarListings),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildComplaintButton() {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return const ComplaintDialog();
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Text(
            "Пожаловаться на объявление",
            style: TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionButtons() {
    return Container(
      padding: const EdgeInsets.only(left: 25, right: 25, bottom: 50),
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return const PhoneDialog(
                      phoneNumbers: ["+7 949 456 56 67", "+7 949 433 33 98"],
                    );
                  },
                );
              },
              child: Container(
                height: 43,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    "Позвонить",
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 43,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  "Написать",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  

  static Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.only(left: 9, right: 9, top: 8, bottom: 14),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      child: child,
    );
  }


}


class _InfoRow extends StatelessWidget {
  final String title;
  final String value;

  const _InfoRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _OfferPriceButton extends StatelessWidget {
  const _OfferPriceButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return const OfferPriceDialog();
          },
        );
      },
      child: Container(
        height: 47,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: activeIconColor),
        ),
        child: const Center(
          child: Text(
            "Предложить свою цену",
            style: TextStyle(
              color: activeIconColor,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _AllListingsButton extends StatelessWidget {
  final List<Listing> similarListings;

  const _AllListingsButton({required this.similarListings});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SellerProfileScreen(
              sellerName: "Андрей Коломойский", 
              sellerAvatar: const AssetImage(
                "assets/property_details_screen/Andrey.png",
              ),
              sellerListings: similarListings
                  .map(
                    (listing) => {
                      "id": listing.id,
                      "image": listing.imagePath,
                      "title": listing.title,
                      "price": listing.price,
                      "address": listing.location,
                      "date": listing.date,
                      "isFavorited": listing.isFavorited,
                    },
                  )
                  .toList(), 
            ),
          ),
        );
      },
      child: Container(
        height: 47,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: activeIconColor),
        ),
        child: const Center(
          child: Text(
            "Все объявления продавца",
            style: TextStyle(
              color: activeIconColor,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _SimilarOfferCard extends StatefulWidget {
  final Listing listing;

  const _SimilarOfferCard({required this.listing});

  @override
  State<_SimilarOfferCard> createState() => _SimilarOfferCardState();
}

class _SimilarOfferCardState extends State<_SimilarOfferCard> {
  bool _isFavorited = false;

  @override
  void initState() {
    super.initState();
    
    _isFavorited = HiveService.isFavorite(widget.listing.id);
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorited = HiveService.toggleFavorite(widget.listing.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      decoration: const BoxDecoration(color: primaryBackground),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            child: Image.asset(
              widget.listing.imagePath,
              height: 159,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.listing.title,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _toggleFavorite,
                      child: _isFavorited
                          ? SvgPicture.asset(
                              'assets/profile_dashboard/heart-rounded.svg',
                              colorFilter: const ColorFilter.mode(
                                Colors.red, 
                                BlendMode.srcIn,
                              ),
                              width: 20,
                              height: 20,
                            )
                          : Image.asset(
                              'assets/BottomNavigation/heart-rounded.png',
                              color:
                                  Colors.white70, 
                              colorBlendMode: BlendMode.srcIn,
                              width: 20,
                              height: 20,
                            ),
                    ),
                    const SizedBox(
                      width: 5,
                    ), 
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.listing.price,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.listing.location,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.listing.date,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
