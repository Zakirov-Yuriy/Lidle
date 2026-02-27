import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/blocs/listings/listings_bloc.dart';
import 'package:lidle/blocs/listings/listings_event.dart';
import 'package:lidle/blocs/listings/listings_state.dart';

// ============================================================
// "Полный экран деталей недвижимости для моих объявлений"
// ============================================================

class MyListingsPropertyDetailsScreen extends StatefulWidget {
  final Listing listing;

  const MyListingsPropertyDetailsScreen({super.key, required this.listing});

  @override
  State<MyListingsPropertyDetailsScreen> createState() =>
      _MyListingsPropertyDetailsScreenState();
}

class _MyListingsPropertyDetailsScreenState
    extends State<MyListingsPropertyDetailsScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _showFullDescription = false;
  bool _showAllCharacteristics = false;
  bool _isAdvertLoaded = false;
  bool _imagesPrecached = false;

  late Listing _listing;

  final List<Listing> _similarListings = [];

  @override
  void initState() {
    super.initState();
    _listing = widget.listing;
    // print();

    // DEBUG логирование
    // print('[DEBUG] initState - проверка полноты данных:');
    // print();
    // print();
    // print();

    // Проверяем, есть ли полные данные (описание, характеристики, информация о продавце)
    final hasCompleteData =
        (_listing.description != null && _listing.description!.isNotEmpty) &&
        (_listing.characteristics.isNotEmpty) &&
        (_listing.sellerName != null && _listing.sellerName!.isNotEmpty);

    // print('[DEBUG] hasCompleteData: $hasCompleteData');
    if (!hasCompleteData) {
      // print();
      context.read<ListingsBloc>().add(LoadAdvertEvent(advertId: _listing.id));
    } else {
      // print();
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

  /// Precache all images to ensure smooth scrolling
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
              // print('Timeout loading image: $imageUrl');
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
              // print('Timeout loading asset image: $imageUrl');
            },
          ),
        );
      }
    }

    try {
      await Future.wait(precacheFutures, eagerError: false);
      // print('Successfully precached ${images.length} images');
    } catch (e) {
      // print('Error precaching images: $e');
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
        // print('BlocListener in MyListingsPropertyDetailsScreen: $state');
        if (state is AdvertLoaded) {
          // print();
          setState(() {
            _isAdvertLoaded = true;
            // Всегда обновляем все данные: описание, характеристики, информацию о продавце
            if (state.listing.images.isNotEmpty) {
              // API вернул изображения, используем их
              _listing = state.listing;
            } else {
              // API вернул пустые изображения, сохраняем исходные, но обновляем остальные данные
              _listing = Listing(
                id: state.listing.id,
                imagePath: state.listing.imagePath,
                images: _listing.images.isNotEmpty
                    ? _listing.images
                    : state.listing.images,
                title: state.listing.title,
                price: state.listing.price,
                location: state.listing.location,
                date: state.listing.date,
                isFavorited: state.listing.isFavorited,
                sellerName: state.listing.sellerName ?? _listing.sellerName,
                sellerAvatar:
                    state.listing.sellerAvatar ?? _listing.sellerAvatar,
                sellerRegistrationDate:
                    state.listing.sellerRegistrationDate ??
                    _listing.sellerRegistrationDate,
                description: state.listing.description ?? _listing.description,
                characteristics: state.listing.characteristics.isNotEmpty
                    ? state.listing.characteristics
                    : _listing.characteristics,
                userId: state.listing.userId ?? _listing.userId,
              );
            }
            // print('✅ _listing updated:');
            // print('  - Title: ${_listing.title}');
            // print();
            // print('  - Seller: ${_listing.sellerName}');
            // print();
          });
          // Precache images after loading the advert
          _precacheImages();
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
                        GestureDetector(
                          onTap: () {},
                          child: SvgPicture.asset(
                            'assets/home_page/share_outlined.svg',
                            colorFilter: const ColorFilter.mode(
                              textPrimary,
                              BlendMode.srcIn,
                            ),
                            width: 24,
                            height: 24,
                          ),
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
                      ],
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

  Widget _buildImageCarousel() {
    if (!_isAdvertLoaded) {
      return Shimmer.fromColors(
        baseColor: const Color(0xFF374B5C),
        highlightColor: const Color(0xFF4A5C6A),
        child: Container(height: 260, color: const Color(0xFF374B5C)),
      );
    }

    // print('Listing ${_listing.id} has ${_listing.images.length} images');
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
                (index) => images[index].startsWith('http')
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
        color: isActive
            ? Colors.blue
            : primaryBackground.withValues(alpha: 0.5),
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
                _listing.date,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Text(
                '№ ${_listing.id}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _listing.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _listing.price,
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
            _listing.location,
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
    // print('[DEBUG] Характеристики в карточке:');
    // print('  - Всего характеристик: ${chars.length}');
    // print('  - Keys: ${chars.keys.toList()}');
    // chars.forEach((k, v) => print('  $k: $v (type: ${v.runtimeType})'));

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

    // Количество строк, показываемых в свёрнутом состоянии
    const int _collapsedCount = 8;
    final bool hasMore = charWidgets.length > _collapsedCount;
    final visibleWidgets = _showAllCharacteristics
        ? charWidgets
        : charWidgets.take(_collapsedCount).toList();

    // print();

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
          else ...[
            ...visibleWidgets,
            if (hasMore) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showAllCharacteristics = !_showAllCharacteristics;
                  });
                },
                child: Row(
                  children: [
                    Text(
                      _showAllCharacteristics
                          ? "Свернуть характеристики"
                          : "Все характеристики",
                      style: const TextStyle(color: Colors.blue, fontSize: 14),
                    ),
                    Icon(
                      _showAllCharacteristics
                          ? Icons.keyboard_arrow_up_sharp
                          : Icons.keyboard_arrow_down_sharp,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    final String? descriptionText = _listing.description;

    // DEBUG логирование
    // print('[DEBUG] _buildDescriptionCard called:');
    // print();
    // print('  - isEmpty: ${descriptionText?.isEmpty ?? true}');

    // Проверяем, нужно ли показывать кнопку раскрытия
    // Показываем кнопку только если текст достаточно длинный (больше 200 символов)
    final bool hasLongDescription =
        descriptionText != null &&
        descriptionText.isNotEmpty &&
        descriptionText.length > 200;

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
          if (descriptionText == null || descriptionText.isEmpty)
            const Text(
              "Описание отсутствует",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            )
          else ...[
            // Используем AnimatedCrossFade для плавного раскрытия/сворачивания
            AnimatedCrossFade(
              firstChild: Text(
                descriptionText,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
              secondChild: Text(
                descriptionText,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              crossFadeState: _showFullDescription
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
            if (hasLongDescription) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showFullDescription = !_showFullDescription;
                  });
                },
                child: Row(
                  children: [
                    Text(
                      _showFullDescription
                          ? "Свернуть описание"
                          : "Все описание",
                      style: const TextStyle(color: Colors.blue, fontSize: 14),
                    ),
                    Icon(
                      _showFullDescription
                          ? Icons.keyboard_arrow_up_sharp
                          : Icons.keyboard_arrow_down_sharp,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
            ],
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

    // DEBUG логирование
    // print('[DEBUG] _buildSellerCard called:');
    // print('  - sellerName (from listing): ${_listing.sellerName ?? "null"}');
    // print();
    // print();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          const Text(
            "Продавец",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 15),
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
                    const SizedBox(height: 4),
                    Text(
                      "На LIDLE с $sellerRegDate",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const Row(
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
          const _AllListingsButton(),
          const SizedBox(height: 18),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              softWrap: true,
            ),
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
    return Container(
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
    );
  }
}

class _AllListingsButton extends StatelessWidget {
  const _AllListingsButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 47,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: activeIconColor),
      ),
      child: const Center(
        child: Text(
          "Все обьявления продавца",
          style: TextStyle(
            color: activeIconColor,
            fontSize: 14,
            fontWeight: FontWeight.w400,
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
