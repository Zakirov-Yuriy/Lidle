// ============================================================
//  "Карточка объявления"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/hive_service.dart';
import 'package:lidle/pages/full_category_screen/mini_property_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lidle/blocs/wishlist/wishlist_bloc.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/cart_service.dart';
import 'package:lidle/widgets/dialogs/cart_folder_dialogs.dart';
import 'package:lidle/services/product_favorites_service.dart';
import 'package:lidle/pages/products/product_details_screen.dart';

// ============================================================
// "Утилиты для форматирования"
// ============================================================
/// Форматирует цену: "1000000,00" → "1 000 000 ₽"
String _formatPriceWithRuble(String price) {
  if (price.isEmpty) return '₽';
  
  // Удаляем копейки (всё после запятой)
  final integerPart = price.contains(',') 
      ? price.split(',')[0] 
      : price.split('.')[0];
  
  // Добавляем пробелы между разрядами
  final parts = <String>[];
  for (var i = integerPart.length; i > 0; i -= 3) {
    final start = (i - 3) < 0 ? 0 : (i - 3);
    parts.insert(0, integerPart.substring(start, i));
  }
  
  final formatted = parts.join(' ');
  return '$formatted ₽';
}

// ============================================================

/// Насколько кнопка корзины свешивается за нижний край картинки, в точках.
///
/// ЗДЕСЬ И РЕГУЛИРУЕТСЯ. Одно число на все экраны: карточка товара одна и та
/// же на главной, в разделе и в избранном, и разводить настройку по экранам
/// значит однажды получить три разных свеса в одном приложении.
///
/// Отступ под картинкой считается от этого же числа, поэтому кнопка не
/// наезжает на название, какое значение ни поставь. Ноль вернёт кнопку целиком
/// на снимок, как было до 15.09.2026.
const double cartButtonOverhang = 7;

class ListingCard extends StatefulWidget {
  final Listing listing;
  final VoidCallback? onBeforeNavigate;

  /// Считать показ карточки как «Просмотр» (импрессия). Включать ТОЛЬКО в
  /// лентах-выдачах: главная, лента категории, результаты фильтра и строки
  /// поиска. Не включать в избранном, «Мои объявления» и профиле продавца —
  /// там показ карточки не является просмотром из поиска.
  final bool countImpression;

  const ListingCard({
    super.key,
    required this.listing,
    this.onBeforeNavigate,
    this.countImpression = false,
  });

  @override
  State<ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<ListingCard> {
  late bool _isFavorite;

  /// Кнопка «В корзину» нажата и ответ ещё не пришёл.
  bool _isAdding = false;

  /// Какая фотография товара сейчас видна в карточке (15.09.2026).
  ///
  /// Карточка в ленте листается пальцем, не заходя в товар. Номер держим
  /// здесь, а не в контроллере страницы: контроллер на каждую карточку это
  /// лишний объект на десятки карточек в списке, а всё, что нам нужно, —
  /// подсветить нужную точку внизу.
  int _imagePage = 0;

  @override
  void initState() {
    super.initState();
    _isFavorite = HiveService.getFavorites().contains(widget.listing.id);

    // Товар в ленте главной (09.09.2026) — не объявление: ни просмотров, ни
    // избранного у него здесь нет. Счётчик просмотров объявлений принял бы
    // номер товара за номер объявления и накрутил чужую статистику.
    if (widget.listing.isProduct) {
      return;
    }

    // «Просмотр» = показ карточки в выдаче. Шлём один раз за сессию на
    // объявление (гуард внутри saveAdvertViewOnce); дневной дедуп — на бэке.
    if (widget.countImpression) {
      final id = int.tryParse(widget.listing.id);
      if (id != null) {
        ApiService.saveAdvertViewOnce(id);
      }
    }
  }

  void _toggleFavorite() {
    // Проверяем текущее состояние перед изменением
    final currentFavorite = HiveService.isFavorite(widget.listing.id);
    final newState = !currentFavorite;
    
    // Только обновляем UI локально для оптимистичного отображения
    setState(() {
      _isFavorite = newState;
    });
    
    // 🔄 Отправляем событие в WishlistBloc для обработки API запроса
    // WishlistBloc сам обновит Hive ПОСЛЕ успешного ответа с сервера
    final advertId = int.tryParse(widget.listing.id);
    if (advertId != null) {
      if (newState) {
        // Добавляем в wishlist на сервере
        // log.i('💗 ListingCard: Отправляем AddToWishlistEvent для advert_id=$advertId');
        context.read<WishlistBloc>().add(
          AddToWishlistEvent(listingId: advertId),
        );
      } else {
        // Удаляем из wishlist на сервере
        // log.i('💔 ListingCard: Отправляем RemoveFromWishlistEvent для advert_id=$advertId');
        context.read<WishlistBloc>().add(
          RemoveFromWishlistEvent(
            listingId: advertId,
            wishlistId: widget.listing.wishlistId,
          ),
        );
      }
    }
  }

  /// Положить товар в корзину прямо из ленты.
  Future<void> _addToCart() async {
    final productId = widget.listing.productId;

    if (productId == null || _isAdding) return;

    setState(() => _isAdding = true);

    final result = await addToCartWithFolder(context, productId);

    if (!mounted) return;

    setState(() => _isAdding = false);

    if (result == null) return;

    if (!result.isOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Не получилось добавить в корзину'),
          backgroundColor: secondaryBackground,
        ),
      );

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Товар в корзине'),
        backgroundColor: secondaryBackground,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Карточка ТОВАРА. Отдельной веткой, а не флажками внутри общей вёрстки:
    // у товара нет адреса, зато есть кнопка «В корзину» и своя оценка, и
    // сшивать это в один макет значит получить карточку из одних условий.
    //
    // Сердечко с 15.09.2026 есть и у товара, но работает оно на своём
    // состоянии: номера товаров и объявлений совпадают, и общее хранилище
    // зажигало бы его не на той карточке.
    if (widget.listing.isProduct) {
      return _buildProductCard(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxHeight;
        final cardWidth = constraints.maxWidth;

        double imageProportion = cardWidth < 140 ? 0.50 : 0.58;
        final imageHeight = cardHeight * imageProportion;

        final scale = cardHeight / 263;
        final titleFontSize = 14 * scale;
        final priceFontSize = 16 * scale;
        final locationFontSize = 13 * scale;
        final dateFontSize = 12 * scale;

        return GestureDetector(
          onTap: () {
            // 💾 Вызываем callback для сохранения позиции скролла
            widget.onBeforeNavigate?.call();
            
            // 🔓 Переходим к деталям объявления (доступно для всех, включая неавторизованных)
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MiniPropertyDetailsScreen(listing: widget.listing),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                height: imageHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5 * scale),
                        child: _advertGallery(scale),
                      ),
                    ),

                    // Сердечко объявления: сверху справа, как у товара.
                    Positioned(
                      right: 6,
                      top: 6,
                      child: GestureDetector(
                        onTap: _toggleFavorite,
                        behavior: HitTestBehavior.opaque,
                        child: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorite ? Colors.red : textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Точки ПОД картинкой, а не поверх неё (15.09.2026): на снимке
              // они спорят с самим снимком и теряются на светлом.
              if (_productImages.length > 1) ...[
                SizedBox(height: 4 * scale),
                _productDots(),
                SizedBox(height: 4 * scale),
              ] else
                SizedBox(height: 8 * scale),

              SizedBox(height: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Сердечко переехало на фотографию (15.09.2026):
                        // теперь оно стоит там же, где у товара, сверху
                        // справа. Раньше оно жило в строке заголовка и
                        // отъедало у названия место, а на соседней карточке
                        // товара было в другом углу.
                        Expanded(
                          child: Text(
                            widget.listing.title,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    Text(
                      _formatPriceWithRuble(widget.listing.price),
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: priceFontSize,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    SizedBox(height: 3 * scale),
                    Text(
                      widget.listing.location,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: locationFontSize,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: 1 * scale),

                    Text(
                      widget.listing.date,
                      style: TextStyle(
                        color: textMuted,
                        fontSize: dateFontSize,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Дата появления на витрине, готовая к показу.
  ///
  /// Пусто, если сервер её не прислал: в списке лежит и старая сборка ответа,
  /// и там вместо даты стоит заглушка «Unknown Date». Показать её человеку
  /// хуже, чем не показать ничего.
  String get _publishedOn {
    final date = widget.listing.date.trim();

    if (date.isEmpty || date == 'Unknown Date') return '';

    return date;
  }

  /// Карточка товара: картинка, цена, название, магазин и «В корзину».
  ///
  /// Кнопки нет, когда у раздела не заведён атрибут оплаты (`can_order`):
  /// такой товар покупают на месте, и корзина для него не работает. Рисовать
  /// кнопку, которая ответит отказом, значит водить человека по кругу.
  Widget _buildProductCard(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxHeight;

        final scale = cardHeight / 263;

        return GestureDetector(
          onTap: () {
            widget.onBeforeNavigate?.call();

            final productId = widget.listing.productId;

            if (productId == null) return;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailsScreen(productId: productId),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Картинка забирает ОСТАТОК высоты, а не свою долю от неё.
              //
              // Так было: у картинки была фиксированная доля, а низ карточки
              // держался распоркой. При длинном названии колонка перерастала
              // свою клетку в сетке, и кнопка «В корзину» наползала на
              // соседнюю карточку снизу. Теперь наоборот: текст и кнопка
              // занимают сколько нужно, картинка — сколько осталось, и
              // выйти за клетку карточка не может.
              // Картинка забирает ОСТАТОК высоты, а кнопка корзины лежит
              // НА ней, в правом нижнем углу.
              //
              // Так было: кнопка «В корзину» во всю ширину карточки отдельной
              // строкой. Она съедала треть высоты, спорила с ценой за
              // внимание и делала витрину рыхлой. Заказчик 14.09.2026 просил
              // как на знакомых маркетплейсах: иконка поверх картинки.
              Expanded(
                child: Stack(
                  // Кнопка корзины СВЕШИВАЕТСЯ за нижний край картинки
                  // (15.09.2026, как на знакомых маркетплейсах). Без этого
                  // разрешения она обрезалась бы по краю снимка.
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _productGallery(),
                      ),
                    ),

                    if (widget.listing.canOrder)
                      Positioned(
                        right: 6,

                        // Ниже края картинки: кнопка частью лежит на снимке,
                        // частью в отступе под ним. Величина свеса — одно
                        // число на весь файл, `cartButtonOverhang` вверху.
                        bottom: -cartButtonOverhang,
                        child: _cartButton(),
                      ),

                    // Сердечко у товара (15.09.2026). Сверху справа, чтобы не
                    // спорить с корзиной снизу. Состояние общее на всё
                    // приложение: тот же товар виден и в ленте, и в разделе.
                    Positioned(
                      right: 6,
                      top: 6,
                      child: _productFavoriteButton(),
                    ),
                  ],
                ),
              ),

              // Отступ под картинкой держит место для свешенной кнопки
              // корзины: она выходит за край снимка на `cartButtonOverhang`
              // точек, и без запаса легла бы прямо на название. Считается от
              // того же числа, поэтому свес можно менять одной строкой вверху
              // файла, ничего больше не трогая.
              //
              // Здесь же точки листалки: под картинкой, а не поверх неё. На
              // снимке они спорят с самим снимком и теряются на светлом.
              // Показываем их только когда листать есть что: одинокая точка
              // под единственным снимком выглядит как недогруженная карточка.
              if (_productImages.length > 1) ...[
                SizedBox(height: cartButtonOverhang * scale),
                _productDots(),
                SizedBox(height: 3 * scale),
              ] else
                SizedBox(height: (cartButtonOverhang + 3) * scale),

              // Сначала НАЗВАНИЕ, потом цена (15.09.2026, просьба заказчика).
              //
              // Так было наоборот. В ленте, где карточки идут сеткой по две,
              // человек сначала узнаёт вещь и только потом смотрит, сколько
              // она стоит; цена первой заставляет его читать карточку задом
              // наперёд.
              Text(
                widget.listing.title,

                // Ровно ОДНА строка, как у объявления (15.09.2026). Длинное
                // название раньше занимало две, подпись росла, и картинка на
                // эту же высоту сжималась: в одном ряду карточки оказывались
                // с разными по размеру фотографиями. Обрезать название
                // многоточием честнее, чем портить фотографию товара.
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textPrimary, fontSize: 14 * scale),
              ),

              SizedBox(height: 2 * scale),

              Text(
                // Тем же форматом, что у объявления: «5 400 ₽», а не
                // «5400.0 ₽». Цена товара приходит числом, и её строковый вид
                // показывал хвост с нулём (15.09.2026).
                _formatPriceWithRuble(widget.listing.price),
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),

              // Название точки убрано 14.09.2026: покупателю на витрине оно
              // ничего не решает, а место занимало. Продавец виден в карточке
              // товара, куда человек и идёт за подробностями.

              SizedBox(height: 3 * scale),
              _ratingRow(scale),

              // Товар без корзины: говорим об этом прямо, иначе человек ищет
              // кнопку и думает, что приложение сломалось.
              if (!widget.listing.canOrder)
                Padding(
                  padding: EdgeInsets.only(top: 3 * scale),
                  child: Text(
                    'Покупка на месте',
                    style: TextStyle(color: textMuted, fontSize: 12 * scale),
                  ),
                ),

              // Дата появления на витрине (15.09.2026). Последней строкой и
              // мелким шрифтом: человек смотрит на неё, только когда уже
              // выбрал глазами карточку и решает, свежее предложение или
              // лежит с весны.
              if (_publishedOn.isNotEmpty) ...[
                SizedBox(height: 3 * scale),
                Text(
                  _publishedOn,
                  style: TextStyle(color: textMuted, fontSize: 12 * scale),
                ),
              ],

              // Отступ до следующего ряда сетки: у сетки главной он нулевой,
              // и без него карточки слипаются низом.
              SizedBox(height: 10 * scale),
            ],
          ),
        );
      },
    );
  }

  /// Фотографии карточки для листалки.
  ///
  /// Одинаково для товара и для объявления (15.09.2026): у объявления набор
  /// приезжает уменьшенными копиями в `thumbnails`, у товара — в `images`, а
  /// на карточке они ведут себя одинаково, потому что лежат в одной ленте.
  ///
  /// Пусто у старого сервера, который набор не присылает: тогда показываем
  /// одну, ту, что приехала в `imagePath`.
  List<String> get _productImages {
    final images = widget.listing.images.where((e) => e.isNotEmpty).toList();

    if (images.isNotEmpty) return images;

    return widget.listing.imagePath.isEmpty
        ? const []
        : [widget.listing.imagePath];
  }

  /// Фотографии объявления, которые листаются пальцем (15.09.2026).
  ///
  /// Отдельно от товарной: у объявления картинка грузится через кэш и умеет
  /// быть локальным файлом из ассетов, а у товара всегда приходит ссылкой.
  Widget _advertGallery(double scale) {
    final images = _productImages;

    if (images.isEmpty) {
      return Container(
        color: const Color(0xFF374B5C),
        child: Icon(Icons.image_not_supported, color: textMuted, size: 50 * scale),
      );
    }

    if (images.length == 1) return _advertImage(images.first, scale);

    return PageView.builder(
      itemCount: images.length,
      onPageChanged: (index) => setState(() => _imagePage = index),
      itemBuilder: (context, index) => _advertImage(images[index], scale),
    );
  }

  Widget _advertImage(String path, double scale) {
    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: const Color(0xFF374B5C)),
        errorWidget: (context, url, error) => Container(
          color: const Color(0xFF374B5C),
          child: Icon(Icons.image, color: textMuted, size: 50 * scale),
        ),
      );
    }

    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: const Color(0xFF374B5C),
        child: Icon(Icons.image, color: textMuted, size: 50 * scale),
      ),
    );
  }

  /// Фотографии товара, которые листаются пальцем (15.09.2026).
  ///
  /// `PageView` заводим ТОЛЬКО когда снимков больше одного. Он перехватывает
  /// горизонтальные жесты, и ставить его под единственную картинку значит
  /// без нужды мешать листанию самой ленты.
  Widget _productGallery() {
    final images = _productImages;

    if (images.isEmpty) {
      return Container(
        color: formBackground,
        child: const Icon(Icons.photo_outlined, color: textMuted, size: 28),
      );
    }

    if (images.length == 1) return _productImage(images.first);

    return PageView.builder(
      itemCount: images.length,
      onPageChanged: (index) => setState(() => _imagePage = index),
      itemBuilder: (context, index) => _productImage(images[index]),
    );
  }

  Widget _productImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: formBackground,
        child: const Icon(Icons.photo_outlined, color: textMuted, size: 28),
      ),
    );
  }

  /// Точки под фотографиями: какая по счёту сейчас видна.
  Widget _productDots() {
    final count = _productImages.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isCurrent = index == _imagePage;

        return Container(
          width: isCurrent ? 6 : 5,
          height: isCurrent ? 6 : 5,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Непоказанные точки приглушены, а не спрятаны: человек должен
            // видеть, сколько всего снимков, а не только где он сейчас.
            //
            // Цвета под фон карточки, а не под снимок: точки переехали из-под
            // картинки наружу (15.09.2026).
            color: isCurrent ? textPrimary : textMuted,
          ),
        );
      }),
    );
  }

  /// Сердечко товара поверх картинки (15.09.2026).
  ///
  /// Работает на своём состоянии (`ProductFavoritesService`), а не на общем
  /// избранном объявлений: номера товаров и объявлений совпадают, и одно
  /// хранилище на двоих зажигало бы сердечко не на той карточке.
  Widget _productFavoriteButton() {
    final productId = widget.listing.productId;

    if (productId == null) return const SizedBox.shrink();

    return ValueListenableBuilder<Map<int, int?>>(
      valueListenable: ProductFavoritesService.items,
      builder: (context, favorites, _) {
        final isFavorite = favorites.containsKey(productId);

        return GestureDetector(
          onTap: () async {
            final error = await ProductFavoritesService.toggle(productId);

            if (error != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(error),
                  backgroundColor: secondaryBackground,
                ),
              );
            }
          },
          behavior: HitTestBehavior.opaque,
          // Без подложки и того же размера, что у объявления (15.09.2026):
          // серый кружок вокруг сердца выбивался из вида карточки, а два
          // разных сердца в одной ленте читались как две разные кнопки.
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Colors.red : textPrimary,
          ),
        );
      },
    );
  }

  /// Кнопка корзины: круглая, поверх картинки.
  ///
  /// Размер и место постоянные, без множителя высоты: это область НАЖАТИЯ, и
  /// в узкой колонке она не должна становиться меньше пальца.
  ///
  /// Если товар уже в корзине, иконка становится закрашенной, а над ней
  /// встаёт счётчик — как на знакомых маркетплейсах (14.09.2026). Без него
  /// человек, вернувшийся к ленте, не помнит, что уже положил, и кладёт
  /// второй раз.
  Widget _cartButton() {
    final productId = widget.listing.productId;

    return ValueListenableBuilder<Map<int, int>>(
      valueListenable: CartService.quantities,
      builder: (context, quantities, _) {
        // Считаем прямо из общего состояния корзины, а не из своего поля:
        // товар мог уехать из корзины на другом экране, и собственная
        // память карточки разошлась бы с правдой.
        final inCart = productId == null ? 0 : (quantities[productId] ?? 0);

        return GestureDetector(
          onTap: _isAdding ? null : _addToCart,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            // Счётчик выходит за край кнопки: без этого он обрезался бы.
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: activeIconColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: _isAdding
                      // Кружок ожидания ровно на месте иконки: кнопка не
                      // должна менять размер, иначе картинка под ней
                      // дёргается.
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(
                          // Закрашенная корзина = товар уже внутри. Отличие
                          // видно и без счётчика, боковым зрением.
                          inCart > 0
                              ? Icons.shopping_cart
                              : Icons.shopping_cart_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),

              if (inCart > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(10),
                      // Обводка цветом подложки: на пёстрой картинке красный
                      // кружок иначе сливается с фоном товара.
                      border: Border.all(color: primaryBackground, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        // Больше 99 не показываем числом: «100» не влезает в
                        // кружок, а точное число здесь никому не нужно.
                        inCart > 99 ? '99+' : '$inCart',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Оценка товара: звезда, значение и число оценок.
  ///
  /// Без отзывов показываем ОДНУ пустую звезду и ничего больше (15.09.2026).
  /// Так было: строка не рисовалась вовсе, и карточки с отзывами и без них
  /// разъезжались по высоте. Ноль писать тоже нельзя: «0,0» читается как
  /// плохая оценка, хотя оценок просто нет, а «будьте первым» в ленте из
  /// двадцати карточек превращается в двадцать одинаковых просьб.
  Widget _ratingRow(double scale) {
    final rating = widget.listing.rating ?? 0;
    final count = widget.listing.reviewsCount;

    if (count == 0 || widget.listing.rating == null) {
      return Row(
        children: [
          Icon(
            Icons.star_border,
            color: const Color(0xFFFFB800),
            size: 14 * scale,
          ),
          SizedBox(width: 4 * scale),
          Expanded(
            child: Text(
              'Будь первым!',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textMuted, fontSize: 12 * scale),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.star, color: const Color(0xFFFFB800), size: 14 * scale),
        SizedBox(width: 3 * scale),
        Text(
          // Запятая, а не точка: по-русски дробную часть отделяют запятой, и
          // «4.7» на витрине читается как чужое.
          rating.toStringAsFixed(1).replaceAll('.', ','),
          style: TextStyle(
            color: textPrimary,
            fontSize: 12 * scale,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: 4 * scale),
        Expanded(
          child: Text(
            '· $count ${_reviewsWord(count)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textMuted, fontSize: 12 * scale),
          ),
        ),
      ],
    );
  }

  /// «оценка», «оценки», «оценок» — по числу.
  static String _reviewsWord(int count) {
    final tail = count % 100;

    if (tail >= 11 && tail <= 14) return 'оценок';

    switch (count % 10) {
      case 1:
        return 'оценка';
      case 2:
      case 3:
      case 4:
        return 'оценки';
      default:
        return 'оценок';
    }
  }
}
