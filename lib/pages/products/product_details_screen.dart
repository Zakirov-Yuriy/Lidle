import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/config/app_config.dart';
import 'package:lidle/widgets/common/share_icons_row.dart';
import 'package:lidle/widgets/dialogs/product_review_dialog.dart';
import 'package:lidle/models/products/product_item.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/pages/full_category_screen/seller_profile_screen.dart';
import 'package:lidle/pages/products/your_order_screen.dart';
import 'package:lidle/pages/products/cart_screen.dart';
import 'package:lidle/pages/products/product_reviews_screen.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/cart_service.dart';
import 'package:lidle/services/product_favorites_service.dart';
import 'package:lidle/services/products_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/models/message_model.dart';
import 'package:lidle/pages/messages/chat_page.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/dialogs/report_product_dialog.dart';

/// Карточка товара.
class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({
    super.key,
    required this.productId,
    this.fromOrder = false,
    this.order,
    this.orderLine,
  });

  final int productId;

  /// Заказ, из которого пришли, и его позиция.
  ///
  /// Нужны ради кнопки «Ваш заказ»: из полного списка заказов человек
  /// попадает сюда, и без этой кнопки к коду получения было бы не вернуться.
  /// Пусто, когда карточку открыли не из заказа.
  final OrderModel? order;
  final OrderLine? orderLine;

  /// Карточка открыта из заказа (17.09.2026).
  ///
  /// Тогда экран собирается иначе: сверху дата и артикул, характеристики и
  /// описание свёрнуты, ниже магазин с подпиской, жалоба и похожие
  /// предложения, а внизу «В избранное» рядом с корзиной.
  ///
  /// Каталожный вид этим флагом НЕ меняется. Так решил заказчик: из каталога
  /// человек выбирает товар и ему нужны размеры, остаток и корзина, а из
  /// своего заказа он приходит посмотреть, что именно он купил, и у кого.
  final bool fromOrder;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final PageController _pageController = PageController();

  ProductItem? _product;
  bool _isLoading = true;
  bool _isAdding = false;

  int _quantity = 1;
  int _currentImage = 0;

  /// Подсвеченная оценка, пока открыт диалог отзыва (15.09.2026). Ровно как
  /// на карточке объявления: звезда остаётся закрашенной, чтобы человек видел,
  /// что именно он нажал.
  int _selectedStars = 0;

  /// Раскрыт ли текст-подсказка в блоке «Поделиться». Свёрнут по умолчанию:
  /// иконки и кнопка видны всегда, а объяснение нужно один раз.
  bool _shareExpanded = false;

  /// Выбранный вариант: цвет плюс размер (14.09.2026).
  ///
  /// Пусто, пока человек не выбрал, и у товаров без вариантов всегда. Именно
  /// его номер уходит в корзину: остаток и цена лежат на варианте, а не на
  /// модели.
  int? _variantId;

  /// Похожие предложения и их загрузка. Нужны только в виде «из заказа»,
  /// поэтому и грузятся только там: лишний запрос в каталоге не нужен.
  List<ProductItem> _similar = const [];
  bool _similarLoading = false;

  /// Раскрыты ли характеристики и описание целиком. Свёрнуты по умолчанию:
  /// у товара бывает два десятка характеристик, и до магазина с ними
  /// пришлось бы листать полэкрана.
  bool _attributesExpanded = false;
  bool _descriptionExpanded = false;

  /// Идёт подписка или отписка от продавца.
  bool _subscribing = false;

  /// Точка с обновлённой подпиской. Пусто, пока человек не нажимал
  /// «Подписаться»: тогда показываем то, что пришло с сервера.
  ShopBrief? _shopOverride;

  /// Точка товара с учётом только что изменённой подписки.
  ShopBrief? _shopOf(ProductItem? product) => _shopOverride ?? product?.shop;

  /// Сколько характеристик видно в свёрнутом виде.
  static const int _shortAttributes = 5;

  /// Сколько строк описания видно в свёрнутом виде.
  static const int _shortDescriptionLines = 6;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final product = await ProductsService.details(widget.productId);

    if (!mounted) return;

    setState(() {
      _product = product;
      _isLoading = false;

      // Сразу выбираем первый доступный вариант: карточка с ценой «от» и
      // погашенной кнопкой выглядит сломанной, а человек в девяти случаях из
      // десяти берёт то, что есть.
      final variants = product?.variants ?? const [];

      if (variants.isNotEmpty) {
        final first = variants.firstWhere(
          (variant) => variant.isAvailable && variant.inStock,
          orElse: () => variants.first,
        );

        _variantId = first.id;
      }
    });

    if (widget.fromOrder && product != null) _loadSimilar();
  }

  /// Похожие предложения. Подбирает сервер: тот же раздел, любые продавцы,
  /// сортировка по близости цены.
  Future<void> _loadSimilar() async {
    setState(() => _similarLoading = true);

    final items = await ProductsService.similar(widget.productId);

    if (!mounted) return;

    setState(() {
      _similar = items;
      _similarLoading = false;
    });
  }

  /// Выбранный вариант, если он есть.
  ProductVariant? get _variant {
    final variants = _product?.variants ?? const <ProductVariant>[];

    for (final variant in variants) {
      if (variant.id == _variantId) return variant;
    }

    return null;
  }

  /// Что кладём в корзину и по чему считаем остаток.
  ///
  /// У товара с вариантами это ВАРИАНТ, у обычного — сам товар. Одно место на
  /// весь экран: цена, остаток, счётчик и кнопка должны говорить об одном и
  /// том же.
  int get _orderId => _variant?.id ?? _product?.id ?? 0;

  int get _availableStock => _variant?.stockQuantity ?? _product?.stockQuantity ?? 0;

  bool get _canBuy {
    final product = _product;

    if (product == null) return false;

    if (product.hasVariants) {
      final variant = _variant;

      return variant != null && variant.isAvailable && variant.inStock;
    }

    return product.inStock;
  }

  /// Выбрать цвет, сохранив размер, если такой есть.
  ///
  /// Человек смотрит красную 46-го, переключает на зелёный и ждёт зелёную
  /// 46-го, а не «первую попавшуюся зелёную».
  void _pickColor(int? colorId) {
    final variants = _product?.variants ?? const <ProductVariant>[];
    final currentSize = _variant?.dimensionId;

    final sameSize = variants.where(
      (variant) => variant.colorId == colorId && variant.dimensionId == currentSize,
    );

    final fallback = variants.where((variant) => variant.colorId == colorId);

    final picked = sameSize.isNotEmpty
        ? sameSize.first
        : (fallback.isNotEmpty ? fallback.first : null);

    if (picked == null) return;

    setState(() {
      _variantId = picked.id;
      _quantity = 1;
    });
  }

  /// Выбрать размер в пределах выбранного цвета.
  void _pickSize(int? dimensionId) {
    final variants = _product?.variants ?? const <ProductVariant>[];
    final currentColor = _variant?.colorId;

    final exact = variants.where(
      (variant) =>
          variant.dimensionId == dimensionId && variant.colorId == currentColor,
    );

    final any = variants.where((variant) => variant.dimensionId == dimensionId);

    final picked = exact.isNotEmpty
        ? exact.first
        : (any.isNotEmpty ? any.first : null);

    if (picked == null) return;

    setState(() {
      _variantId = picked.id;
      _quantity = 1;
    });
  }

  Future<void> _addToCart() async {
    final product = _product;
    if (product == null || _isAdding) return;

    setState(() => _isAdding = true);

    // В корзину уходит номер ВАРИАНТА, если он выбран: остаток и цена лежат
    // на нём, и заказ модели означал бы заказ неизвестно чего.
    final result = await CartService.add(_orderId, quantity: _quantity);

    if (!mounted) return;

    setState(() => _isAdding = false);

    if (!result.isOk) {
      SnackBarHelper.showError(context, result.error!);
      return;
    }

    SnackBarHelper.showSuccess(context, 'Товар в корзине');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Header(),
            _buildTopBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: activeIconColor),
                    )
                  : _product == null
                      ? const Center(
                          child: Text(
                            'Товар не найден',
                            style: TextStyle(color: textMuted, fontSize: 15),
                          ),
                        )
                      : _buildBody(_product!),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _product == null ? null : _buildBottomBar(_product!),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 8, 25, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Row(
              children: [
                Icon(Icons.arrow_back_ios, color: activeIconColor, size: 16),
                SizedBox(width: 4),
                Text(
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
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            ),
            child: const Icon(Icons.shopping_cart_outlined,
                color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ProductItem product) {
    // Картинки ВЫБРАННОГО варианта, если продавец их загрузил: красная куртка
    // должна выглядеть красной. Нет своих — показываем картинки модели.
    final variant = _variant;

    final variantImages = variant == null
        ? const <String>[]
        : (variant.images.isNotEmpty
            ? variant.images
            : (variant.image != null ? [variant.image!] : const <String>[]));

    final images = variantImages.isNotEmpty
        ? variantImages
        : (product.images.isNotEmpty
            ? product.images
            : (product.image != null ? [product.image!] : <String>[]));

    if (widget.fromOrder) return _buildOrderBody(product, images);

    return ListView(
      padding: const EdgeInsets.fromLTRB(25, 8, 25, 24),
      children: [
        if (images.isNotEmpty) _buildGallery(images),
        const SizedBox(height: 16),
        Text(
          // Цена ВЫБРАННОГО варианта: у 46-го и 54-го она бывает разной, и
          // показывать цену модели значит соврать о том, сколько человек
          // заплатит.
          _variant?.priceLabel ?? product.priceLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          product.name,
          style: const TextStyle(color: Colors.white, fontSize: 17),
        ),

        if (product.hasVariants) ...[
          const SizedBox(height: 14),
          _buildVariants(product),
        ],

        const SizedBox(height: 12),
        _buildStock(product),
        if (product.shop != null) ...[
          const SizedBox(height: 12),
          _buildShop(product.shop!),
        ],
        if (product.cookingTimeMinutes != null) ...[
          const SizedBox(height: 12),
          _card(
            child: Row(
              children: [
                const Icon(Icons.schedule, color: textSecondary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Готовят примерно ${product.cookingTimeMinutes} мин',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
        if (product.attributes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildAttributes(product),
        ],
        if (product.description != null && product.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Описание',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.description!,
                  style: const TextStyle(color: textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],

        // Кнопка на страницу продавца (15.09.2026). Сразу после описания:
        // человек уже понял, что это за вещь, и следующий его вопрос —
        // «а что ещё есть у этого продавца».
        //
        // Ведёт на ту же страницу, что кнопка с карточки объявления, и там
        // теперь лежат и объявления, и товары.
        if (product.shop?.userId != null) ...[
          const SizedBox(height: 12),
          _buildSellerButton(product.shop!),
        ],

        // Поделиться товаром (15.09.2026). Порядок как на карточке
        // объявления: после продавца, перед отзывами.
        const SizedBox(height: 12),
        _buildShareCard(product),

        // Отзывы покупателей (15.09.2026). Последним блоком: человек читает
        // их, когда уже посмотрел цену, размеры и описание.
        const SizedBox(height: 12),
        _buildReviews(product),
      ],
    );
  }

  /// Отзывы о товаре: оценка, звёзды и список.
  ///
  /// Оценка и число отзывов приходят с сервера посчитанными по одному
  /// правилу для витрины и карточки: опубликованные, четыре звезды и выше.
  /// Считать их здесь значило бы однажды показать в карточке одно число, а на
  /// главной другое.
  ///
  /// Отзыв оставляется ЗВЁЗДАМИ (15.09.2026), как на карточке объявления: пять
  /// звёзд, нажатие на любую открывает диалог с этой оценкой. Так было:
  /// кнопка «Оставить отзыв» показывалась только тому, кому она разрешена, а
  /// остальные видели блок, который выглядел как сломанный — заголовок,
  /// пустая звезда и строка мелким шрифтом.
  ///
  /// Звёзды видны и нажимаются у ВСЕХ, включая тех, кому отзыв не положен:
  /// правило «отзыв оставляет только тот, кто купил» никуда не делось, но
  /// объяснять его надо в ответ на действие, а не заранее и мелко. Отказ
  /// приходит словами с сервера, своих не выдумываем.
  Widget _buildReviews(ProductItem product) {
    final reviews = product.reviews;
    final mine = product.myReview;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок ОДИН (15.09.2026, просьба заказчика). Раньше их было
          // два подряд: «Отзывы» со сводкой оценки и под ним «Оставить отзыв».
          // Слово «отзыв» дважды в одном блоке читается как недоделка, а
          // оценка товара и так стоит на его карточке в ленте и на экране
          // всех отзывов.
          Text(
            mine == null ? 'Оставить отзыв' : 'Изменить отзыв',
            style: const TextStyle(
              color: textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),

          // Звёзды тем же размером и цветом, что на карточке объявления:
          // человек уже пользовался ими там, и вторые, устроенные по-своему,
          // заставили бы его разбираться заново.
          //
          // Подсвечены по своему прежнему отзыву, если он есть: человек
          // должен видеть, что именно он тогда поставил.
          Row(
            children: List.generate(
              5,
              (index) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onReviewStarTap(product, index + 1),
                child: Icon(
                  Icons.star,
                  color: index < (_selectedStars == 0
                          ? (mine?.rating ?? 0)
                          : _selectedStars)
                      ? Colors.amber
                      : Colors.grey,
                  size: 32,
                ),
              ),
            ),
          ),

          // Синяя ссылка «Все отзывы», как у объявления: в карточке лежат
          // последние десять, остальные на своём экране. Показываем всегда,
          // даже когда отзывов нет: там же объяснено, откуда они берутся, и
          // человеку не надо гадать, почему пусто.
          const SizedBox(height: 2),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openAllReviews(product),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Все отзывы',
                style: TextStyle(
                  color: activeIconColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          for (final review in reviews) ...[
            const SizedBox(height: 12),
            _reviewTile(review),
          ],
        ],
      ),
    );
  }

  /// Экран со всеми отзывами товара.
  ///
  /// Оценку и число отзывов передаём готовыми: их посчитал сервер по всем
  /// отзывам сразу, а считать среднее по первой странице значит показать на
  /// двух экранах разные числа для одного товара.
  Future<void> _openAllReviews(ProductItem product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductReviewsScreen(
          productId: product.id,
          productName: product.name,
          rating: product.rating,
          reviewsCount: product.reviewsCount,
        ),
      ),
    );
  }

  /// Нажатие по звезде.
  ///
  /// Отказ объясняем ЗДЕСЬ и словами сервера: правило «отзыв оставляет только
  /// тот, кто купил» живёт на сервере, и переписывать его текст в приложении
  /// значит однажды сказать человеку не то, за что его на самом деле не
  /// пустили.
  Future<void> _onReviewStarTap(ProductItem product, int rating) async {
    if (!product.canReview) {
      SnackBarHelper.showWarning(
        context,
        product.reviewNotAllowed ??
            'Отзыв можно оставить после того, как заберёте заказ с этим товаром',
      );

      return;
    }

    setState(() => _selectedStars = rating);

    await _openReviewDialog(product, rating: rating);

    if (!mounted) return;

    // Своя подсветка нужна только пока открыт диалог: после сохранения
    // карточка перечитана, и звёзды загорятся по настоящему отзыву.
    setState(() => _selectedStars = 0);
  }

  Widget _reviewTile(ProductReview review) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(
                i <= review.rating ? Icons.star : Icons.star_border,
                color: const Color(0xFFF5B301),
                size: 15,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                review.author.isEmpty ? 'Покупатель' : review.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            Text(
              review.shortDate,
              style: const TextStyle(color: textMuted, fontSize: 12),
            ),
          ],
        ),
        if (review.comment.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            review.comment,
            style: const TextStyle(color: textSecondary, fontSize: 13),
          ),
        ],
      ],
    );
  }

  Future<void> _openReviewDialog(ProductItem product, {int rating = 0}) async {
    final saved = await showProductReviewDialog(
      context: context,
      productId: product.id,
      title: product.name,
      existing: product.myReview,
      initialRating: rating,
    );

    // Перечитываем карточку целиком: после отзыва меняется не только список,
    // но и оценка, и подпись кнопки.
    if (saved == true && mounted) await _load();
  }

  /// Характеристики товара.
  ///
  /// Название слева, значение справа: так их читают глазами, сравнивая два
  /// товара. Набор полей задаётся в админке на раздел, поэтому рисуем то,
  /// что пришло, и ничего не подписываем от себя.
  /// «Этот товар покупают на месте».
  ///
  /// Текст берём с сервера: одна и та же фраза нужна сайту, приложению и
  /// админке, и написанная в трёх местах она разойдётся. Свой запасной
  /// вариант оставлен на случай старого сервера, который поле не присылает.
  Widget _buildOfflineNotice(ProductItem product) {
    final shopName = product.shop?.name;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(25, 8, 25, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront_outlined,
                    color: textSecondary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    product.orderNotice ??
                        'Этот товар не заказывают через сайт: '
                            'оплата и получение на месте, у продавца.',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
            if (shopName != null && shopName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Точка: $shopName',
                style: const TextStyle(color: textSecondary, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttributes(ProductItem product) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Характеристики',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...product.attributes.map(
            (attribute) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      attribute.title,
                      style: const TextStyle(color: textSecondary, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: Text(
                      attribute.value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  Вид «из заказа» (17.09.2026)
  // ══════════════════════════════════════════════════════════════════
  //
  // Тот же товар и тот же экран, но собранный под другой вопрос. В каталоге
  // человек выбирает и ему нужны размеры, остаток и корзина. Из своего заказа
  // он приходит посмотреть, ЧТО он купил и У КОГО, поэтому наверху дата и
  // артикул, а ниже продавец, жалоба и похожие предложения.

  Widget _buildOrderBody(ProductItem product, List<String> images) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (images.isNotEmpty) _buildGallery(images),
        const SizedBox(height: 12),
        _orderHeadCard(product),
        if (widget.order != null) ...[
          const SizedBox(height: 12),
          _yourOrderButton(),
        ],
        if (images.length > 1) ...[
          const SizedBox(height: 12),
          _thumbsRow(images),
        ],
        if (product.attributes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _orderAttributes(product),
        ],
        if ((product.description ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _orderDescription(product),
        ],
        if (_shopOf(product) != null) ...[
          const SizedBox(height: 12),
          _orderShopCard(_shopOf(product)!),
        ],
        const SizedBox(height: 12),
        _complaintCard(product),
        const SizedBox(height: 16),
        _similarBlock(),
      ],
    );
  }

  /// Дата, артикул, название, цена и оценка звёздами.
  Widget _orderHeadCard(ProductItem product) {
    final date = product.date.trim();
    final sku = (product.sku ?? '').trim();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (date.isNotEmpty || sku.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: Text(
                    date,
                    style: const TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ),
                if (sku.isNotEmpty)
                  Text(
                    '№ $sku',
                    style: const TextStyle(color: textSecondary, fontSize: 13),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            product.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            // Цена ВЫБРАННОГО варианта, как и в каталоге: у 46-го и 54-го она
            // бывает разной.
            _variant?.priceLabel ?? product.priceLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Оценка',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          _stars(product.rating, size: 24),
        ],
      ),
    );
  }

  /// «Ваш заказ»: код получения, отказ и вопросы.
  ///
  /// Из полного списка заказов человек попадает на карточку товара, и без
  /// этой кнопки к своему коду он бы оттуда не вернулся.
  Widget _yourOrderButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => YourOrderScreen(
              order: widget.order!,
              line: widget.orderLine,
            ),
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: const BorderSide(color: activeIconColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'Ваш заказ',
          style: TextStyle(color: activeIconColor, fontSize: 15),
        ),
      ),
    );
  }

  /// Звёзды по оценке. Пустая оценка это не ноль, а «ещё никто не оценил»,
  /// поэтому звёзды тогда серые, а не закрашенные наполовину.
  Widget _stars(double? rating, {double size = 16}) {
    final value = rating ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = value >= index + 0.5;

        return Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Icon(
            filled ? Icons.star : Icons.star_border,
            color: filled ? const Color(0xFFFFB800) : textMuted,
            size: size,
          ),
        );
      }),
    );
  }

  /// Ряд миниатюр под галереей. Нажатие листает саму галерею, а не открывает
  /// картинку отдельно: человек ждёт, что большая картинка сменится.
  Widget _thumbsRow(List<String> images) {
    return _card(
      child: SizedBox(
        height: 74,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: images.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, index) {
            final isCurrent = index == _currentImage;

            return GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              },
              child: Container(
                width: 74,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCurrent ? activeIconColor : Colors.transparent,
                    width: 1.6,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.network(
                    images[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: primaryBackground,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: textMuted,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Характеристики, свёрнутые до пяти строк.
  Widget _orderAttributes(ProductItem product) {
    final all = product.attributes;
    final visible = _attributesExpanded || all.length <= _shortAttributes
        ? all
        : all.take(_shortAttributes).toList();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Характеристики',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...visible.map(
            (attribute) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      attribute.title,
                      style: const TextStyle(color: textSecondary, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: Text(
                      attribute.value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (all.length > _shortAttributes)
            _expandLink(
              _attributesExpanded ? 'Свернуть' : 'Все характеристики',
              _attributesExpanded,
              () => setState(() => _attributesExpanded = !_attributesExpanded),
            ),
        ],
      ),
    );
  }

  /// Описание, свёрнутое до нескольких строк.
  Widget _orderDescription(ProductItem product) {
    final text = product.description!.trim();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Описание',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            maxLines: _descriptionExpanded ? null : _shortDescriptionLines,
            overflow: _descriptionExpanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          _expandLink(
            _descriptionExpanded ? 'Свернуть' : 'Все описание',
            _descriptionExpanded,
            () => setState(() => _descriptionExpanded = !_descriptionExpanded),
          ),
        ],
      ),
    );
  }

  Widget _expandLink(String title, bool expanded, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(color: activeIconColor, fontSize: 14),
            ),
            const SizedBox(width: 4),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: activeIconColor,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  /// Магазин: логотип, название, год, оценка, подписка и две кнопки.
  Widget _orderShopCard(ShopBrief shop) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Магазин',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shopLogo(shop),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((shop.since ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'На Лидле с ${shop.since}г',
                          style: const TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Text(
                            'Оценка: ',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const Icon(
                            Icons.star,
                            color: Color(0xFFFFB800),
                            size: 14,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            // Пусто, а не ноль: «нет оценок» и «оценка ноль»
                            // это разные вещи, и продавцу без отзывов нельзя
                            // рисовать худшую оценку.
                            shop.rating == null
                                ? 'нет оценок'
                                : shop.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _subscribeButton(shop),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _writeSeller(shop),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Написать продавцу',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openSeller(shop),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: activeIconColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Все товары',
                        style: TextStyle(color: activeIconColor, fontSize: 14),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: activeIconColor,
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shopLogo(ShopBrief shop) {
    final image = (shop.image ?? '').trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        width: 56,
        height: 56,
        child: image.isEmpty
            ? _shopLogoFallback(shop)
            : Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _shopLogoFallback(shop),
              ),
      ),
    );
  }

  /// Заглушка логотипа: первая буква названия. Чужую картинку сюда ставить
  /// нельзя, а пустой серый круг ничего не говорит.
  Widget _shopLogoFallback(ShopBrief shop) {
    final name = shop.name.trim();
    final letter = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

    return Container(
      color: primaryBackground,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _subscribeButton(ShopBrief shop) {
    if (shop.userId == null) return const SizedBox.shrink();

    if (_subscribing) {
      return const Padding(
        padding: EdgeInsets.only(left: 8, top: 4),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _toggleSubscription(shop),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, top: 2),
        child: Text(
          shop.isWishlisted ? 'Вы подписаны' : 'Подписаться',
          style: TextStyle(
            color: shop.isWishlisted ? textSecondary : activeIconColor,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  /// Подписка на продавца.
  ///
  /// Отдельной ручки подписки в проекте нет: подписка это запись избранного с
  /// типом «пользователь», ровно та же, что на странице продавца. Поэтому и
  /// здесь те же два запроса, а не свой способ.
  Future<void> _toggleSubscription(ShopBrief shop) async {
    final token = TokenService.currentToken;

    if (token == null || token.isEmpty) {
      SnackBarHelper.showWarning(
        context,
        'Войдите в профиль, чтобы подписаться на магазин',
      );

      return;
    }

    setState(() => _subscribing = true);

    try {
      if (shop.isWishlisted && shop.wishlistId != null) {
        await ApiService.delete('/me/wishlist/destroy/${shop.wishlistId}');

        _applySubscription(isWishlisted: false, wishlistId: null);
      } else {
        final response = await ApiService.post(
          '/me/wishlist/add',
          {'user_id': shop.userId},
        );

        final id = response['wishlist_id'] ??
            (response['data'] is Map ? response['data']['wishlist_id'] : null);

        _applySubscription(
          isWishlisted: true,
          wishlistId: id is int ? id : int.tryParse('$id'),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Не получилось. Попробуйте ещё раз');
      }
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  void _applySubscription({required bool isWishlisted, int? wishlistId}) {
    final shop = _shopOf(_product);

    if (shop == null || !mounted) return;

    // Меняем только точку, а не весь товар: подписка не меняет ни цены, ни
    // остатка, и пересобирать ради неё модель из тридцати полей незачем.
    setState(() {
      _shopOverride = shop.copyWithSubscription(
        isWishlisted: isWishlisted,
        wishlistId: wishlistId,
      );
    });
  }

  /// Чат с продавцом, без привязки к товару. Тот же способ, что на странице
  /// продавца: переписка одна, и заводить вторую под товар значит разнести
  /// разговор по двум местам.
  void _writeSeller(ShopBrief shop) {
    final token = TokenService.currentToken;

    if (token == null || token.isEmpty) {
      SnackBarHelper.showWarning(
        context,
        'Войдите в профиль, чтобы написать продавцу',
      );

      return;
    }

    if (shop.userId == null) {
      SnackBarHelper.showWarning(context, 'Продавец недоступен');

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          message: Message(
            senderName: shop.name,
            senderAvatar: shop.image,
            lastMessageTime: 'сейчас',
            unreadCount: 0,
            isInternal: true,
            isCompany: false,
            userId: '${shop.userId}',
          ),
        ),
      ),
    );
  }

  void _openSeller(ShopBrief shop) {
    if (shop.userId == null) {
      SnackBarHelper.showWarning(context, 'Продавец недоступен');

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerProfileScreen(
          sellerName: shop.name,
          sellerAvatar:
              const AssetImage('assets/profile_dashboard/default-photo.svg'),
          sellerAvatarUrl: shop.image,
          userId: '${shop.userId}',
        ),
      ),
    );
  }

  Widget _complaintCard(ProductItem product) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Оставить жалобу на товар',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Вы можете оставить жалобу на товар в случае нарушения правил',
            style: TextStyle(color: textSecondary, fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => showDialog<bool>(
              context: context,
              builder: (_) => ReportProductDialog(productId: product.id),
            ),
            behavior: HitTestBehavior.opaque,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Пожаловаться',
                  style: TextStyle(color: Color(0xFFE05B5B), fontSize: 15),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFFE05B5B),
                  size: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Похожие предложения.
  ///
  /// Пустой блок не рисуем вовсе: заголовок над пустым местом выглядит как
  /// не загрузившийся экран.
  Widget _similarBlock() {
    if (_similarLoading && _similar.isEmpty) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_similar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Похожие предложения',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _similar.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => _similarCard(_similar[index]),
          ),
        ),
      ],
    );
  }

  Widget _similarCard(ProductItem item) {
    final image = item.image ?? (item.images.isEmpty ? null : item.images.first);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          // Открываем в ТОМ ЖЕ виде: человек листает похожие одно за другим, и
          // менять вид на полпути значит менять правила игры на ходу.
          builder: (_) => ProductDetailsScreen(
            productId: item.id,
            fromOrder: true,
          ),
        ),
      ),
      child: SizedBox(
        width: 165,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 165,
                    height: 165,
                    child: image == null
                        ? Container(
                            color: secondaryBackground,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: textMuted,
                              size: 28,
                            ),
                          )
                        : Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: secondaryBackground,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: textMuted,
                                size: 28,
                              ),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: _SimilarFavorite(productId: item.id),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            if ((item.shop?.name ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  item.shop!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: textSecondary, fontSize: 13),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              item.priceLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGallery(List<String> images) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 280,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentImage = index),
              itemCount: images.length,
              itemBuilder: (context, index) => Image.network(
                images[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: secondaryBackground,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported_outlined,
                      color: textMuted, size: 40),
                ),
              ),
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              images.length,
              (index) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == _currentImage ? activeIconColor : textMuted,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStock(ProductItem product) {
    // Остаток берём у выбранного варианта: у красной 46-го он свой, и остаток
    // модели здесь ничего не значит.
    if (!_canBuy) {
      return _card(
        child: Text(
          product.hasVariants && _variant != null
              ? 'Этого варианта сейчас нет'
              : 'Нет в наличии',
          style: const TextStyle(color: textMuted, fontSize: 15),
        ),
      );
    }

    return _card(
      // Счётчик здесь — это «сколько положить». Как только товар в корзине,
      // количеством распоряжается счётчик внизу, у зелёной кнопки
      // (15.09.2026). Два счётчика на одном экране, отвечающие за одно и то
      // же число, — это вопрос «а какой из них настоящий», и задать его
      // некому.
      child: ValueListenableBuilder<Map<int, int>>(
        valueListenable: CartService.quantities,
        builder: (context, quantities, _) {
          final inCart = quantities[_orderId] ?? 0;

          return Row(
            children: [
              Text(
                'В наличии: $_availableStock шт.',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const Spacer(),
              if (inCart == 0)
                _stepper(product)
              else
                Text(
                  'В корзине: $inCart шт.',
                  style: const TextStyle(color: inCartGreen, fontSize: 15),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Выбор цвета и размера.
  ///
  /// Цвета квадратиками, размеры кнопками — так их показывают везде, где
  /// человек уже покупал одежду, и объяснять ничего не приходится.
  ///
  /// Показываем ВСЕ цвета и размеры модели, а не только те, что есть в
  /// наличии: покупатель должен видеть, что 46-й бывает, просто кончился.
  /// Недоступное гасим и перечёркиваем.
  Widget _buildVariants(ProductItem product) {
    final colors = <int, ProductVariant>{};
    final sizes = <int, ProductVariant>{};

    for (final variant in product.variants) {
      final colorId = variant.colorId;
      final sizeId = variant.dimensionId;

      if (colorId != null) colors.putIfAbsent(colorId, () => variant);
      if (sizeId != null) sizes.putIfAbsent(sizeId, () => variant);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Цвет у товара ОДИН: зелёная куртка это другой товар, а не другой
        // вариант этого (решение заказчика 14.09.2026). Поэтому при одном
        // цвете рисуем строку словом, а не квадратик, который некуда
        // переключать. Несколько цветов остались возможны у товаров, заведённых
        // до этого решения, и для них выбор работает по-прежнему.
        if (colors.length == 1) ...[
          Row(
            children: [
              const Text(
                'Цвет: ',
                style: TextStyle(color: textSecondary, fontSize: 14),
              ),
              if (_hex(colors.values.first.colorCode) != null) ...[
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _hex(colors.values.first.colorCode),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.white24),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                colors.values.first.colorName ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ] else if (colors.length > 1) ...[
          Text(
            _variant?.colorName == null
                ? 'Цвет'
                : 'Цвет: ${_variant!.colorName}',
            style: const TextStyle(color: textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: colors.entries
                .map((entry) => _colorChip(entry.key, entry.value))
                .toList(),
          ),
        ],

        if (sizes.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            _variant?.dimensionName == null
                ? 'Размер'
                : 'Размер: ${_variant!.dimensionName}',
            style: const TextStyle(color: textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sizes.entries
                .map((entry) => _sizeChip(product, entry.key, entry.value))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _colorChip(int colorId, ProductVariant sample) {
    final selected = _variant?.colorId == colorId;
    final color = _hex(sample.colorCode);

    // Есть ли у этого цвета хоть один вариант в наличии. Если нет — цвет
    // гасим: нажать можно, но человек сразу видит, что брать нечего.
    final available = (_product?.variants ?? const <ProductVariant>[]).any(
      (variant) =>
          variant.colorId == colorId && variant.isAvailable && variant.inStock,
    );

    return GestureDetector(
      onTap: () => _pickColor(colorId),
      child: Opacity(
        opacity: available ? 1 : 0.4,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color ?? secondaryBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? activeIconColor : Colors.white24,
              width: selected ? 3 : 1,
            ),
          ),
          child: color == null
              ? const Icon(Icons.palette_outlined, color: textMuted, size: 18)
              : null,
        ),
      ),
    );
  }

  Widget _sizeChip(ProductItem product, int sizeId, ProductVariant sample) {
    final selected = _variant?.dimensionId == sizeId;
    final currentColor = _variant?.colorId;

    // Доступен ли этот размер В ВЫБРАННОМ ЦВЕТЕ. Именно так человек и
    // рассуждает: «зелёная есть, а зелёной 46-го нет».
    final available = product.variants.any(
      (variant) =>
          variant.dimensionId == sizeId &&
          (currentColor == null || variant.colorId == currentColor) &&
          variant.isAvailable &&
          variant.inStock,
    );

    return GestureDetector(
      onTap: () => _pickSize(sizeId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? activeIconColor : formBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? activeIconColor : Colors.white24,
          ),
        ),
        child: Text(
          sample.dimensionName ?? '—',
          style: TextStyle(
            color: selected
                ? Colors.white
                : (available ? Colors.white : textMuted),
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,

            // Перечёркнутый размер это «бывает, но сейчас нет». Спрятать его
            // значит заставить человека гадать, шьют ли такой вообще.
            decoration: available ? null : TextDecoration.lineThrough,
            decorationColor: textMuted,
          ),
        ),
      ),
    );
  }

  /// «#43A047» в цвет.
  Color? _hex(String? code) {
    final hex = (code ?? '').replaceFirst('#', '').trim();

    if (hex.length != 6) return null;

    final value = int.tryParse(hex, radix: 16);

    return value == null ? null : Color(0xFF000000 | value);
  }

  /// Счётчик ограничен остатком: предлагать взять больше, чем есть, значит
  /// обещать то, чего мы не выполним, а отказ придёт только при оформлении.
  Widget _stepper(ProductItem product) {
    return Row(
      children: [
        _stepButton(Icons.remove, _quantity > 1, () {
          setState(() => _quantity--);
        }),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '$_quantity',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _stepButton(Icons.add, _quantity < _availableStock, () {
          setState(() => _quantity++);
        }),
      ],
    );
  }

  Widget _stepButton(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: secondaryBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: enabled ? Colors.white : textMuted, size: 18),
      ),
    );
  }

  /// Ссылка на товар на сайте.
  ///
  /// Вид тот же, что у объявления (`/advertisements/{id}-{слаг}`), только
  /// раздел свой. ВНИМАНИЕ: адрес страницы товара на сайте нигде не записан,
  /// он выведен по образцу объявления — если сайт откроет товары по другому
  /// пути, править надо ЗДЕСЬ, одно место на весь экран.
  ///
  /// Слаг приходит с сервера. Нет слага — обходимся номером: ссылка с одним
  /// номером рабочая, просто некрасивая.
  String _productUrl(ProductItem product) {
    final base = '${AppConfig().websiteUrl}/products';
    final slug = product.slug ?? '';

    return slug.isEmpty ? '$base/${product.id}' : '$base/${product.id}-$slug';
  }

  /// «Поделиться товаром» (15.09.2026).
  ///
  /// Тот же блок, что на карточке объявления: заголовок с шевроном, ряд
  /// иконок соцсетей и кнопка системного окна «Поделиться». Иконки видны
  /// всегда, свёрнут только поясняющий текст.
  ///
  /// Кнопки с QR-кодом здесь нет: экран с кодом написан под объявление и
  /// принимает его номер. Товарам такой же нужен отдельно, и делать вид, что
  /// он уже есть, значит показать кнопку, которая откроет чужую страницу.
  Widget _buildShareCard(ProductItem product) {
    final url = _productUrl(product);

    final text = '${product.name}\n'
        'Цена: ${product.priceLabel}\n\n'
        'Присоединяйся к LIDLE!\n'
        '$url';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _shareExpanded = !_shareExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Row(
                children: [
                  const Text(
                    'Поделиться товаром',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _shareExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: textSecondary,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: ShareIconsRow(url: url, text: product.name),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SizedBox(
              width: double.infinity,
              height: 47,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeIconColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Share.share(text),
                icon: const Icon(Icons.share, color: Colors.white, size: 18),
                label: const Text(
                  'Поделиться ссылкой',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          if (_shareExpanded)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                'Отправьте ссылку друзьям или в соцсети удобным для вас способом',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// «Все объявления и товары продавца» (15.09.2026).
  ///
  /// Вид и поведение те же, что у такой же кнопки на карточке объявления:
  /// человек уже видел её там, и вторая, устроенная по-своему, заставила бы
  /// его разбираться заново.
  ///
  /// Имя продавца берём у точки, а не у профиля: профиль приедет на самой
  /// странице продавца, а пока её ещё нет, название точки — самое честное,
  /// что мы можем написать. Аватарку не передаём вовсе: карточка товара её не
  /// знает, а страница продавца сама показывает заглушку и грузит настоящую.
  Widget _buildSellerButton(ShopBrief shop) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SellerProfileScreen(
            sellerName: shop.name,
            sellerAvatar:
                const AssetImage('assets/profile_dashboard/default-photo.svg'),
            userId: '${shop.userId}',
          ),
        ),
      ),
      child: Container(
        height: 47,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: activeIconColor),
        ),
        child: const Center(
          child: Text(
            'Все объявления и товары продавца',
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

  Widget _buildShop(ShopBrief shop) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Где забрать',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            shop.name,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          if (shop.address != null && shop.address!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              shop.address!,
              style: const TextStyle(color: textSecondary, fontSize: 14),
            ),
          ],
          const SizedBox(height: 6),
          const Text(
            'Доставки нет: заказ забирают в точке по коду получения.',
            style: TextStyle(color: textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ProductItem product) {
    // Раздел без атрибута оплаты не заказывается вовсе. Кнопку не рисуем:
    // нажать её всё равно нельзя, сервер откажет при оформлении, и человек
    // решит, что сломалось приложение. Вместо неё объяснение с сервера.
    if (!product.canOrder) {
      return _buildOfflineNotice(product);
    }

    final canBuy = _canBuy;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(25, 8, 25, 12),

        // Количество берём из ОБЩЕГО состояния корзины, а не из своего поля:
        // товар могли положить или убрать на другом экране, и собственная
        // память карточки разошлась бы с правдой.
        child: ValueListenableBuilder<Map<int, int>>(
          valueListenable: CartService.quantities,
          builder: (context, quantities, _) {
            final inCart = canBuy ? (quantities[_orderId] ?? 0) : 0;

            final cart = inCart == 0
                ? _buildAddButton(product, canBuy)
                : _buildInCartRow(inCart);

            // Из заказа рядом с корзиной стоит «В избранное»: человек смотрит
            // на уже купленную вещь, и чаще хочет отложить её на потом, чем
            // купить второй раз прямо сейчас.
            if (!widget.fromOrder) {
              return SizedBox(height: 50, child: cart);
            }

            return SizedBox(
              height: 50,
              child: Row(
                children: [
                  Expanded(child: _favoriteButton(product)),
                  const SizedBox(width: 10),
                  Expanded(child: cart),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// «В избранное» рядом с корзиной, в виде «из заказа».
  ///
  /// Состояние берём из общей памяти избранного, а не из своего поля: тот же
  /// товар виден и в ленте, и в похожих предложениях, и собственная память
  /// карточки разошлась бы с правдой.
  Widget _favoriteButton(ProductItem product) {
    return ValueListenableBuilder<Map<int, int?>>(
      valueListenable: ProductFavoritesService.items,
      builder: (context, _, __) {
        final isFavorite = ProductFavoritesService.isFavorite(product.id);

        return OutlinedButton(
          onPressed: () async {
            final error = await ProductFavoritesService.toggle(product.id);

            if (error != null && mounted) {
              SnackBarHelper.showError(context, error);
            }
          },
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? const Color(0xFFE05B5B) : Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  isFavorite ? 'В избранном' : 'В избранное',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Кнопка «В корзину», пока товара в корзине нет.
  Widget _buildAddButton(ProductItem product, bool canBuy) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: canBuy ? activeIconColor : secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: canBuy && !_isAdding ? _addToCart : null,
      child: Text(
        // «В корзину», а не «Добавить в корзину» (15.09.2026, просьба
        // заказчика): короче и совпадает с надписью на карточке в ленте.
        canBuy
            ? 'В корзину'
            : (product.hasVariants ? 'Этого варианта нет' : 'Нет в наличии'),
        style: TextStyle(
          color: canBuy ? Colors.white : textMuted,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Товар уже в корзине: зелёная кнопка и счётчик справа (15.09.2026).
  ///
  /// Зелёный цвет здесь несёт смысл, а не украшает: он отличает «уже лежит» от
  /// «положить», и человек видит состояние, не читая надпись. Второе нажатие
  /// по зелёной кнопке ведёт В КОРЗИНУ, а не кладёт второй раз — так устроены
  /// маркетплейсы, к которым покупатель привык.
  Widget _buildInCartRow(int inCart) {
    // Кнопка и счётчик ровно пополам (15.09.2026, просьба заказчика). Оба
    // `Expanded`, а не кнопка на весь остаток и счётчик по содержимому: при
    // втором варианте ширина счётчика прыгала от числа — «1» и «10» дают
    // разную ширину, — и кнопка каждый раз меняла размер.
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: inCartGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isAdding ? null : _openCart,
              child: const Text(
                'В корзине',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _buildCartStepper(inCart)),
      ],
    );
  }

  /// Минус, количество, плюс — правее зелёной кнопки.
  ///
  /// Меняет количество СРАЗУ в корзине, а не «сколько положу, когда нажму»:
  /// товар уже лежит там, и второе число рядом с первым человек читать не
  /// обязан.
  Widget _buildCartStepper(int inCart) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _cartStep(Icons.remove, () => _setCartQuantity(inCart - 1)),
          Expanded(
            child: Center(
              child: Text(
                '$inCart',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          _cartStep(
            Icons.add,
            // Больше остатка набрать не даём: отказ придёт только при
            // оформлении, а погасший плюс говорит о том же сразу.
            inCart < _availableStock
                ? () => _setCartQuantity(inCart + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _cartStep(IconData icon, VoidCallback? onTap) {
    final disabled = onTap == null || _isAdding;

    return GestureDetector(
      onTap: disabled ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 42,
        height: 50,
        // Минус и плюс синим, число белым (15.09.2026, просьба заказчика).
        // Цвет тот же, что у всех остальных действий в приложении: так видно,
        // что нажимается именно знак, а число рядом просто показание.
        child: Icon(
          icon,
          size: 20,
          color: disabled ? textMuted : activeIconColor,
        ),
      ),
    );
  }

  /// Изменить количество уже лежащего в корзине товара.
  ///
  /// Ноль удаляет позицию: минус до единицы и упор в неё заставляют искать
  /// отдельную кнопку удаления, которой на этом экране нет.
  Future<void> _setCartQuantity(int quantity) async {
    if (_isAdding) return;

    setState(() => _isAdding = true);

    final result = quantity <= 0
        ? await CartService.remove(_orderId)
        : await CartService.setQuantity(_orderId, quantity);

    if (!mounted) return;

    setState(() => _isAdding = false);

    if (!result.isOk) SnackBarHelper.showError(context, result.error!);
  }

  /// Открыть корзину, отметив в ней ЭТОТ товар.
  ///
  /// Отметка обязательна (15.09.2026): человек пришёл в корзину из карточки
  /// конкретной вещи, и заставлять его искать её галочку среди прочих значит
  /// потерять покупку на ровном месте.
  Future<void> _openCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartScreen(preselectedProductIds: {_orderId}),
      ),
    );

    if (!mounted) return;

    // Возвращаемся — перечитываем корзину: в ней могли поменять количество
    // или оформить заказ, и кнопка внизу обязана это показать.
    await CartService.sync();
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

/// Сердечко на карточке похожего предложения.
///
/// Своим виджетом, а не полем экрана: состояние избранного общее на всё
/// приложение, и перерисовывать ради одного сердечка весь экран незачем.
class _SimilarFavorite extends StatelessWidget {
  final int productId;

  const _SimilarFavorite({required this.productId});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<int, int?>>(
      valueListenable: ProductFavoritesService.items,
      builder: (context, _, __) {
        final isFavorite = ProductFavoritesService.isFavorite(productId);

        return GestureDetector(
          onTap: () async {
            final error = await ProductFavoritesService.toggle(productId);

            if (error != null && context.mounted) {
              SnackBarHelper.showError(context, error);
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Color(0xCC1E2831),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? const Color(0xFFE05B5B) : Colors.white,
              size: 18,
            ),
          ),
        );
      },
    );
  }
}
