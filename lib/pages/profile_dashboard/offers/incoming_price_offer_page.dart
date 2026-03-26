import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/models/offer_model.dart';
import 'package:lidle/widgets/dialogs/reject_offer_dialog.dart';
import 'package:lidle/pages/full_category_screen/mini_property_details_screen.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/pages/profile_dashboard/offers/price_offers_empty_page.dart'
    show PriceOffersEmptyPage;

class IncomingPriceOfferPage extends StatelessWidget {
  final PriceOfferItem offerItem;

  const IncomingPriceOfferPage({super.key, required this.offerItem});

  static const routeName = '/incoming-price-offer';

  static const backgroundColor = Color(0xFF243241);
  static const cardColor = Color(0xFF1F2C3A);
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
      child: BlocBuilder<NavigationBloc, NavigationState>(
        builder: (context, navigationState) {
          return Scaffold(
            extendBody: true,
            backgroundColor: backgroundColor,
            body: SafeArea(
              bottom: false,
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
                          'Предложения цен',
                          style: TextStyle(
                            color: Color.fromARGB(255, 255, 255, 255),
                            fontSize: 16,
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
                            style: TextStyle(
                              color: activeIconColor,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // const SizedBox(height: 20),

                  // ───── Object ─────
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 25),
                    child: Text(
                      'Ваш объект',
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
                    child: _ObjectCard(),
                  ),

                  const SizedBox(height: 14),

                  // ───── Offer ─────
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 25),
                    child: Text(
                      'Предложил свою цену',
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
                    child: _OfferCard(),
                  ),

                  const SizedBox(height: 5),

                  // const Spacer(),

                  // ───── Complaint ─────
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
                            borderRadius: BorderRadius.circular(10),
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

                  const SizedBox(height: 80),
                ],
              ),
            ),
            bottomNavigationBar: BottomNavigation(
              onItemSelected: (index) {
                if (index == 3) {
                  // Shopping cart icon
                  context.read<NavigationBloc>().add(
                    NavigateToMyPurchasesEvent(),
                  );
                } else {
                  context.read<NavigationBloc>().add(
                    SelectNavigationIndexEvent(index),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────

class _ObjectCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Получаем данные объявления из родительского виджета
    final offerItem = context
        .findAncestorWidgetOfExactType<IncomingPriceOfferPage>()!
        .offerItem;

    // Определяем отображаемое изображение: сетевое или локальный ассет
    final imageUrl = offerItem.listingImage;
    final imageProvider = (imageUrl != null && imageUrl.startsWith('http'))
        ? NetworkImage(imageUrl) as ImageProvider
        : const AssetImage('assets/home_page/apartment1.png') as ImageProvider;

    final listingTitle = offerItem.listingTitle ?? 'Объявление';
    final listingId = offerItem.listingId ?? '';
    final listingPrice = offerItem.listingPrice;
    final formattedPrice = listingPrice != null
        ? _formatListingPrice(listingPrice)
        : '';

    return Container(
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Создаём Listing из данных объявления и переходим на экран деталей
          final listing = Listing(
            id: offerItem.listingId ?? '',
            imagePath: offerItem.listingImage ?? '',
            title: offerItem.listingTitle ?? 'Объявление',
            price: offerItem.listingPrice ?? '0',
            location: '',
            date: '',
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MiniPropertyDetailsScreen(listing: listing),
            ),
          );
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
              children: [
                // Фото объявления
                Container(
                  width: 105,
                  height: 74,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    image: DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '№ $listingId',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        listingTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formattedPrice,
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
          const Divider(color: Colors.white24, height: 1),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Text(
              'Перейти',
              style: TextStyle(
                color: IncomingPriceOfferPage.accentColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  /// Форматирует цену объявления с разделителями
  String _formatListingPrice(String priceStr) {
    try {
      final price = double.parse(priceStr);
      final intPrice = price.toInt().toString();
      String result = '';
      int count = 0;
      for (int i = intPrice.length - 1; i >= 0; i--) {
        if (count > 0 && count % 3 == 0) result = ' $result';
        result = '${intPrice[i]}$result';
        count++;
      }
      return '$result₽';
    } catch (_) {
      return '$priceStr₽';
    }
  }
}

class _OfferCard extends StatefulWidget {
  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard> {
  /// true пока идёт запрос к API на отклонение
  bool _isRejecting = false;

  /// true пока идёт запрос к API на принятие
  bool _isAccepting = false;

  /// Отклонить предложение через API и вернуться на предыдущий экран
  Future<void> _rejectOffer(
    BuildContext context,
    PriceOfferItem offerItem,
  ) async {
    // Диалог подтверждения
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const RejectOfferDialog(),
    );
    if (confirmed != true) return;

    final offerId = offerItem.offerId;
    if (offerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось определить ID предложения')),
      );
      return;
    }

    setState(() => _isRejecting = true);
    try {
      // PUT /me/offers/received/{id} с offer_status_id: 3 (отказ)
      await ApiService.updateReceivedOfferStatus(
        offerId: int.parse(offerId),
        statusId: 3,
      );

      if (!mounted) return;
      // Возвращаем true — список обновится
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _isRejecting = false);
    }
  }

  /// Принять предложение цены через API и перейти на аккаунт покупателя.
  ///
  /// Логика навигации:
  /// - Стек ДО:  PriceOffersEmptyPage / PriceOffersListPage / IncomingPriceOfferPage
  /// - Стек ПОСЛЕ: PriceOffersEmptyPage / UserAccountPage
  ///
  /// Используем pushNamedAndRemoveUntil вместо связки pop+push, потому что:
  /// 1. pop(true) → PriceOffersListPage получал result=true → перезагружал офферы →
  ///    видел пустой список → вызывал pop(true) → убирал UserAccountPage со стека
  ///    (баг: пользователя выбрасывало обратно на PriceOffersListPage)
  /// 2. PriceOffersEmptyPage получал result=true → объявление пропадало из списка
  ///    (баг: принятая сделка должна оставаться в списке, пока нет явного отказа)
  ///
  /// Правильная схема: удаляем IncomingPriceOfferPage + PriceOffersListPage из стека
  /// без возврата результата — объявление остаётся в PriceOffersEmptyPage, и
  /// при нажатии "Назад" с экрана профиля пользователь попадает на PriceOffersEmptyPage.
  Future<void> _acceptOffer(
    BuildContext context,
    PriceOfferItem offerItem,
  ) async {
    final offerId = offerItem.offerId;
    if (offerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось определить ID предложения')),
      );
      return;
    }

    setState(() => _isAccepting = true);
    try {
      // PUT /me/offers/received/{id} с offer_status_id: 2 (принятие)
      await ApiService.updateReceivedOfferStatus(
        offerId: int.parse(offerId),
        statusId: 2,
      );

      if (!mounted) return;

      // Переходим на профиль покупателя, убирая из стека
      // IncomingPriceOfferPage и PriceOffersListPage, но оставляя PriceOffersEmptyPage.
      // Так объявление не пропадает из списка и Back ведёт на PriceOffersEmptyPage.
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/user-account',
        (route) =>
            route.settings.name == PriceOffersEmptyPage.routeName ||
            route.isFirst,
        arguments: offerItem,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offerItem = context
        .findAncestorWidgetOfExactType<IncomingPriceOfferPage>()!
        .offerItem;

    return Container(
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/user-account-only',
                  arguments: offerItem,
                );
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage:
                        offerItem.avatar.startsWith('http://') ||
                            offerItem.avatar.startsWith('https://')
                        ? NetworkImage(offerItem.avatar) as ImageProvider
                        : AssetImage(offerItem.avatar) as ImageProvider,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offerItem.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          offerItem.subtitle,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Предлагаемая цена',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  offerItem.price,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Сообщение',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  offerItem.message ?? '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: IncomingPriceOfferPage.dangerColor,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isRejecting || _isAccepting
                        ? null
                        : () => _rejectOffer(context, offerItem),
                    child: _isRejecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: IncomingPriceOfferPage.dangerColor,
                            ),
                          )
                        : const Text(
                            'Отклонить',
                            style: TextStyle(
                              color: IncomingPriceOfferPage.dangerColor,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: IncomingPriceOfferPage.accentColor,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isAccepting || _isRejecting
                        ? null
                        : () => _acceptOffer(context, offerItem),
                    child: _isAccepting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: IncomingPriceOfferPage.accentColor,
                            ),
                          )
                        : const Text(
                            'Принять',
                            style: TextStyle(
                              color: IncomingPriceOfferPage.accentColor,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
