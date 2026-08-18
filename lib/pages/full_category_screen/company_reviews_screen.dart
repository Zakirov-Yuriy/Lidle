import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/core/logger.dart';

// ============================================================
//  "Отзывы на компанию (продавца)"
// ============================================================
// Список отзывов компании: GET /v1/companies/{companyId}/reviews.
// Открывается из экрана продавца по ссылке «Все отзывы» под звёздами.

class CompanyReviewsScreen extends StatefulWidget {
  final int companyId;
  final String? companyName;

  const CompanyReviewsScreen({
    super.key,
    required this.companyId,
    this.companyName,
  });

  @override
  State<CompanyReviewsScreen> createState() => _CompanyReviewsScreenState();
}

class _CompanyReviewsScreenState extends State<CompanyReviewsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _reviews = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadReviews();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading) {
      _loadMore();
    }
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response =
          await ApiService.getCompanyReviews(widget.companyId, page: 1);
      final list = _extractList(response);
      if (!mounted) return;
      setState(() {
        _reviews
          ..clear()
          ..addAll(list);
        _page = 1;
        _hasMore = _hasNextPage(response);
        _isLoading = false;
      });
    } catch (e) {
      log.d('Ошибка загрузки отзывов компании: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Не удалось загрузить отзывы';
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final next = _page + 1;
      final response =
          await ApiService.getCompanyReviews(widget.companyId, page: next);
      final list = _extractList(response);
      if (!mounted) return;
      setState(() {
        _reviews.addAll(list);
        _page = next;
        _hasMore = _hasNextPage(response);
        _isLoadingMore = false;
      });
    } catch (e) {
      log.d('Ошибка подгрузки отзывов компании: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _hasMore = false;
      });
    }
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  bool _hasNextPage(Map<String, dynamic> response) {
    // Пагинация Laravel: meta.current_page < meta.last_page, либо links.next != null.
    final meta = response['meta'];
    if (meta is Map && meta['current_page'] != null && meta['last_page'] != null) {
      final cur = int.tryParse('${meta['current_page']}') ?? 1;
      final last = int.tryParse('${meta['last_page']}') ?? cur;
      return cur < last;
    }
    final links = response['links'];
    if (links is Map) {
      return links['next'] != null;
    }
    return false;
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
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 8, 25, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: const Row(
                      children: [
                        Icon(Icons.arrow_back_ios,
                            color: activeIconColor, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Отзывы',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: const Text(
                      'Назад',
                      style: TextStyle(
                        color: activeIconColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: activeIconColor),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: textSecondary)),
      );
    }
    if (_reviews.isEmpty) {
      return const Center(
        child: Text('Отзывов пока нет',
            style: TextStyle(color: textSecondary, fontSize: 15)),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadReviews,
      color: activeIconColor,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _reviews.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _reviews.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: activeIconColor),
              ),
            );
          }
          return _ReviewCardItem(review: _reviews[index]);
        },
      ),
    );
  }
}

/// Карточка одного отзыва: аватар, имя, дата, «Оценка» + звёзды, текст.
class _ReviewCardItem extends StatelessWidget {
  final Map<String, dynamic> review;

  const _ReviewCardItem({required this.review});

  int get _rating {
    final r = review['rating'];
    if (r is int) return r;
    return int.tryParse('${r ?? 0}') ?? 0;
  }

  String get _name {
    final n = review['user_name'] ?? review['title'];
    final s = (n ?? '').toString().trim();
    return s.isNotEmpty ? s : 'Пользователь';
  }

  String? get _avatar {
    final a = review['user_avatar'] ?? review['thumbnail'];
    final s = (a ?? '').toString().trim();
    return s.isNotEmpty ? s : null;
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _avatar;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: avatar != null
                      ? Image.network(
                          avatar,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _avatarPlaceholder(),
                        )
                      : _avatarPlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (review['date'] ?? '').toString(),
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Оценка',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      5,
                      (i) => Icon(
                        Icons.star,
                        size: 16,
                        color: i < _rating ? Colors.amber : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if ((review['comment'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review['comment'].toString(),
              style: const TextStyle(
                color: textSecondary,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: formBackground,
      child: const Icon(Icons.person, color: textSecondary, size: 28),
    );
  }
}
