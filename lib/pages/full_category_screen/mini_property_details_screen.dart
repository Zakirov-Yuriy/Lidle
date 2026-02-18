import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/models/advert_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/blocs/listings/listings_bloc.dart';
import 'package:lidle/blocs/listings/listings_event.dart';
import 'package:lidle/blocs/listings/listings_state.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/dialogs/offer_price_dialog.dart';
import 'package:lidle/widgets/dialogs/complaint_dialog.dart';
import 'package:lidle/widgets/dialogs/phone_dialog.dart';
import 'package:lidle/pages/full_category_screen/seller_profile_screen.dart';
import 'package:lidle/pages/full_category_screen/property_gallery_screen.dart';

// ============================================================
// "Мини-экран деталей недвижимости"
// ============================================================

class MiniPropertyDetailsScreen extends StatefulWidget {
  final Listing listing;

  const MiniPropertyDetailsScreen({super.key, required this.listing});

  @override
  State<MiniPropertyDetailsScreen> createState() =>
      _MiniPropertyDetailsScreenState();
}

class _MiniPropertyDetailsScreenState extends State<MiniPropertyDetailsScreen> {
  bool _showFullDescription = false;
  bool _showAllCharacteristics = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isAdvertLoaded = false;
  bool _imagesPrecached = false;
  bool _isSimilarListingsLoading = false;
  Listing _listing = Listing(
    id: '',
    imagePath: '',
    title: '',
    price: '',
    location: '',
    date: '',
  );

  List<Listing> _similarListings = [
    Listing(
      id: '1',
      imagePath: "assets/property_details_screen/image2.png",
      images: [
        "assets/property_details_screen/image2.png",
        "assets/property_details_screen/image3.png",
        "assets/property_details_screen/image4.png",
      ],
      title: "1-к. квартира, 33 м²",
      price: "44 500 000 ₽",
      location: "Москва, Истринская ул, 8к3",
      date: "09.08.2024",
      isFavorited: false,
    ),
    Listing(
      id: '2',
      imagePath: "assets/property_details_screen/image3.png",
      images: [
        "assets/property_details_screen/image3.png",
        "assets/property_details_screen/image5.png",
      ],
      title: "2-к. квартира, 65,5 м² ",
      price: "21 000 000 ₽",
      location: "Москва, ул. Коминтерна, 4",
      date: "12.04.2024",
      isFavorited: false,
    ),
    Listing(
      id: '3',
      imagePath: "assets/property_details_screen/image4.png",
      images: ["assets/property_details_screen/image4.png"],
      title: "5-к. квартира, 111 м²",
      price: "21 000 000 ₽",
      location: "Москва, ул. Коминтерна, 4",
      date: "11.08.2024",
      isFavorited: false,
    ),
    Listing(
      id: '4',
      imagePath: "assets/property_details_screen/image5.png",
      images: [
        "assets/property_details_screen/image5.png",
        "assets/property_details_screen/image7.png",
      ],
      title: "1-к. квартира, 30 м² ...",
      price: "21 000 000 ₽",
      location: "Москва, ул. Коминтерна, 4",
      date: "12.04.2024",
      isFavorited: false,
    ),
    Listing(
      id: '5',
      imagePath: "assets/property_details_screen/image4.png",
      images: [
        "assets/property_details_screen/image4.png",
        "assets/property_details_screen/image8.png",
      ],
      title: "5-к. квартира, 111 м²",
      price: "21 000 000 ₽",
      location: "Москва, ул. Коминтерна, 4",
      date: "11.08.2024",
      isFavorited: false,
    ),
    Listing(
      id: '6',
      imagePath: "assets/property_details_screen/image5.png",
      images: ["assets/property_details_screen/image5.png"],
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
    _listing = widget.listing;
    _imagesPrecached = false;
    print(
      'MiniPropertyDetailsScreen init: listing id ${_listing.id}, images ${_listing.images.length}',
    );

    // 🔄 Загружаем полное объявление, если:
    // 1. Нет изображений (значит это базовые данные со списка)
    // 2. Нет достаточно информации для отображения
    // Если объявление уже полностью загружено, не загружаем повторно
    if (_listing.images.isEmpty) {
      print('📥 MiniPropertyDetailsScreen: Загружаем полные данные объявления');
      _isAdvertLoaded = false;
      context.read<ListingsBloc>().add(LoadAdvertEvent(advertId: _listing.id));
    } else {
      print('✅ MiniPropertyDetailsScreen: Используем уже загруженные данные');
      _isAdvertLoaded = true;
    }

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

  /// Загружает похожие объявления из API (объявления из первого каталога)
  Future<void> _loadSimilarListings() async {
    if (_isSimilarListingsLoading) return;

    setState(() {
      _isSimilarListingsLoading = true;
    });

    try {
      final token = HiveService.getUserData('token') as String?;
      if (token == null) {
        print('❌ Токен не найден для загрузки похожих объявлений');
        return;
      }

      // 📥 Загружаем объявления из каталога (первые 20)
      final response = await ApiService.getAdverts(
        catalogId: 1, // Основной каталог
        limit: 20,
        token: token,
      );

      if (mounted) {
        setState(() {
          _similarListings = response.data
              .take(12) // Берём первые 12 для отображения в сетке
              .map((advert) => advert.toListing())
              .toList();
          _isSimilarListingsLoading = false;
        });

        print('✅ Загружены похожие объявления: ${_similarListings.length} шт.');
      }
    } catch (e) {
      print('❌ Ошибка при загрузке похожих объявлений: $e');
      if (mounted) {
        setState(() {
          _isSimilarListingsLoading = false;
        });
      }
    }
  }

  // Precache all images to ensure smooth scrolling
  Future<void> _precacheImages() async {
    if (_imagesPrecached || !mounted) return;

    final images = _listing.images.isNotEmpty
        ? _listing.images
        : [_listing.imagePath];
    final precacheFutures = <Future<void>>[];

    for (final imageUrl in images) {
      if (imageUrl.isEmpty) continue;

      if (imageUrl.startsWith('http')) {
        // Precache network images with timeout
        precacheFutures.add(
          precacheImage(
            NetworkImage(imageUrl),
            context,
            size: const Size(400, 260),
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print('Timeout loading image: $imageUrl');
            },
          ),
        );
      } else {
        // Precache asset images
        precacheFutures.add(
          precacheImage(
            AssetImage(imageUrl),
            context,
            size: const Size(400, 260),
          ).timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              print('Timeout loading asset image: $imageUrl');
            },
          ),
        );
      }
    }

    try {
      await Future.wait(precacheFutures, eagerError: false);
      print('Successfully precached ${images.length} images');
    } catch (e) {
      print('Error precaching images: $e');
    }

    if (mounted) {
      setState(() {
        _imagesPrecached = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ListingsBloc, ListingsState>(
      listener: (context, state) {
        print('BlocListener in MiniPropertyDetailsScreen: $state');
        if (state is AdvertLoaded) {
          print(
            'Updating _listing to ${state.listing.id} with ${state.listing.images.length} images',
          );
          setState(() {
            _isAdvertLoaded = true;
            if (state.listing.images.isNotEmpty) {
              // Use the new images from API
              _listing = state.listing;
            } else {
              // API returned empty images, keep the initial images but update other data
              _listing = Listing(
                id: state.listing.id,
                imagePath: state.listing.imagePath,
                images: _listing.images, // Keep initial images
                title: state.listing.title,
                price: state.listing.price,
                location: state.listing.location,
                date: state.listing.date,
                isFavorited: state.listing.isFavorited,
                sellerName: state.listing.sellerName,
                sellerAvatar: state.listing.sellerAvatar,
                sellerRegistrationDate: state.listing.sellerRegistrationDate,
              );
            }
          });
          // Precache images after loading the advert
          _precacheImages();

          // 🔄 Загружаем похожие объявления из API
          _loadSimilarListings();
        }
      },
      child: Scaffold(
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
                          child: Row(
                            children: [
                              const Icon(
                                Icons.arrow_back_ios,
                                color: activeIconColor,
                                size: 16,
                              ),
                              const SizedBox(
                                width: 4,
                              ), // Небольшой отступ между иконкой и текстом
                              const Text(
                                'Назад',
                                style: TextStyle(
                                  color: activeIconColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.share_outlined,
                            color: textPrimary,
                          ),
                          onPressed: () {
                            final textToShare =
                                '''
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
                      padding: const EdgeInsets.only(
                        right: 25,
                        left: 25,
                        top: 20,
                      ),
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
                        const SizedBox(height: 85),
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
      ),
    );
  }

  Widget _buildImageCarousel() {
    if (!_isAdvertLoaded) {
      return Shimmer.fromColors(
        baseColor: const Color(0xFF374B5C),
        highlightColor: const Color(0xFF4A5C6A),
        child: Container(height: 260, color: const Color(0xFF374B5C)),
      );
    }

    print('Listing ${_listing.id} has ${_listing.images.length} images');
    final images = _listing.images.isNotEmpty
        ? _listing.images
        : [_listing.imagePath];

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Container(
            height: 260,
            color: const Color(0xFF374B5C),
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: List.generate(
                images.length,
                (index) => GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PropertyGalleryScreen(
                          images: images,
                          initialIndex: _currentPage,
                        ),
                      ),
                    );
                  },
                  child: images[index].startsWith('http')
                      ? Image.network(
                          images[index],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: const Color(0xFF374B5C),
                              child: const Center(
                                child: SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFF374B5C),
                              child: Icon(
                                Icons.image,
                                color: textMuted,
                                size: 50,
                              ),
                            );
                          },
                        )
                      : Image.asset(
                          images[index],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFF374B5C),
                              child: Icon(
                                Icons.image,
                                color: textMuted,
                                size: 50,
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            images.length,
            (index) => _buildPageIndicator(index == _currentPage),
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 5.0),
      height: 11.0,
      width: 11.0,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Colors.blue : primaryBackground.withOpacity(0.5),
        border: Border.all(color: Colors.grey, width: 1.0),
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
    final Map<String, dynamic> chars = _listing.characteristics;
    // DEBUG: Выводим характеристики в консоль для отладки
    print('[DEBUG] Характеристики в карточке:');
    chars.forEach((k, v) => print('  $k: $v'));

    // Формируем список виджетов для отображения характеристик
    final List<Widget> charWidgets = [];
    chars.forEach((key, charData) {
      if (charData is Map<String, dynamic>) {
        final title = charData['title'] as String? ?? 'Характеристика';
        final value = charData['value'];
        final maxValue = charData['max_value'];

        String displayValue = '-';
        if (value is Map && value.containsKey('value')) {
          // Случай: {"value": ..., "max_value": ...}
          displayValue = value['value'].toString();
          if (value.containsKey('max_value')) {
            displayValue += ' — ' + value['max_value'].toString();
          }
        } else if (maxValue != null) {
          // Диапазон: value и max_value на разных уровнях
          displayValue = value.toString() + ' — ' + maxValue.toString();
        } else if (value is bool) {
          displayValue = value ? 'Да' : 'Нет';
        } else if (value is num) {
          displayValue = value.toString();
        } else if (value is String) {
          displayValue = value;
        } else if (value is List) {
          // Если value это список
          displayValue = (value as List).join(', ');
        }
        charWidgets.add(_InfoRow(title: '$title: ', value: displayValue));
      }
    });

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
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
          const SizedBox(height: 8),
          if (charWidgets.isEmpty)
            const Text(
              "Нет данных о характеристиках",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...charWidgets,
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    final String? descriptionText = _listing.description;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          const Text(
            "Описание",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (descriptionText != null && descriptionText.isNotEmpty)
            Text(
              descriptionText,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: _showFullDescription ? null : 6,
              overflow: _showFullDescription
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            )
          else
            const Text(
              "Описание отсутствует",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          const SizedBox(height: 8),
          if (_showFullDescription &&
              descriptionText != null &&
              descriptionText.isNotEmpty) ...[
            GestureDetector(
              onTap: () {
                setState(() {
                  _showFullDescription = false;
                });
              },
              child: Row(
                children: const [
                  Text(
                    "Свернуть описание",
                    style: TextStyle(color: Colors.blue, fontSize: 14),
                  ),
                  Icon(Icons.keyboard_arrow_up_sharp, color: Colors.blue),
                ],
              ),
            ),
            const SizedBox(height: 2),
          ] else if (descriptionText != null && descriptionText.isNotEmpty) ...[
            GestureDetector(
              onTap: () {
                setState(() {
                  _showFullDescription = true;
                });
              },
              child: Row(
                children: const [
                  Text(
                    "Все описание",
                    style: TextStyle(color: Colors.blue, fontSize: 14),
                  ),
                  Icon(Icons.keyboard_arrow_down_sharp, color: Colors.blue),
                ],
              ),
            ),
            const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }

  Widget _buildSellerCard() {
    final sellerName = _listing.sellerName ?? "Имя не указано";
    final sellerAvatar =
        _listing.sellerAvatar ?? "assets/property_details_screen/Andrey.png";
    final sellerRegDate = _listing.sellerRegistrationDate ?? "2024г.";

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
              sellerAvatar.startsWith('http')
                  ? CircleAvatar(
                      radius: 35.5,
                      backgroundImage: NetworkImage(sellerAvatar),
                      onBackgroundImageError: (exception, stackTrace) {
                        // Fallback to asset image on error
                      },
                    )
                  : CircleAvatar(
                      radius: 35.5,
                      backgroundImage: AssetImage(sellerAvatar),
                    ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sellerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "На LIDLE с $sellerRegDate",
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
          _AllListingsButton(
            similarListings: _similarListings,
            sellerName: sellerName,
            sellerAvatar: sellerAvatar,
            userId: _listing.userId,
          ),
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
                  color: Color(0xFF19D849),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    "Позвонить",
                    style: TextStyle(color: Colors.white, fontSize: 16),
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
  final String sellerName;
  final String sellerAvatar;
  final String? userId;

  const _AllListingsButton({
    required this.similarListings,
    required this.sellerName,
    required this.sellerAvatar,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Создаем ImageProvider в зависимости от типа URL
        ImageProvider avatarProvider;
        if (sellerAvatar.startsWith('http')) {
          avatarProvider = NetworkImage(sellerAvatar);
        } else {
          avatarProvider = AssetImage(sellerAvatar);
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SellerProfileScreen(
              sellerName: sellerName,
              sellerAvatar: avatarProvider,
              userId: userId,
              sellerListings: similarListings
                  .map((listing) => listing.toJson())
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
            child: widget.listing.imagePath.startsWith('http')
                ? Image.network(
                    widget.listing.imagePath,
                    height: 159,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFF374B5C),
                        child: Icon(Icons.image, color: textMuted, size: 40),
                      );
                    },
                  )
                : Image.asset(
                    widget.listing.imagePath,
                    height: 159,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFF374B5C),
                        child: Icon(Icons.image, color: textMuted, size: 40),
                      );
                    },
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
                              color: Colors.white70,
                              colorBlendMode: BlendMode.srcIn,
                              width: 20,
                              height: 20,
                            ),
                    ),
                    const SizedBox(width: 5),
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
