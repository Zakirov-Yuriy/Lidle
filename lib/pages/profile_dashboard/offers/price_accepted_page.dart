import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/offer_model.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/dialogs/edit_price_dialog.dart';
import 'package:lidle/widgets/dialogs/reject_offer_dialog.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/pages/full_category_screen/mini_property_details_screen.dart';

class PriceAcceptedPage extends StatefulWidget {
  final Offer offer;

  const PriceAcceptedPage({super.key, required this.offer});

  static const routeName = '/price-accepted';

  @override
  State<PriceAcceptedPage> createState() => _PriceAcceptedPageState();
}

class _PriceAcceptedPageState extends State<PriceAcceptedPage> {
  late String _currentDescription;
  late String _currentPrice;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _currentDescription = widget.offer.description;
    _currentPrice = widget.offer.yourPrice;
  }

  void _showEditDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => EditPriceDialog(
        initialPrice: _currentPrice,
        initialMessage: _currentDescription,
      ),
    );

    if (result != null) {
      setState(() {
        _currentPrice = result['price'] ?? _currentPrice;
        _currentDescription = result['message'] ?? _currentDescription;
      });
    }
  }

  void _showRejectDialog() async {
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (context) => const RejectOfferDialog(),
    );

    if (shouldReject == true) {
      _rejectOffer();
    }
  }

  Future<void> _rejectOffer() async {
    setState(() => _isDeleting = true);

    try {
      final offerId = int.parse(widget.offer.id);
      print('🗑️ Удаляем предложение ID: $offerId');

      final response = await ApiService.updateOfferStatus(
        offerId: offerId,
        statusId: 3, // 3 = Refused/Delete
      );

      // Проверяем что API вернул success: true
      if (response['success'] == true) {
        if (mounted) {
          print('✅ Предложение успешно удалено!');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Предложение успешно отклонено'),
              backgroundColor: Colors.green,
            ),
          );
          // Закрываем экран и возвращаемся на список
          Navigator.pop(context, true); // true = предложение удалено
        }
      } else {
        throw Exception(response['message'] ?? 'Неизвестная ошибка API');
      }
    } catch (e) {
      print('❌ Ошибка при удалении предложения: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  static const backgroundColor = Color(0xFF243241);
  static const accentColor = Color(0xFF00B7FF);
  static const dangerColor = Color(0xFFFF3B30);

  @override
  Widget build(BuildContext context) {
    return BlocListener<NavigationBloc, NavigationState>(
      listener: (context, state) {
        if (state is NavigationToProfile ||
            state is NavigationToHome ||
            state is NavigationToFavorites ||
            state is NavigationToAddListing ||
            state is NavigationToMyPurchases ||
            state is NavigationToMessages ||
            state is NavigationToSignIn) {
          context.read<NavigationBloc>().executeNavigation(context);
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: backgroundColor,
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
                      'Принята ваша цена',
                      style: TextStyle(
                        color: Color.fromARGB(255, 255, 255, 255),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Назад',
                        style: TextStyle(color: activeIconColor, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),

              // ───── Object ─────
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 25),
                child: Text(
                  'Объект',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Container(
                  decoration: BoxDecoration(
                    color: formBackground,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              // Показываем изображение только если URL не пустой.
                              // При отсутствии thumbnail — серый прямоугольник без заглушки.
                              child: widget.offer.imageUrl.isEmpty
                                  ? Container(
                                      width: 105,
                                      height: 74,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[850],
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: const Icon(
                                        Icons.image_not_supported_outlined,
                                        color: Colors.white24,
                                        size: 30,
                                      ),
                                    )
                                  : widget.offer.imageUrl.startsWith('http')
                                  ? Image.network(
                                      widget.offer.imageUrl,
                                      width: 105,
                                      height: 74,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              width: 105,
                                              height: 74,
                                              color: Colors.grey[800],
                                              child: const Icon(
                                                Icons.image_not_supported,
                                                color: Colors.grey,
                                              ),
                                            );
                                          },
                                    )
                                  : Image.asset(
                                      widget.offer.imageUrl,
                                      width: 105,
                                      height: 74,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '№ ${widget.offer.advertisementId ?? widget.offer.id}',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.offer.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.offer.originalPrice,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white24, height: 9),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              // Создание Listing объекта из данных предложения
                              final listing = Listing(
                                id:
                                    widget.offer.advertisementId ??
                                    widget.offer.id,
                                imagePath: widget.offer.imageUrl,
                                title: widget.offer.title,
                                price: widget.offer.originalPrice,
                                location:
                                    '', // Не требуется для инициального включения
                                date:
                                    '', // Не требуется для инициального включения
                              );

                              // Навигация на экран деталей объявления
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      MiniPropertyDetailsScreen(
                                        listing: listing,
                                      ),
                                ),
                              );
                            },
                            child: Text(
                              'Перейти',
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ───── Your Offer ─────
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 25),
                child: Text(
                  'Ваше предложение',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 11),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Container(
                  decoration: BoxDecoration(
                    color: formBackground,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 19,
                          left: 9,
                          bottom: 18,
                          right: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Предлагаемая цена',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _currentPrice,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Сообщение',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _currentDescription,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white24, height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _isDeleting ? null : _showRejectDialog,
                              child: Text(
                                'Удалить',
                                style: TextStyle(
                                  color: _isDeleting
                                      ? Colors.grey
                                      : dangerColor,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // GestureDetector(
                            //   onTap: _showEditDialog,
                            //   child: const Text(
                            //     'Изменить',
                            //     style: TextStyle(
                            //       color: accentColor,
                            //       fontSize: 16,
                            //     ),
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // ───── Complaint Button ─────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 16,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: dangerColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {},
                    child: const Text(
                      'Пожаловаться',
                      style: TextStyle(
                        color: dangerColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 110), // под bottom nav
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigation(
          onItemSelected: (index) {
            if (index == 3) {
              // Shopping cart icon
              context.read<NavigationBloc>().add(NavigateToMyPurchasesEvent());
            } else {
              context.read<NavigationBloc>().add(
                SelectNavigationIndexEvent(index),
              );
            }
          },
        ),
      ),
    );
  }
}
