// ============================================================
//  "Все отзывы о товаре" (15.09.2026)
//
//  Открывается с карточки товара по синей ссылке «Все отзывы» под звёздами —
//  ровно как у объявления.
//
//  Свой экран, а не общий с объявлением: у объявления отзыв относится к
//  сделке с человеком, и там есть ответ владельца и жалоба на отзыв. У товара
//  отзыв относится к вещи, писать его может только покупатель, и ни ответа,
//  ни жалобы на сервере для него пока нет. Экран, притворяющийся общим, показал
//  бы кнопки, которые ничего не делают.
//
//  В карточке товара показываются последние десять отзывов, здесь — все,
//  страницами по мере прокрутки.
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/products/product_item.dart';
import 'package:lidle/services/products_service.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductReviewsScreen extends StatefulWidget {
  const ProductReviewsScreen({
    super.key,
    required this.productId,
    this.productName = '',
    this.rating,
    this.reviewsCount = 0,
  });

  final int productId;

  /// Название товара для заголовка.
  final String productName;

  /// Оценка и число отзывов, уже посчитанные сервером для карточки.
  ///
  /// Передаём их сюда, а не считаем заново по списку: в списке лежит страница,
  /// а не все отзывы, и среднее по первой странице разошлось бы с числом на
  /// карточке.
  final double? rating;
  final int reviewsCount;

  @override
  State<ProductReviewsScreen> createState() => _ProductReviewsScreenState();
}

class _ProductReviewsScreenState extends State<ProductReviewsScreen> {
  final ScrollController _scroll = ScrollController();
  final List<ProductReview> _reviews = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isLoading) return;

    // Подгружаем заранее, за экран до конца: дождаться самого низа значит
    // показать человеку пустоту и заставить ждать сеть.
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    final page = await ProductsService.reviews(widget.productId);

    if (!mounted) return;

    setState(() {
      _reviews
        ..clear()
        ..addAll(page);
      _page = 1;
      _hasMore = page.isNotEmpty;
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);

    final next = await ProductsService.reviews(
      widget.productId,
      page: _page + 1,
    );

    if (!mounted) return;

    setState(() {
      _isLoadingMore = false;

      if (next.isEmpty) {
        _hasMore = false;

        return;
      }

      _page++;
      _reviews.addAll(next);
    });
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
                  : RefreshIndicator(
                      color: activeIconColor,
                      onRefresh: _load,
                      child: _buildList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 8, 25, 4),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
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
    );
  }

  Widget _buildList() {
    return ListView(
      controller: _scroll,

      // Прокрутка нужна всегда: без неё «потяните вниз» не работает на
      // коротком списке, а обновить его человек хочет именно тогда.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(25, 0, 25, 24),
      children: [
        Text(
          widget.productName.trim().isEmpty
              ? 'Отзывы'
              : 'Отзывы: ${widget.productName.trim()}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _buildSummary(),
        const SizedBox(height: 12),

        if (_reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text(
              'Отзывов пока нет. Их оставляют покупатели, забравшие заказ с '
              'этим товаром.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textMuted, fontSize: 15),
            ),
          )
        else
          for (final review in _reviews) ...[
            _buildTile(review),
            const SizedBox(height: 10),
          ],

        if (_isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: activeIconColor),
            ),
          ),
      ],
    );
  }

  /// Оценка и число отзывов сверху: то же, что человек видел на карточке.
  Widget _buildSummary() {
    if (widget.rating == null || widget.reviewsCount == 0) {
      return const Row(
        children: [
          Icon(Icons.star_border, color: Color(0xFFF5B301), size: 18),
          SizedBox(width: 6),
          Text(
            'Оценок пока нет',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(Icons.star, color: Color(0xFFF5B301), size: 18),
        const SizedBox(width: 4),
        Text(
          widget.rating!.toStringAsFixed(1).replaceAll('.', ','),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          _ratingsLabel(widget.reviewsCount),
          style: const TextStyle(color: textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildTile(ProductReview review) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= review.rating ? Icons.star : Icons.star_border,
                  color: const Color(0xFFF5B301),
                  size: 16,
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
            const SizedBox(height: 6),
            Text(
              review.comment,
              style: const TextStyle(color: textSecondary, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  /// «10 903 оценки» и «1 оценка»: число и слово должны сходиться.
  String _ratingsLabel(int count) {
    final last = count % 10;
    final lastTwo = count % 100;

    if (lastTwo >= 11 && lastTwo <= 14) return '$count оценок';
    if (last == 1) return '$count оценка';
    if (last >= 2 && last <= 4) return '$count оценки';

    return '$count оценок';
  }
}
