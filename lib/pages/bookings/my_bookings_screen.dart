import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/bookings/booking_item.dart';
import 'package:lidle/pages/full_category_screen/property_details_screen.dart';
import 'package:lidle/services/bookings_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';

/// Брони пользователя: две вкладки в одном экране.
///
/// «Мои брони» — куда я записался. «Заявки ко мне» — кто записался ко мне.
/// Два списка, а не один с пометкой роли: человек смотрит на них разными
/// глазами. В своих его занимает «подтвердили ли», во входящих «на что
/// ответить».
///
/// Кнопки рисуются по флагам сервера (`can_confirm`, `can_reject`,
/// `can_cancel`), а не по собственным вычислениям. Правило про «отменить не
/// позже чем за сутки» живёт на сервере в одном месте, и повторять его тут
/// значит однажды разойтись с ним.
class MyBookingsScreen extends StatefulWidget {
  static const routeName = '/my-bookings';

  /// 0 — мои брони, 1 — заявки ко мне.
  final int initialTab;

  const MyBookingsScreen({super.key, this.initialTab = 0});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  String _scope = 'upcoming';

  List<BookingItem> _mine = const [];
  List<BookingItem> _incoming = const [];

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Оба списка сразу: вкладки переключают мгновенно, и ждать загрузку
      // при каждом касании было бы утомительно.
      final results = await Future.wait([
        BookingsService.myBookings(scope: _scope),
        BookingsService.incoming(scope: _scope),
      ]);

      if (!mounted) return;

      setState(() {
        _mine = results[0];
        _incoming = results[1];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Не получилось загрузить брони. Потяните вниз, чтобы повторить.';
      });
    }
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
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: GestureDetector(
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
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(25, 12, 25, 0),
              child: Text(
                'Брони',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: textSecondary,
              indicatorColor: activeIconColor,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Мои брони'),
                Tab(text: 'Заявки ко мне'),
              ],
            ),
            _buildScopeSwitch(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList(_mine, isIncoming: false),
                  _buildList(_incoming, isIncoming: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeSwitch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 12, 25, 4),
      child: Row(
        children: [
          _scopeChip('upcoming', 'Предстоящие'),
          const SizedBox(width: 8),
          _scopeChip('past', 'Прошедшие'),
        ],
      ),
    );
  }

  Widget _scopeChip(String value, String title) {
    final isSelected = _scope == value;

    return GestureDetector(
      onTap: isSelected
          ? null
          : () {
              setState(() => _scope = value);
              _load();
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeIconColor : formBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<BookingItem> items, {required bool isIncoming}) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: activeIconColor),
      );
    }

    // Пустой список это не ошибка, а обычное состояние, и текст должен
    // объяснять, что делать дальше, а не сообщать о пустоте.
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: activeIconColor,
        backgroundColor: formBackground,
        child: ListView(
          children: [
            const SizedBox(height: 80),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _error ??
                      (isIncoming
                          ? _scope == 'past'
                              ? 'Прошедших заявок нет.'
                              : 'К вам пока никто не записался. Заявки появятся здесь, как только у ваших объявлений включат бронь и кто-то выберет время.'
                          : _scope == 'past'
                              ? 'Прошедших броней нет.'
                              : 'Вы пока никуда не записались. Время бронируется в карточке объявления, если у него подключена запись.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: textSecondary, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: activeIconColor,
      backgroundColor: formBackground,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(25, 12, 25, 40),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildCard(items[index]),
      ),
    );
  }

  Widget _buildCard(BookingItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdvertRow(item),
          const SizedBox(height: 10),
          _buildStatusRow(item),
          const SizedBox(height: 8),
          _buildTimeRow(item),
          if (item.counterparty != null) ...[
            const SizedBox(height: 8),
            _buildPartyRow(item),
          ],
          if (item.comment != null) ...[
            const SizedBox(height: 8),
            Text(
              item.comment!,
              style: const TextStyle(color: textSecondary, fontSize: 14),
            ),
          ],
          if (item.cancelReason != null) ...[
            const SizedBox(height: 8),
            Text(
              'Причина: ${item.cancelReason}',
              style: const TextStyle(color: textSecondary, fontSize: 13),
            ),
          ],
          _buildActions(item),
        ],
      ),
    );
  }

  Widget _buildAdvertRow(BookingItem item) {
    final advert = item.advert;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PropertyDetailsScreen(
            advertisementId: '${item.advertId}',
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 56,
              height: 56,
              child: advert?.thumbnail != null
                  ? Image.network(
                      advert!.thumbnail!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbStub(),
                    )
                  : _thumbStub(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  advert?.name ?? 'Объявление ${item.advertId}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (advert?.price != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    advert!.price!,
                    style: const TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbStub() {
    return Container(
      color: secondaryBackground,
      child: const Icon(Icons.image_outlined, color: textMuted, size: 22),
    );
  }

  Widget _buildStatusRow(BookingItem item) {
    // Цвет плашки несёт смысл: ждущая ответа заявка не должна выглядеть так
    // же, как подтверждённая или отменённая.
    final Color color;
    if (item.isPending) {
      color = const Color(0xFFE0A63C);
    } else if (item.isConfirmed) {
      color = const Color(0xFF3BA55D);
    } else {
      color = textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        item.statusTitle,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTimeRow(BookingItem item) {
    return Row(
      children: [
        const Icon(Icons.event, color: activeIconColor, size: 17),
        const SizedBox(width: 6),
        Text(
          _humanDate(item.startsAt),
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.schedule, color: activeIconColor, size: 17),
        const SizedBox(width: 6),
        Text(
          '${_time(item.startsAt)} — ${_time(item.endsAt)}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildPartyRow(BookingItem item) {
    final party = item.counterparty!;
    final label = item.isOwnerView ? 'Гость' : 'Владелец';

    return Row(
      children: [
        Expanded(
          child: Text(
            '$label: ${party.name.isEmpty ? 'без имени' : party.name}'
            '${party.phone == null ? '' : ', ${party.phone}'}',
            style: const TextStyle(color: textSecondary, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BookingItem item) {
    final buttons = <Widget>[];

    if (item.canConfirm) {
      buttons.add(_actionButton(
        'Подтвердить',
        const Color(0xFF3BA55D),
        () => _run(item, () => BookingsService.confirm(item.id)),
      ));
    }

    if (item.canReject) {
      buttons.add(_actionButton(
        'Отклонить',
        textMuted,
        () => _askReason(
          title: 'Отклонить заявку',
          onConfirmed: (reason) =>
              _run(item, () => BookingsService.reject(item.id, reason: reason)),
        ),
      ));
    }

    if (item.canCancel) {
      buttons.add(_actionButton(
        'Отменить',
        const Color(0xFFCE5A5A),
        () => _askReason(
          title: 'Отменить бронь',
          onConfirmed: (reason) =>
              _run(item, () => BookingsService.cancel(item.id, reason: reason)),
        ),
      ));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(spacing: 8, runSpacing: 8, children: buttons),
    );
  }

  Widget _actionButton(String title, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Причину спрашиваем, но не требуем: заставлять человека объясняться,
  /// чтобы отменить, невежливо, а вторая сторона всё равно получит
  /// уведомление.
  Future<void> _askReason({
    required String title,
    required void Function(String? reason) onConfirmed,
  }) async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: formBackground,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Причина, необязательно',
            hintStyle: TextStyle(color: textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Назад', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Подтвердить',
              style: TextStyle(color: activeIconColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onConfirmed(controller.text);
    }
  }

  Future<void> _run(BookingItem item, Future<BookingResult> Function() action) async {
    final result = await action();

    if (!mounted) return;

    if (result.isCreated) {
      SnackBarHelper.showSuccess(context, result.message);
    } else {
      SnackBarHelper.showError(context, result.message);
    }

    // Перечитываем в любом случае: если действие не прошло из-за того, что
    // состояние успело измениться, свежий список это и покажет.
    await _load();
  }

  String _time(DateTime? value) {
    if (value == null) return '--:--';
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _humanDate(DateTime? date) {
    if (date == null) return 'дата не указана';

    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    return '${date.day} ${months[(date.month - 1).clamp(0, 11)]}';
  }
}
