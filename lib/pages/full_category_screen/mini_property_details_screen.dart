import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/services/favorites_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/models/advert_model.dart';
import 'package:lidle/models/message_model.dart';
import 'package:lidle/models/chat_message_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/blocs/listings/listings_bloc.dart';
import 'package:lidle/blocs/listings/listings_event.dart';
import 'package:lidle/blocs/listings/listings_state.dart';
import 'package:lidle/blocs/wishlist/wishlist_bloc.dart';
import 'package:lidle/blocs/connectivity/connectivity_bloc.dart';
import 'package:lidle/blocs/connectivity/connectivity_state.dart';
import 'package:lidle/blocs/connectivity/connectivity_event.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/no_internet_screen.dart';
import 'package:lidle/widgets/dialogs/offer_price_dialog.dart';
import 'package:lidle/widgets/dialogs/complaint_dialog.dart';
import 'package:lidle/widgets/dialogs/phone_dialog.dart';
import 'package:lidle/pages/full_category_screen/seller_profile_screen.dart';
import 'package:lidle/pages/full_category_screen/property_gallery_screen.dart';
import 'package:lidle/pages/messages/chat_page.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/core/config/app_config.dart';

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
  bool _isPriceOffersLoading = false;
  List<Map<String, dynamic>> _priceOffers = [];

  Listing _listing = Listing(
    id: '',
    imagePath: '',
    title: '',
    price: '',
    location: '',
    date: '',
    isBargain: false,
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
      isBargain: true,
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
      isBargain: false,
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
      isBargain: true,
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
      isBargain: false,
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
      isBargain: true,
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
      isBargain: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _listing = widget.listing;
    _imagesPrecached = false;
    
    // 🔍 DEBUG: Логируем какие данные пришли с объявлением
    log.d('📥 MiniPropertyDetailsScreen initState:');
    log.d('  ID: ${_listing.id}');
    log.d('  Title: ${_listing.title}');
    log.d('  Images count: ${_listing.images.length}');
    log.d('  Has description: ${_listing.description?.isNotEmpty ?? false}');
    log.d('  Has characteristics: ${_listing.characteristics?.isNotEmpty ?? false}');
    log.d('  Seller name: ${_listing.sellerName ?? "EMPTY"}');
    log.d('  Seller avatar: ${_listing.sellerAvatar ?? "EMPTY"}');

    // 🔄 ВСЕГДА загружаем полное объявление если:
    // 1. Нет изображений
    // 2. Нет характеристик / описания
    // 3. Нет информации о продавце
    final needsFullLoad = _listing.images.isEmpty || 
                          (_listing.characteristics?.isEmpty ?? true) ||
                          (_listing.description?.isEmpty ?? true) ||
                          (_listing.sellerName?.isEmpty ?? true);
    
    if (needsFullLoad) {
      log.d('🔄 ТРЕБУЕТСЯ загрузка полных данных объявления');
      _isAdvertLoaded = false;
      // Добавляем задержку для стабилизации
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          context.read<ListingsBloc>().add(LoadAdvertEvent(advertId: _listing.id));
        }
      });
    } else {
      log.d('✅ Используем уже загруженные полные данные');
      _isAdvertLoaded = true;
    }

    _pageController.addListener(() {
      if (_pageController.hasClients && _pageController.page != null) {
        int next = _pageController.page!.round();
        if (_currentPage != next) {
          setState(() {
            _currentPage = next;
          });
        }
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
      final token = TokenService.currentToken;
      if (token == null) {
        // log.d('❌ Токен не найден для загрузки похожих объявлений');
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

        // log.d('✅ Загружены похожие объявления: ${_similarListings.length} шт.');
      }
    } catch (e) {
      // log.d('❌ Ошибка при загрузке похожих объявлений: $e');
      if (mounted) {
        setState(() {
          _isSimilarListingsLoading = false;
        });
      }
    }
  }

  /// 💰 Загружает предложения цены для текущего объявления
  Future<void> _loadPriceOffers() async {
    if (_isPriceOffersLoading) return;

    setState(() {
      _isPriceOffersLoading = true;
    });

    try {
      final token = TokenService.currentToken;
      if (token == null) {
        // Пользователь не авторизован - пропускаем загрузку
        return;
      }

      final advertId = int.tryParse(_listing.id);
      if (advertId == null) {
        return;
      }

      // 📥 Загружаем предложения цены из API
      // Используем slug из listing если он есть, иначе 'adverts' по умолчанию
      final advertSlug = _listing.slug?.isNotEmpty ?? false 
          ? _listing.slug! 
          : 'adverts';
      
      final offers = await ApiService.getPriceOffers(
        advertId: advertId,
        advertSlug: advertSlug,
        token: token,
      );

      if (mounted) {
        setState(() {
          _priceOffers = offers;
          _isPriceOffersLoading = false;
        });

        // log.d('✅ Загружены предложения цены: ${_priceOffers.length} шт.');
      }
    } catch (e) {
      log.d('⚠️ Ошибка при загрузке предложений цены (это нормально, если объявление не ваше): $e');
      if (mounted) {
        setState(() {
          _isPriceOffersLoading = false;
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
              // log.d('Timeout loading image: $imageUrl');
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
              // log.d('Timeout loading asset image: $imageUrl');
            },
          ),
        );
      }
    }

    try {
      await Future.wait(precacheFutures, eagerError: false);
      // log.d('Successfully precached ${images.length} images');
    } catch (e) {
      // log.d('Error precaching images: $e');
    }

    if (mounted) {
      setState(() {
        _imagesPrecached = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectivityBloc, ConnectivityState>(
      listener: (context, connectivityState) {
        // Когда интернет восстановлен - перезагружаем данные объявления
        if (connectivityState is ConnectedState) {
          // Очищаем ошибку сразу
          // ⏳ Добавляем задержку для стабилизации соединения
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              // Перезагружаем данные объявления
              // ignore: use_build_context_synchronously
              context.read<ListingsBloc>().add(LoadAdvertEvent(advertId: _listing.id));
              // Перезагружаем похожие объявления и предложения цены
              _loadSimilarListings();
              _loadPriceOffers();
            }
          });
        }
      },
      child: BlocBuilder<ConnectivityBloc, ConnectivityState>(
        builder: (context, connectivityState) {
          // Показываем экран отсутствия интернета
          if (connectivityState is DisconnectedState) {
            return NoInternetScreen(
              onRetry: () {
                context.read<ConnectivityBloc>().add(
                  const CheckConnectivityEvent(),
                );
              },
            );
          }

          // Показываем обычный контент
          return BlocListener<ListingsBloc, ListingsState>(
      listener: (context, state) {
        log.d('🔔 BlocListener state in MiniPropertyDetailsScreen: ${state.runtimeType}');
        
        if (state is AdvertLoaded) {
          log.d('✅ AdvertLoaded:');
          log.d('  - ID: ${state.listing.id}');
          log.d('  - Has description: ${state.listing.description?.isNotEmpty ?? false}');
          log.d('  - Characteristics: ${state.listing.characteristics?.keys.length ?? 0} items');
          log.d('  - Seller: ${state.listing.sellerName ?? "EMPTY"}');
          
          setState(() {
            _isAdvertLoaded = true;
            if (state.listing.images.isNotEmpty) {
              // API вернул изображения - используем их
              _listing = state.listing;
              log.d('📸 Используем изображения из API: ${state.listing.images.length} шт');
            } else {
              // API вернул пустые изображения - сохраняем старые
              _listing = Listing(
                id: state.listing.id,
                slug: state.listing.slug,
                imagePath: state.listing.imagePath,
                images: _listing.images, // Сохраняем изображения
                title: state.listing.title,
                price: state.listing.price,
                location: state.listing.location,
                date: state.listing.date,
                isFavorited: state.listing.isFavorited,
                sellerName: state.listing.sellerName,
                sellerAvatar: state.listing.sellerAvatar,
                sellerRegistrationDate: state.listing.sellerRegistrationDate,
                description: state.listing.description,
                characteristics: state.listing.characteristics,
                userId: state.listing.userId,
                isBargain: state.listing.isBargain,
              );
              log.d('📸 Сохранили изображения из предыдущих данных');
            }
            
            // ВАЖНО: Логируем что пришло от API
            if ((_listing.characteristics?.isEmpty ?? true) && 
                (_listing.description?.isEmpty ?? true)) {
              log.w('⚠️ ВНИМАНИЕ: API вернул объявление БЕЗ характеристик и описания!');
              log.w('   Это может быть ошибка при создании объявления.');
            }
          });
          
          _precacheImages();
          _loadSimilarListings();
          _loadPriceOffers();
        } else if (state is ListingsError) {
          log.e('❌ ОШИБКА загрузки объявления: ${state.message}');
          setState(() {
            _isAdvertLoaded = true;
          });
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
                    padding: const EdgeInsets.only(bottom: 00.0),
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
                          icon: SvgPicture.asset(
                            'assets/home_page/share_outlined.svg',
                            width: 24,
                            height: 24,
                            colorFilter: const ColorFilter.mode(
                              textPrimary,
                              BlendMode.srcIn,
                            ),
                          ),
                          onPressed: () {
                            final textToShare =
                                '${widget.listing.title}\n'
                                'Цена: ${widget.listing.price}\n'
                                'Адрес: ${widget.listing.location}\n\n'
                                'Присоединяйся к LIDLE!\n'
                                '${AppConfig().websiteUrl}';

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
                        top: 0,
                      ),
                      children: _isAdvertLoaded
                          ? [
                              // ✅ Основной контент (реальные данные)
                              _buildImageCarousel(),
                              const SizedBox(height: 16),
                              _buildMainInfoCard(),
                              const SizedBox(height: 16),
                              // 💰 Показываем кнопку "Предложить свою цену" 
                              // Условие: is_bargain == true ИЛИ атрибут 1048 == 1
                              if (_listing.canShowOfferButton()) ...[
                                _OfferPriceButton(
                                  advertId: _listing.id,
                                  advertSlug: _listing.slug ?? _listing.id,
                                ),
                                const SizedBox(height: 19),
                              ],
                              _buildLocationCard(),
                              const SizedBox(height: 10),
                              _buildAboutApartmentCard(),
                              const SizedBox(height: 10),
                              _buildDescriptionCard(),
                              const SizedBox(height: 24),
                              if (_priceOffers.isNotEmpty) ...[
                                _buildPriceOffersCard(),
                                const SizedBox(height: 24),
                              ],
                              _buildSellerCard(),
                              const SizedBox(height: 19),
                              _buildComplaintButton(),
                              const SizedBox(height: 85),
                            ]
                          : [
                              // 💀 Скелетоны при загрузке
                              _buildImageCarousel(),
                              const SizedBox(height: 16),
                              _buildMainInfoCardSkeleton(),
                              const SizedBox(height: 16),
                              // Skeleton кнопки
                              Shimmer.fromColors(
                                baseColor: const Color(0xFF374B5C),
                                highlightColor: const Color(0xFF4A5C6A),
                                child: Container(
                                  height: 47,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF374B5C),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 19),
                              _buildLocationCardSkeleton(),
                              const SizedBox(height: 10),
                              _buildAboutApartmentCardSkeleton(),
                              const SizedBox(height: 10),
                              _buildDescriptionCardSkeleton(),
                              const SizedBox(height: 24),
                              _buildSellerCardSkeleton(),
                              const SizedBox(height: 19),
                              // Skeleton кнопки жалобы
                              Shimmer.fromColors(
                                baseColor: const Color(0xFF374B5C),
                                highlightColor: const Color(0xFF4A5C6A),
                                child: Container(
                                  height: 43,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF374B5C),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.red),
                                  ),
                                ),
                              ),
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
        },
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

    // Безопасный парсинг изображений: images + imagePath
    final List<String> images = _listing.images.isNotEmpty
        ? _listing.images
        : (_listing.imagePath.isNotEmpty ? [_listing.imagePath] : <String>[]);

    // Если нет изображений, показываем placeholder
    if (images.isEmpty) {
      return Container(
        height: 260,
        color: const Color(0xFF374B5C),
        child: Icon(
          Icons.image_not_supported,
          color: textMuted,
          size: 50,
        ),
      );
    }

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
                          listingId: widget.listing.id,
                        ),
                      ),
                    );
                  },
                  child: _buildImageWidget(images[index]),
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

  /// Вспомогательный метод для безопасного отображения изображения
  /// Поддерживает network images, assets и валидирует пустые пути
  Widget _buildImageWidget(String imagePath) {
    if (imagePath.isEmpty) {
      return Container(
        color: const Color(0xFF374B5C),
        child: Icon(
          Icons.image_not_supported,
          color: textMuted,
          size: 50,
        ),
      );
    }

    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
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
      );
    } else {
      return Image.asset(
        imagePath,
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
      );
    }
  }

  /// Вспомогательный метод для безопасного отображения аватара продавца
  /// Поддерживает: сетевые изображения (PNG, JPG), локальные ассеты и SVG файлы
  /// При ошибке загрузки сетевого изображения показывает дефолтную SVG аватарку
  Widget _buildSellerAvatar(String? avatarUrl) {
    final defaultAvatar = 'assets/profile_dashboard/default-photo.svg';
    
    // Если нет аватарки или URL пуст - показываем дефолтную SVG
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return _buildDefaultAvatarContainer();
    }
    
    // Для SVG файлов используем SvgPicture
    if (avatarUrl.endsWith('.svg')) {
      return Container(
        width: 71,
        height: 71,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: formBackground,
        ),
        child: ClipOval(
          child: SvgPicture.asset(
            avatarUrl,
            fit: BoxFit.cover,
            placeholderBuilder: (context) => Container(
              color: formBackground,
            ),
          ),
        ),
      );
    }
    
    // Для сетевых изображений с fallback на дефолтную аватарку
    if (avatarUrl.startsWith('http')) {
      return ClipOval(
        child: SizedBox(
          width: 71,
          height: 71,
          child: Image.network(
            avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              log.w('❌ Failed to load avatar from: $avatarUrl, using default');
              return _buildDefaultAvatarContainer();
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: formBackground,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.grey.shade600,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    
    // Для локальных растровых изображений (PNG, JPG)
    return ClipOval(
      child: SizedBox(
        width: 71,
        height: 71,
        child: Image.asset(
          avatarUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            log.w('❌ Failed to load local avatar from: $avatarUrl, using default');
            return _buildDefaultAvatarContainer();
          },
        ),
      ),
    );
  }

  /// Вспомогательный метод для отображения дефолтной аватарки
  Widget _buildDefaultAvatarContainer() {
    const defaultAvatar = 'assets/profile_dashboard/default-photo.svg';
    return Container(
      width: 71,
      height: 71,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: formBackground,
      ),
      child: ClipOval(
        child: SvgPicture.asset(
          defaultAvatar,
          fit: BoxFit.cover,
          placeholderBuilder: (context) => Container(
            color: formBackground,
          ),
        ),
      ),
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
                '№ ${widget.listing.id}',
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
          // const SizedBox(height: 4),
          // const Text(
          //   "354 582 ₽ за м²",
          //   style: TextStyle(
          //     color: Colors.white70,
          //     fontSize: 13,
          //     fontWeight: FontWeight.w500,
          //   ),
          // ),
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
    // Безопасно получаем характеристики
    final Map<String, dynamic> chars = _listing.characteristics ?? {};
    
    // DEBUG: Выводим характеристики в консоль для отладки
    // log.d('[DEBUG] Характеристики в карточке:');
    // chars.forEach((k, v) => log.d('  $k: $v'));

    // Формируем список виджетов для отображения характеристик
    final List<Widget> charWidgets = [];
    
    // Проверяем что chars не пусто
    if (chars.isNotEmpty) {
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
            displayValue = value.join(', ');
          }
          charWidgets.add(_InfoRow(title: '$title: ', value: displayValue));
        }
      });
    }

    // Количество строк, показываемых в свёрнутом состоянии
    const int _collapsedCount = 8;
    final bool hasMore = charWidgets.length > _collapsedCount;
    final visibleWidgets = _showAllCharacteristics
        ? charWidgets
        : charWidgets.take(_collapsedCount).toList();

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
          const Padding(
            padding: EdgeInsets.only(top: 6.0),
            child: Text(
              "Описание",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
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
              const SizedBox(height: 6),
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

  /// 💰 Карточка с предложениями цены от других пользователей
  Widget _buildPriceOffersCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6.0),
            child: Text(
              "Предложения цены",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_priceOffers.isEmpty)
            const Text(
              "Нет предложений цены",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _priceOffers.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: Colors.white24, height: 16),
              itemBuilder: (context, index) {
                final offer = _priceOffers[index];
                final user = offer['user'] as Map<String, dynamic>? ?? {};
                final userName =
                    user['name'] as String? ?? 'Неизвестный пользователь';
                final userAvatar = user['avatar'] as String?;
                final price = offer['price'] as String? ?? '-';
                final message = offer['message'] as String? ?? '';
                final createdAt = offer['created_at'] as String? ?? '';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Аватар пользователя
                        if (userAvatar != null && userAvatar.isNotEmpty)
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: userAvatar.startsWith('http')
                                ? NetworkImage(userAvatar)
                                : AssetImage(userAvatar) as ImageProvider,
                          )
                        else
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                        const SizedBox(width: 12),
                        // Информация о пользователе и цене
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                createdAt,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Цена предложения
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₽ $price',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Предложение',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Сообщение пользователя
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSellerCard() {
    // 📝 Парсим полное имя продавца - берем только первое слово (имя)
    final fullSellerName = _listing.sellerName ?? "Имя не указано";
    final nameParts = fullSellerName.trim().split(RegExp(r'\s+'));
    final sellerName = nameParts.isNotEmpty ? nameParts.first : fullSellerName;
    
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
              _buildSellerAvatar(sellerAvatar),
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
        // Проверяем авторизацию перед открытием диалога жалобы
        final token = TokenService.currentToken;
        if (token == null || token.isEmpty) {
          SnackBarHelper.showAuthRequired(
            context,
            'Чтобы пожаловаться на объявление, войдите в свой профиль или создайте новый',
          );
          return;
        }
        
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
              onTap: _loadAndShowPhoneDialog,
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
            child: GestureDetector(
              onTap: _openChatWithSeller,
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
          ),
        ],
      ),
    );
  }

  /// 📞 Загрузить номера телефонов владельца объявления и показать диалог
  Future<void> _loadAndShowPhoneDialog() async {
    // Проверяем авторизацию перед загрузкой номеров
    final token = TokenService.currentToken;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      SnackBarHelper.showAuthRequired(
        context,
        'Чтобы позвонить продавцу, войдите в свой профиль или создайте новый',
      );
      return;
    }
    
    // Проверяем, есть ли userId (sellerId)
    final userId = _listing.userId;
    if (userId == null || userId.isEmpty) {
      // Если нет userId, показываем заглушку с сообщением об ошибке
      if (!mounted) return;
      SnackBarHelper.showWarning(context, 'Информация о продавце недоступна');
      return;
    }

    // Показываем индикатор загрузки
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => Dialog(
        backgroundColor: primaryBackground,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          decoration: BoxDecoration(
            color: primaryBackground,
            borderRadius: BorderRadius.circular(5),
          ),
          padding: const EdgeInsets.all(25.0),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 20),
              CircularProgressIndicator(color: Color(0xFF19D849)),
              SizedBox(height: 20),
              Text(
                'Загрузка номеров...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );

    try {
      // Получаем телефоны из API
      log.d('📞 Loading phones for seller ID: $userId');
      
      // Безопасный парсинг userId
      final userIdInt = int.tryParse(userId);
      if (userIdInt == null) {
        if (!mounted) return;
        SnackBarHelper.showError(context, 'Некорректный ID продавца');
        Navigator.of(context).pop();
        return;
      }
      
      final phoneNumbers = await ApiService.getUserPhones(
        userId: userIdInt,
      );

      // Закрываем диалог загрузки
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Если телефонов нет
      if (phoneNumbers.isEmpty) {
        if (!mounted) return;
        SnackBarHelper.showInfo(context, 'Номера телефонов не найдены');
        return;
      }

      // Показываем диалог с телефонами
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return PhoneDialog(phoneNumbers: phoneNumbers);
        },
      );
    } catch (e) {
      log.d('❌ Error loading phone numbers: $e');

      // Закрываем диалог загрузки
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Показываем ошибку
      if (!mounted) return;
      SnackBarHelper.showError(context, 'Ошибка загрузки номеров: $e');
    }
  }

  /// 💬 Открыть чат с продавцом объявления
  Future<void> _openChatWithSeller() async {
    // Проверяем авторизацию перед открытием чата
    final token = TokenService.currentToken;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      SnackBarHelper.showAuthRequired(
        context,
        'Чтобы связаться с этим продавцом, войдите в свой профиль или создайте новый',
      );
      return;
    }
    
    // Проверяем, есть ли информация о продавце
    final sellerName = _listing.sellerName;
    final userId = _listing.userId;
    if (sellerName == null || sellerName.isEmpty || userId == null || userId.isEmpty) {
      if (!mounted) return;
      SnackBarHelper.showWarning(context, 'Информация о продавце недоступна');
      return;
    }

    if (!mounted) return;
    
    // Создаем объект Message с информацией о продавце
    final message = Message(
      senderName: sellerName,
      senderAvatar: _listing.sellerAvatar,
      lastMessageTime: 'сейчас',
      unreadCount: 0,
      isInternal: true,
      isCompany: false,
      userId: userId,
      advertTitle: _listing.title,
      // Используем первую картинку из списка изображений, если она доступна
      advertImage: _listing.images.isNotEmpty ? _listing.images.first : _listing.imagePath,
      advertPrice: _listing.price,
      advertisementId: _listing.id,
    );

    // Переходим на экран чата с флагом что открыт с экрана объявления
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          message: message,
          openedFromAdvertScreen: true,
          initialListing: _listing, // ✅ Передаем объявление для отправки как сообщение
        ),
      ),
    );
  }

  /// 💀 Skeleton loaders для компонентов экрана во время загрузки
  Widget _buildMainInfoCardSkeleton() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Дата и номер
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Shimmer.fromColors(
                baseColor: const Color(0xFF374B5C),
                highlightColor: const Color(0xFF4A5C6A),
                child: Container(
                  height: 13,
                  width: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF374B5C),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Shimmer.fromColors(
                baseColor: const Color(0xFF374B5C),
                highlightColor: const Color(0xFF4A5C6A),
                child: Container(
                  height: 13,
                  width: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF374B5C),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Заголовок
          Shimmer.fromColors(
            baseColor: const Color(0xFF374B5C),
            highlightColor: const Color(0xFF4A5C6A),
            child: Container(
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF374B5C),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Цена
          Shimmer.fromColors(
            baseColor: const Color(0xFF374B5C),
            highlightColor: const Color(0xFF4A5C6A),
            child: Container(
              height: 22,
              width: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF374B5C),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Цена за м²
          Shimmer.fromColors(
            baseColor: const Color(0xFF374B5C),
            highlightColor: const Color(0xFF4A5C6A),
            child: Container(
              height: 13,
              width: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF374B5C),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Без скидки
          Shimmer.fromColors(
            baseColor: const Color(0xFF374B5C),
            highlightColor: const Color(0xFF4A5C6A),
            child: Container(
              height: 12,
              width: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF374B5C),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCardSkeleton() {
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
          Shimmer.fromColors(
            baseColor: const Color(0xFF374B5C),
            highlightColor: const Color(0xFF4A5C6A),
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF374B5C),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Shimmer.fromColors(
            baseColor: const Color(0xFF374B5C),
            highlightColor: const Color(0xFF4A5C6A),
            child: Container(
              height: 14,
              width: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF374B5C),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 3),
        ],
      ),
    );
  }

  Widget _buildAboutApartmentCardSkeleton() {
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
          // Несколько строк-скелетонов для характеристик
          ...List.generate(
            5,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Shimmer.fromColors(
                baseColor: const Color(0xFF374B5C),
                highlightColor: const Color(0xFF4A5C6A),
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF374B5C),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCardSkeleton() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6.0),
            child: Text(
              "Описание",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Несколько строк текста
          ...List.generate(
            4,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Shimmer.fromColors(
                baseColor: const Color(0xFF374B5C),
                highlightColor: const Color(0xFF4A5C6A),
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF374B5C),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerCardSkeleton() {
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
              Shimmer.fromColors(
                baseColor: const Color(0xFF374B5C),
                highlightColor: const Color(0xFF4A5C6A),
                child: Container(
                  width: 71,
                  height: 71,
                  decoration: BoxDecoration(
                    color: const Color(0xFF374B5C),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Shimmer.fromColors(
                      baseColor: const Color(0xFF374B5C),
                      highlightColor: const Color(0xFF4A5C6A),
                      child: Container(
                        height: 16,
                        width: 150,
                        decoration: BoxDecoration(
                          color: const Color(0xFF374B5C),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Shimmer.fromColors(
                      baseColor: const Color(0xFF374B5C),
                      highlightColor: const Color(0xFF4A5C6A),
                      child: Container(
                        height: 13,
                        width: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFF374B5C),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Shimmer.fromColors(
                      baseColor: const Color(0xFF374B5C),
                      highlightColor: const Color(0xFF4A5C6A),
                      child: Container(
                        height: 13,
                        width: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF374B5C),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 27),
          Shimmer.fromColors(
            baseColor: const Color(0xFF374B5C),
            highlightColor: const Color(0xFF4A5C6A),
            child: Container(
              height: 47,
              decoration: BoxDecoration(
                color: const Color(0xFF374B5C),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
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
    // Allow both title and value to wrap instead of truncating with an ellipsis.
    // - Title: up to 2 lines (prevents single-line truncation for long labels).
    // - Value: expands and wraps as needed.
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title — разрешаем перенос строк (убираем усечение)
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              softWrap: true,
              maxLines: 2,
              overflow: TextOverflow.visible,
            ),
          ),
          const SizedBox(width: 6),
          // Значение — занимает остаток строки и переносится по словам
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferPriceButton extends StatelessWidget {
  final String advertId;
  final String advertSlug;

  const _OfferPriceButton({required this.advertId, required this.advertSlug});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return OfferPriceDialog(
              advertId: int.parse(advertId),
              advertSlug: advertSlug,
            );
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
        // Проверяем что sellerAvatar не пусто
        if (sellerAvatar.isEmpty) {
          return;
        }
        
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
              // Передаём оригинальный строковый URL аватарки
              sellerAvatarUrl: sellerAvatar,
              userId: userId,
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

    _isFavorited = FavoritesService.isFavorite(widget.listing.id);
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorited = FavoritesService.toggleFavorite(widget.listing.id);
    });
    
    // Синхронизируем с сервером через WishlistBloc
    final listingId = int.tryParse(widget.listing.id);
    if (listingId != null && mounted) {
      if (_isFavorited) {
        context.read<WishlistBloc>().add(
          AddToWishlistEvent(listingId: listingId),
        );
      } else {
        context.read<WishlistBloc>().add(
          RemoveFromWishlistEvent(listingId: listingId),
        );
      }
    }
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
