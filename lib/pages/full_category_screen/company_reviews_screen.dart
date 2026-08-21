import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/user_service.dart';
import 'package:lidle/widgets/dialogs/company_reply_dialog.dart';
import 'package:lidle/widgets/dialogs/review_complaint_dialog.dart';
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

  /// true — если экран открыл сам владелец компании (продавец). Только ему
  /// показываем кнопку «Ответить». Компания 1:1 с пользователем, поэтому
  /// сравниваем id текущего пользователя с companyId.
  bool _isSeller = false;

  /// Название компании для заголовка «Отзывы на компанию {name}». Сначала
  /// берём из параметра, затем обновляем актуальным значением с сервера
  /// (GET /companies/{id} → data.name), чтобы имя менялось динамически.
  String? _companyName;

  @override
  void initState() {
    super.initState();
    _isSeller = _computeIsSeller();
    _companyName = (widget.companyName ?? '').trim();
    _scrollController.addListener(_onScroll);
    _loadReviews();
    _loadCompanyName();
  }

  bool _computeIsSeller() {
    final me = UserService.getLocal('userId')?.toString().trim();
    return me != null && me.isNotEmpty && me == '${widget.companyId}';
  }

  /// Подтягивает актуальное название компании с сервера, чтобы в заголовке
  /// всегда было имя компании (а не имя/ник пользователя, переданные извне).
  Future<void> _loadCompanyName() async {
    try {
      final resp = await ApiService.get('/companies/${widget.companyId}');
      final data = (resp['data'] is Map)
          ? Map<String, dynamic>.from(resp['data'] as Map)
          : <String, dynamic>{};
      final nameRaw = data['name'];
      final name = (nameRaw is String && nameRaw.trim().isNotEmpty)
          ? nameRaw.trim()
          : '';
      if (name.isEmpty || !mounted) return;
      setState(() => _companyName = name);
    } catch (e) {
      log.d('Не удалось загрузить название компании для заголовка: $e');
    }
  }

  /// Заголовок экрана: «Отзывы на компанию {name}», либо просто «Отзывы».
  String get _headerTitle {
    final name = (_companyName ?? '').trim();
    return name.isEmpty ? 'Отзывы' : 'Отзывы на компанию $name';
  }

  /// Открыть диалог ответа продавца на отзыв [index]. При успехе обновляем
  /// ответ у этого отзыва прямо в списке (без перезагрузки).
  Future<void> _openReplyDialog(int index) async {
    final review = _reviews[index];
    final reviewId = int.tryParse('${review['id']}');
    if (reviewId == null) return;

    final current = (review['reply'] ?? '').toString();
    final res = await showCompanyReplyDialog(
      context: context,
      reviewId: reviewId,
      initialText: current,
    );
    if (!mounted || res == null) return;

    setState(() {
      _reviews[index] = {
        ...review,
        'reply': res['reply'] ?? review['reply'],
        'reply_date':
            _formatRuDate(res['replied_at']?.toString()) ?? review['reply_date'],
      };
    });
  }

  /// Открыть диалог жалобы на отзыв о компании [index]
  /// (POST /companies/{companyId}/reviews/{id}/report).
  Future<void> _openReportDialog(int index) async {
    final review = _reviews[index];
    final reviewId = int.tryParse('${review['id']}');
    if (reviewId == null) return;
    await showDialog<bool>(
      context: context,
      builder: (_) => ReviewComplaintDialog(
        reviewId: reviewId,
        target: ReviewComplaintTarget.company,
        companyId: widget.companyId,
      ),
    );
  }

  /// ISO-дату из ответа сервера превращаем в «19 августа» (как в GET-списке),
  /// чтобы новый ответ сразу выглядел единообразно. null, если распарсить нельзя.
  String? _formatRuDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return null;
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    if (dt.month < 1 || dt.month > 12) return null;
    return '${dt.day} ${months[dt.month - 1]}';
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
      // Владелец компании (продавец) видит ВСЕ свои отзывы (1-5) из личного
      // кабинета; остальные — только публичные (4-5).
      final response = _isSeller
          ? await ApiService.getMyCompanyReviews(page: 1)
          : await ApiService.getCompanyReviews(widget.companyId, page: 1);
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
      final response = _isSeller
          ? await ApiService.getMyCompanyReviews(page: next)
          : await ApiService.getCompanyReviews(widget.companyId, page: next);
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
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_back_ios,
                              color: textPrimary, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _headerTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
          return _ReviewCardItem(
            review: _reviews[index],
            isSeller: _isSeller,
            onReplyTap: () => _openReplyDialog(index),
            onReportTap: () => _openReportDialog(index),
          );
        },
      ),
    );
  }
}

/// Карточка одного отзыва: аватар, имя, дата, «Оценка» + звёзды, текст.
/// Если есть ответ продавца — показываем его блоком под отзывом (виден всем).
/// Продавцу (владельцу компании) дополнительно показываем кнопку «Ответить».
class _ReviewCardItem extends StatelessWidget {
  final Map<String, dynamic> review;
  final bool isSeller;
  final VoidCallback? onReplyTap;
  final VoidCallback? onReportTap;

  const _ReviewCardItem({
    required this.review,
    this.isSeller = false,
    this.onReplyTap,
    this.onReportTap,
  });

  int get _rating {
    final r = review['rating'];
    if (r is int) return r;
    return int.tryParse('${r ?? 0}') ?? 0;
  }

  String get _reply => (review['reply'] ?? '').toString().trim();

  String get _replyDate => (review['reply_date'] ?? '').toString().trim();

  bool get _hasReply => _reply.isNotEmpty;

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
          // Ответ продавца (виден всем, если он есть).
          if (_hasReply) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: formBackground,
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                  left: BorderSide(color: activeIconColor, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Ответ продавца',
                        style: TextStyle(
                          color: activeIconColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_replyDate.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          _replyDate,
                          style: const TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _reply,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Кнопка ответа — только для владельца компании (продавца).
          if (isSeller) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onReplyTap,
                style: TextButton.styleFrom(
                  foregroundColor: activeIconColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  _hasReply ? Icons.edit_outlined : Icons.reply,
                  size: 18,
                  color: activeIconColor,
                ),
                label: Text(
                  _hasReply ? 'Изменить ответ' : 'Ответить',
                  style: const TextStyle(
                    color: activeIconColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
          // Жалоба на отзыв — для всех, кроме владельца компании.
          if (!isSeller) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onReportTap,
                style: TextButton.styleFrom(
                  foregroundColor: textSecondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.flag_outlined,
                    size: 16, color: textSecondary),
                label: const Text(
                  'Пожаловаться',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
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
