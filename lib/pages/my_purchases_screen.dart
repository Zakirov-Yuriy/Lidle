import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/blocs/connectivity/connectivity_bloc.dart';
import 'package:lidle/blocs/connectivity/connectivity_state.dart';
import 'package:lidle/blocs/connectivity/connectivity_event.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/pages/products/my_orders_screen.dart';
import 'package:lidle/pages/products/product_details_screen.dart';
import 'package:lidle/pages/products/products_screen.dart';
import 'package:lidle/services/orders_service.dart';
import 'package:lidle/services/products_service.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/no_internet_screen.dart';

/// Мои покупки: то, что человек реально купил и забрал.
///
/// Покупка — это выданный заказ (статус `completed`). Живые и отменённые
/// заказы живут на экране «Мои заказы»: там за ними следят, а здесь — история
/// того, что уже в руках. Каждая позиция выданного заказа показывается
/// отдельной строкой: покупают товары, а не номера заказов.
class MyPurchasesScreen extends StatefulWidget {
  static const String routeName = '/my-purchases';

  const MyPurchasesScreen({super.key});

  @override
  State<MyPurchasesScreen> createState() => _MyPurchasesScreenState();
}

/// Одна купленная позиция: строка заказа плюс то, что нужно для подписи.
class _PurchaseEntry {
  final OrderLine line;
  final String shopName;
  final DateTime? date;

  const _PurchaseEntry({
    required this.line,
    required this.shopName,
    required this.date,
  });
}

class _MyPurchasesScreenState extends State<MyPurchasesScreen> {
  bool _isLoading = true;
  bool _newestFirst = true;

  /// Покупки существуют только у аккаунта: сервер опознаёт покупателя по
  /// токену. Гостю показываем предложение войти, а не «покупок нет».
  bool _isGuest = true;

  List<_PurchaseEntry> _purchases = const [];

  /// Картинки товаров. В позициях заказа их нет: сервер хранит имя и цену на
  /// момент покупки, а не витринную карточку. Дотягиваем из карточек товаров
  /// после загрузки списка, по одному запросу на уникальный товар.
  final Map<int, String> _images = {};

  @override
  void initState() {
    super.initState();

    final token = HiveService.getUserData('token');
    _isGuest = token == null || '$token'.isEmpty;

    if (_isGuest) {
      _isLoading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    // Берём все свои заказы и оставляем выданные. Фильтр на клиенте: заказов
    // у человека десятки, а не тысячи, и один запрос проще, чем спор с
    // сервером о параметрах.
    final orders = await OrdersService.myOrders(all: true);

    final purchases = <_PurchaseEntry>[];

    for (final order in orders) {
      if (order.status != 'completed') continue;

      for (final line in order.items) {
        purchases.add(
          _PurchaseEntry(
            line: line,
            shopName: order.shop?.name ?? '',
            date: order.pickedUpAt ?? order.createdAt,
          ),
        );
      }
    }

    _sort(purchases);

    if (!mounted) return;

    setState(() {
      _purchases = purchases;
      _isLoading = false;
    });

    _loadImages(purchases);
  }

  Future<void> _loadImages(List<_PurchaseEntry> purchases) async {
    final ids = purchases
        .map((entry) => entry.line.productId)
        .whereType<int>()
        .toSet()
        .where((id) => !_images.containsKey(id))
        .toList();

    if (ids.isEmpty) return;

    await Future.wait(ids.map((id) async {
      final product = await ProductsService.details(id);

      // Картинка в карточке может прийти и скаляром, и галереей: берём что
      // есть, как делает экран товара.
      var image = product?.image;
      if ((image == null || image.isEmpty) &&
          product != null &&
          product.images.isNotEmpty) {
        image = product.images.first;
      }

      if (image != null && image.isNotEmpty) _images[id] = image;
    }));

    if (mounted) setState(() {});
  }

  void _sort(List<_PurchaseEntry> list) {
    list.sort((a, b) {
      final left = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);

      return _newestFirst ? right.compareTo(left) : left.compareTo(right);
    });
  }

  void _toggleSort() {
    setState(() {
      _newestFirst = !_newestFirst;
      final copy = List<_PurchaseEntry>.from(_purchases);
      _sort(copy);
      _purchases = copy;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectivityBloc, ConnectivityState>(
      listener: (context, connectivityState) {
        if (connectivityState is ConnectedState && !_isGuest) {
          _load();
        }
      },
      child: BlocBuilder<ConnectivityBloc, ConnectivityState>(
        builder: (context, connectivityState) {
          if (connectivityState is DisconnectedState) {
            return NoInternetScreen(onRetry: () {
              context
                  .read<ConnectivityBloc>()
                  .add(const CheckConnectivityEvent());
            });
          }

          return BlocListener<NavigationBloc, NavigationState>(
            listener: (context, state) {
              if (state is NavigationToProfile ||
                  state is NavigationToHome ||
                  state is NavigationToFavorites ||
                  state is NavigationToCategorySelection ||
                  state is NavigationToMessages) {
                context.read<NavigationBloc>().executeNavigation(context);
              }
            },
            child: Scaffold(
              backgroundColor: primaryBackground,
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Header(),
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
                              color: textPrimary,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Мои покупки',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.import_export,
                              color: textPrimary,
                            ),
                            onPressed:
                                _purchases.length > 1 ? _toggleSort : null,
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _buildBody()),
                  ],
                ),
              ),
              bottomNavigationBar: BottomNavigation(
                onItemSelected: (index) {
                  context.read<NavigationBloc>().add(
                        SelectNavigationIndexEvent(index),
                      );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isGuest) return _buildGuestNotice();

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: activeIconColor),
      );
    }

    if (_purchases.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      color: activeIconColor,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(25, 0, 25, 24),
        children: [
          // Два товара в ряд, той же плиткой, что в витрине: покупают
          // товары, и выглядеть они должны как товары.
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
              childAspectRatio: 0.58,
            ),
            itemCount: _purchases.length,
            itemBuilder: (context, index) =>
                _buildPurchase(_purchases[index]),
          ),
          // Кнопки живут под списком всегда: докрутил покупки — можешь сразу
          // пойти за новыми или проверить живые заказы.
          const SizedBox(height: 20),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: 220,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: activeIconColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProductsScreen()),
            ),
            child: const Text(
              'Перейти к товарам',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 220,
          height: 46,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: activeIconColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
              );

              // Пока человек ходил по заказам, он мог забрать один из них:
              // вернувшись, список покупок должен это знать.
              if (mounted) _load();
            },
            child: const Text(
              'Мои заказы',
              style: TextStyle(
                color: activeIconColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPurchase(_PurchaseEntry entry) {
    final line = entry.line;

    return GestureDetector(
      onTap: line.productId == null
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProductDetailsScreen(productId: line.productId!),
                ),
              ),
      child: Container(
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Картинка забирает остаток высоты, как в плитке витрины: подпись
            // берёт сколько нужно, и переполнения не бывает.
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: _buildThumbnail(line.productId),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.quantity > 1
                        ? '${_money(line.sum)} · × ${line.quantity}'
                        : _money(line.sum),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    line.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                  if (entry.shopName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: textMuted, fontSize: 12),
                    ),
                  ],
                  if (entry.date != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(entry.date!),
                      style: const TextStyle(color: textMuted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(int? productId) {
    final url = productId == null ? null : _images[productId];

    if (url == null || url.isEmpty) {
      return Container(
        color: secondaryBackground,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, color: textMuted, size: 32),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (c, e, st) => Container(
        color: secondaryBackground,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined,
            color: textMuted, size: 32),
      ),
    );
  }

  /// Что видит гость.
  ///
  /// Купить он может, а вот история покупок существует только у аккаунта:
  /// гостевой заказ ищется по коду получения.
  Widget _buildGuestNotice() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline, color: textMuted, size: 44),
            const SizedBox(height: 12),
            const Text(
              'Войдите, чтобы видеть свои покупки',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Покупать можно и без регистрации: код получения мы показываем '
              'сразу после оформления заказа.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeIconColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProductsScreen()),
                ),
                child: const Text(
                  'Перейти к товарам',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/my_purchases/shopping-bag-01.svg',
            height: 120,
            width: 120,
            colorFilter: const ColorFilter.mode(
              Color(0xFFFEDC02),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Нет покупок',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              'У вас нет покупок, как только вы\n купите товар здесь он будет\n отображен',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFAAAAAA),
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 28),
          _buildActionButtons(),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    String two(int value) => value < 10 ? '0$value' : '$value';

    return '${two(date.day)}.${two(date.month)}.${date.year}';
  }

  String _money(double value) {
    final whole = value.truncate().toString();

    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(whole[i]);
    }

    return '${buffer.toString()} ₽';
  }
}
