// ============================================================
//  "Все отзывы объявления"
//  Полный список с пагинацией. Открывается из блока отзывов
//  на карточке объявления по ссылке «Все отзывы».
//  Данные: GET /v1/advertisements/{id}/reviews
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/review_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/widgets/common/user_avatar.dart';

class AdvertReviewsScreen extends StatefulWidget {
  final int advertId;

  /// Показываем в подзаголовке, чтобы человек понимал, чьи это отзывы.
  final String advertTitle;

  const AdvertReviewsScreen({
    super.key,
    required this.advertId,
    this.advertTitle = '',
  });

  @override
  State<AdvertReviewsScreen> createState() => _AdvertReviewsScreenState();
}

class _AdvertReviewsScreenState extends State<AdvertReviewsScreen> {
  static const _star = Color(0xFFF5B301);

  final List<ReviewModel> _items = [];
  final ScrollController _scroll = ScrollController();

  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  bool get _hasMore => _page < _lastPage;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) _loadMore();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiService.getAdvertReviews(widget.advertId);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(ReviewModel.listFromResponse(response, ReviewKind.received));
        _page = 1;
        _lastPage = ReviewModel.lastPageFromResponse(response);
        _total = ReviewModel.totalFromResponse(response) ?? _items.length;
        _loading = false;
      });
    } catch (e) {
      log.d('Не удалось загрузить отзывы объявления: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить отзывы';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final response =
          await ApiService.getAdvertReviews(widget.advertId, page: next);
      if (!mounted) return;
      setState(() {
        _items.addAll(
          ReviewModel.listFromResponse(response, ReviewKind.received),
        );
        _page = next;
        _lastPage = ReviewModel.lastPageFromResponse(response);
        _loadingMore = false;
      });
    } catch (e) {
      log.d('Не удалось догрузить отзывы: $e');
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      appBar: AppBar(
        backgroundColor: formBackground,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Отзывы', style: TextStyle(fontSize: 18)),
            if (_total > 0)
              Text(
                '$_total ${_plural(_total)}',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
          ],
        ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _load,
              child: const Text('Повторить',
                  style: TextStyle(color: Color(0xFF009EE2))),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'У этого объявления пока нет отзывов',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) =>
            const Divider(color: Color(0xFF474747), height: 24),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _item(_items[index]);
        },
      ),
    );
  }

  Widget _item(ReviewModel review) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(url: review.imageUrl, size: 42),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (i) => Icon(
                          i < review.rating ? Icons.star : Icons.star_border,
                          color: _star,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        review.date,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (review.text.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            review.text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
        if (review.hasReply) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Ответ продавца',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if ((review.replyDate ?? '').isNotEmpty)
                      Text(
                        review.replyDate!,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  review.reply!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _plural(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'отзыв';
    if ((count % 10 >= 2 && count % 10 <= 4) &&
        (count % 100 < 10 || count % 100 >= 20)) {
      return 'отзыва';
    }
    return 'отзывов';
  }
}
