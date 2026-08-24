// ============================================================
//  "Экран отзывов личного кабинета"
//  Три вкладки:
//    • Мои отзывы     — GET /v1/me/reviews (что я оставил другим)
//    • Мои объявления — GET /v1/me/received-reviews (что оставили мне)
//    • Моя компания   — GET /v1/company/reviews (отзывы о моей компании,
//                       включая оценки 1-3, которых нет на публичной странице)
//  Пагинация подгружается при прокрутке, потянуть вниз — перезагрузить.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart';
import 'package:lidle/blocs/navigation/navigation_event.dart';
import 'package:lidle/blocs/navigation/navigation_state.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/review_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/widgets/cards/review_card.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/navigation/bottom_navigation.dart';
import 'package:lidle/widgets/sort_dialog.dart';

class ReviewsEmptyPage extends StatefulWidget {
  static const routeName = '/reviews-empty';

  const ReviewsEmptyPage({super.key});

  @override
  State<ReviewsEmptyPage> createState() => _ReviewsEmptyPageState();
}

/// Состояние одной вкладки: список, страница, признаки загрузки.
class _TabData {
  final List<ReviewModel> items = [];
  int page = 1;
  int lastPage = 1;
  bool loading = false;
  bool loadingMore = false;
  bool loadedOnce = false;
  String? error;

  bool get hasMore => page < lastPage;

  void reset() {
    items.clear();
    page = 1;
    lastPage = 1;
    error = null;
    loadedOnce = false;
  }
}

class _ReviewsEmptyPageState extends State<ReviewsEmptyPage> {
  static const _tabs = ['Мои отзывы', 'Мои объявления', 'Моя компания'];

  static const _kinds = [
    ReviewKind.mine,
    ReviewKind.received,
    ReviewKind.company,
  ];

  int _currentTab = 0;
  SortOption? _sortOption;

  late final List<_TabData> _data =
      List.generate(_tabs.length, (_) => _TabData());

  final ScrollController _scrollController = ScrollController();

  _TabData get _current => _data[_currentTab];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadTab(_currentTab);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // Подгружаем следующую страницу, когда осталось меньше двух экранов.
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  /// Запрос списка для вкладки. `reset` — перезагрузка с первой страницы.
  Future<void> _loadTab(int tabIndex, {bool reset = false}) async {
    final data = _data[tabIndex];
    if (data.loading) return;

    setState(() {
      if (reset) data.reset();
      data.loading = true;
      data.error = null;
    });

    try {
      final response = await _request(tabIndex, 1);
      final items = ReviewModel.listFromResponse(response, _kinds[tabIndex]);

      if (!mounted) return;
      setState(() {
        data.items
          ..clear()
          ..addAll(items);
        data.page = 1;
        data.lastPage = ReviewModel.lastPageFromResponse(response);
        data.loading = false;
        data.loadedOnce = true;
      });
    } catch (e) {
      log.d('Не удалось загрузить отзывы (вкладка $tabIndex): $e');
      if (!mounted) return;
      setState(() {
        data.loading = false;
        data.loadedOnce = true;
        data.error = 'Не удалось загрузить отзывы';
      });
    }
  }

  /// Догрузка следующей страницы текущей вкладки.
  Future<void> _loadMore() async {
    final data = _current;
    if (data.loading || data.loadingMore || !data.hasMore) return;

    final tabIndex = _currentTab;
    setState(() => data.loadingMore = true);

    try {
      final next = data.page + 1;
      final response = await _request(tabIndex, next);
      final items = ReviewModel.listFromResponse(response, _kinds[tabIndex]);

      if (!mounted) return;
      setState(() {
        data.items.addAll(items);
        data.page = next;
        data.lastPage = ReviewModel.lastPageFromResponse(response);
        data.loadingMore = false;
      });
    } catch (e) {
      log.d('Не удалось догрузить отзывы: $e');
      if (!mounted) return;
      setState(() => data.loadingMore = false);
    }
  }

  Future<Map<String, dynamic>> _request(int tabIndex, int page) {
    switch (tabIndex) {
      case 0:
        return ApiService.getMyReviews(page: page);
      case 1:
        return ApiService.getReceivedReviews(page: page);
      default:
        return ApiService.getMyCompanyReviews(page: page);
    }
  }

  void _switchTab(int index) {
    if (index == _currentTab) return;
    setState(() => _currentTab = index);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    // Вкладку грузим один раз, дальше показываем уже загруженное.
    if (!_data[index].loadedOnce) _loadTab(index);
  }

  /// Сортировка применяется к уже загруженным отзывам: бэк сортировку по
  /// оценке не поддерживает, поэтому при выборе «по оценке» упорядочиваем
  /// то, что подгружено, а не весь список на сервере.
  List<ReviewModel> _sorted(List<ReviewModel> items) {
    if (_sortOption != SortOption.byRating) return items;
    final copy = [...items];
    copy.sort((a, b) => b.rating.compareTo(a.rating));
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NavigationBloc, NavigationState>(
      listener: (context, state) {
        if (state is NavigationToProfile ||
            state is NavigationToHome ||
            state is NavigationToFavorites ||
            state is NavigationToMessages) {
          context.read<NavigationBloc>().executeNavigation(context);
        }
      },
      child: BlocBuilder<NavigationBloc, NavigationState>(
        builder: (context, navigationState) {
          return Scaffold(
            extendBody: true,
            backgroundColor: primaryBackground,
            body: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ───── Header ─────
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20, right: 25),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Header(),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),

                  // ───── Назад / сортировка ─────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const Text(
                          'Отзывы',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          child:
                              const Icon(Icons.swap_vert, color: Colors.white),
                          onTap: () async {
                            final selected = await showDialog<SortOption>(
                              context: context,
                              builder: (_) =>
                                  SortDialog(initialSortOption: _sortOption),
                            );
                            if (selected != null) {
                              setState(() => _sortOption = selected);
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildTabs(),

                  Expanded(child: _buildContent()),

                  const SizedBox(height: 80), // под bottom nav
                ],
              ),
            ),
            bottomNavigationBar: BottomNavigation(
              onItemSelected: (index) {
                context
                    .read<NavigationBloc>()
                    .add(SelectNavigationIndexEvent(index));
              },
            ),
          );
        },
      ),
    );
  }

  /// Три вкладки равной ширины с подчёркиванием активной. Ширину не считаем
  /// вручную — каждая вкладка рисует свою полоску, поэтому вёрстка не поедет
  /// при изменении подписей.
  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final active = index == _currentTab;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _switchTab(index),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Text(
                      _tabs[index],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? accentColor : Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    height: active ? 2 : 1,
                    color: active ? accentColor : Colors.white24,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildContent() {
    final data = _current;

    if (data.loading && data.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data.error != null && data.items.isEmpty) {
      return _message(
        title: 'Не удалось загрузить',
        subtitle: 'Проверьте соединение и попробуйте ещё раз.',
        action: TextButton(
          onPressed: () => _loadTab(_currentTab, reset: true),
          child: const Text('Повторить',
              style: TextStyle(color: Color(0xFF009EE2))),
        ),
      );
    }

    if (data.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadTab(_currentTab, reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.12),
            _message(
              title: 'У вас нет отзывов',
              subtitle: _emptySubtitle(),
            ),
          ],
        ),
      );
    }

    final items = _sorted(data.items);

    return RefreshIndicator(
      onRefresh: () => _loadTab(_currentTab, reset: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: items.length + (data.loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return ReviewCard(
            review: items[index],
            onChanged: () => _loadTab(_currentTab, reset: true),
          );
        },
      ),
    );
  }

  String _emptySubtitle() {
    switch (_currentTab) {
      case 0:
        return 'Вы пока не оставляли отзывов.\nОставьте отзыв после звонка продавцу.';
      case 1:
        return 'На ваши объявления пока нет отзывов.\nКак только покупатели их оставят,\nони появятся здесь.';
      default:
        return 'О вашей компании пока нет отзывов.\nОни появятся здесь, когда клиенты\nих оставят.';
    }
  }

  Widget _message({
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/offers/Applications_for_me.png',
          width: 100,
          height: 100,
        ),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 8),
          action,
        ],
      ],
    );
  }
}
